// static/js/quiz.js

// --- Global State ---
let quizData = null;
let quizId = null;
let timerInterval = null;
let isLocked = false;
let pollingInterval = null;

// --- Helper Functions ---
function getToken() {
    return localStorage.getItem('authToken');
}

function getQuizIdFromUrl() {
    const params = new URLSearchParams(window.location.search);
    return params.get('quizId');
}

async function handleApiError(response) {
    try {
        const errorData = await response.json();
        return errorData.detail || JSON.stringify(errorData);
    } catch (e) {
        return response.statusText;
    }
}

// --- Anti-Cheat Logic ---

async function triggerLockout(reason) {
    if (isLocked) return;
    if (!quizData || !quizData.anticheat_enabled) return;

    isLocked = true;
    document.getElementById('lockOverlay').style.display = 'flex';

    try {
        await fetch('/api/quizzes/events', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${getToken()}` },
            body: JSON.stringify({
                quiz_id: parseInt(quizId),
                type: 'tab_switch',
                desc: `User left the window: ${reason}`
            })
        });
    } catch (error) {
        console.error("Failed to log cheat event:", error);
    }

    startPollingUnlock();
}

function startPollingUnlock() {
    if (pollingInterval) clearInterval(pollingInterval);

    pollingInterval = setInterval(async () => {
        try {
            const response = await fetch(`/api/quizzes/${quizId}/lock-status`, {
                headers: { 'Authorization': `Bearer ${getToken()}` }
            });

            if (response.ok) {
                const status = await response.json();

                if (!status.is_locked) {
                    clearInterval(pollingInterval);
                    isLocked = false;
                    document.getElementById('lockOverlay').style.display = 'none';
                    alert("The teacher has unlocked your test. You may continue.");
                } else {
                    document.getElementById('lockStatusText').textContent = status.message || "Waiting for teacher...";
                }
            }
        } catch (error) {
            console.error("Polling error:", error);
        }
    }, 3000);
}

// --- UI Rendering ---

function startTimer(endTimeIso) {
    const endTime = new Date(endTimeIso).getTime();
    const timerElement = document.getElementById('timerBadge');

    if (timerInterval) clearInterval(timerInterval);

    timerInterval = setInterval(() => {
        const now = new Date().getTime();
        const distance = endTime - now;

        if (distance < 0) {
            clearInterval(timerInterval);
            timerElement.textContent = "TIME UP";
            timerElement.style.backgroundColor = "#000";

            if (document.getElementById('quizApp').style.display !== 'none') {
                alert("Time is up! Submitting your answers now.");
                submitQuiz(true);
            }
            return;
        }

        const days = Math.floor(distance / (1000 * 60 * 60 * 24));
        const hours = Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
        const seconds = Math.floor((distance % (1000 * 60)) / 1000);

        const hh = hours.toString().padStart(2, '0');
        const mm = minutes.toString().padStart(2, '0');
        const ss = seconds.toString().padStart(2, '0');

        if (days > 0) {
            timerElement.textContent = `${days}d ${hh}:${mm}:${ss}`;
        } else {
            timerElement.textContent = `${hh}:${mm}:${ss}`;
        }

        if (distance < 5 * 60 * 1000 && days === 0) {
            timerElement.style.backgroundColor = "#ff0000";
        }

    }, 1000);
}

function renderBlocks(blocks) {
    const container = document.getElementById('questionsContainer');
    container.innerHTML = '';

    blocks.forEach((block, index) => {
        const blockDiv = document.createElement('div');
        blockDiv.className = 'question-block';
        blockDiv.dataset.blockId = block.id;
        blockDiv.dataset.type = block.type;

        let html = `<div class="question-text">${index + 1}. ${block.question}</div>`;

        if (block.subtext) {
            html += `<div class="subtext">${block.subtext}</div>`;
        }
        if (block.image_url) {
            html += `<img src="${block.image_url}" style="max-width:100%; margin-bottom:15px; border-radius:5px;">`;
        }
        if (block.link_url) {
            html += `<div style="margin-bottom:15px;"><a href="${block.link_url}" target="_blank" rel="noopener noreferrer">Attached Resource Link</a></div>`;
        }

        html += `<div class="options-container">`;

        if (block.type === 'TEXT') {
            html += `<textarea class="quiz-input" rows="3" style="width:100%; padding:10px; border-radius:5px; border:1px solid #ccc;" placeholder="Type your answer here..."></textarea>`;
        }
        else if (block.type === 'SINGLE') {
            block.answers.forEach(opt => {
                html += `
                    <label>
                        <input type="radio" name="block_${block.id}" value="${opt.text}" class="quiz-input">
                        ${opt.text}
                    </label>
                `;
            });
        }
        else if (block.type === 'MULTIPLE') {
            block.answers.forEach(opt => {
                html += `
                    <label>
                        <input type="checkbox" name="block_${block.id}" value="${opt.text}" class="quiz-input">
                        ${opt.text}
                    </label>
                `;
            });
        }

        html += `</div>`;
        blockDiv.innerHTML = html;
        container.appendChild(blockDiv);
    });
}

// --- Main Logic ---

async function initQuiz() {
    quizId = getQuizIdFromUrl();
    if (!quizId || !getToken()) {
        alert("Invalid access. Please ensure you are logged in and using a valid link.");
        window.location.href = '/groups/';
        return;
    }

    try {
        const response = await fetch(`/api/quizzes/${quizId}/start`, {
            headers: { 'Authorization': `Bearer ${getToken()}` }
        });

        if (!response.ok) {
            const msg = await handleApiError(response);
            document.getElementById('loadingMessage').innerHTML = `<h3 style="color:red">${msg}</h3><a href="/groups/" class="back-btn">Go Back</a>`;
            return;
        }

        quizData = await response.json();

        document.getElementById('quizTitle').textContent = quizData.title;
        document.getElementById('loadingMessage').style.display = 'none';
        document.getElementById('quizApp').style.display = 'block';

        let badges = "";
        if (quizData.anticheat_enabled) badges += "🔒 Anti-Cheat Active ";
        if (quizData.kiosk_enabled) badges += "📱 Kiosk Mode ";
        document.getElementById('quizModeBadge').textContent = badges;

        renderBlocks(quizData.blocks);
        startTimer(quizData.date_end);

        if (quizData.anticheat_enabled) {
            document.addEventListener('visibilitychange', () => {
                if (document.hidden) triggerLockout("Tab switched / Minimized");
            });

            window.addEventListener('blur', () => {
                triggerLockout("Focus lost (Clicked outside)");
            });
        }

    } catch (error) {
        console.error(error);
        alert("Failed to load quiz data.");
    }
}

async function submitQuiz(forced = false) {
    if (!forced && !confirm("Are you sure you want to submit your answers? This cannot be undone.")) {
        return;
    }

    const answers = [];
    const blockDivs = document.querySelectorAll('.question-block');

    blockDivs.forEach(div => {
        const blockId = parseInt(div.dataset.blockId);
        const type = div.dataset.type;
        const inputs = div.querySelectorAll('.quiz-input');

        if (type === 'TEXT') {
            const val = inputs[0].value.trim();
            if (val) answers.push({ block_id: blockId, answer_text: val });
        }
        else if (type === 'SINGLE') {
            inputs.forEach(radio => {
                if (radio.checked) {
                    answers.push({ block_id: blockId, answer_text: radio.value });
                }
            });
        }
        else if (type === 'MULTIPLE') {
            inputs.forEach(chk => {
                if (chk.checked) {
                    answers.push({ block_id: blockId, answer_text: chk.value });
                }
            });
        }
    });

    try {
        const submitBtn = document.getElementById('submitQuizBtn');
        submitBtn.disabled = true;
        submitBtn.textContent = "Submitting...";

        const response = await fetch('/api/quizzes/submit', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${getToken()}` },
            body: JSON.stringify({
                quiz_id: parseInt(quizId),
                answers: answers
            })
        });

        if (!response.ok) throw new Error(await handleApiError(response));

        const result = await response.json();

        // FIXED: Using result.group_id from the response
        document.getElementById('quizApp').innerHTML = `
            <div style="text-align:center; padding:50px;">
                <h1 style="color:green; font-size:3em;">✓ Submitted!</h1>
                <p>Your answers have been recorded successfully.</p>
                <div style="background:white; padding:20px; border-radius:10px; max-width:400px; margin:20px auto; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                    <h2 style="margin-top:0;">Result: ${result.percentage.toFixed(1)}%</h2>
                    ${result.grade_value
                ? `<h3 style="color:#007bff; font-size: 2em; margin: 10px 0;">Grade: ${result.grade_value}</h3>`
                : '<p><em>(No grade assigned for this percentage)</em></p>'
            }
                    <p style="color:#666; font-size:0.9em;">Submitted on: ${new Date(result.date_submitted).toLocaleString()}</p>
                </div>
                <a href="/grouppage/?groupId=${result.group_id}" style="display:inline-block; margin-top:20px; text-decoration:none; background:#555; color:white; padding:10px 20px; border-radius:5px;">Return to Group</a>
            </div>
        `;

        if (timerInterval) clearInterval(timerInterval);
        if (pollingInterval) clearInterval(pollingInterval);

    } catch (error) {
        alert(`Submission Failed: ${error.message}`);
        const submitBtn = document.getElementById('submitQuizBtn');
        submitBtn.disabled = false;
        submitBtn.textContent = "Submit Answers";
    }
}

document.addEventListener('DOMContentLoaded', () => {
    initQuiz();
    const submitBtn = document.getElementById('submitQuizBtn');
    if (submitBtn) {
        submitBtn.addEventListener('click', () => submitQuiz(false));
    }
});