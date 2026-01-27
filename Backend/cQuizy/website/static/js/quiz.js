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
    // Only trigger if enabled in quiz settings
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
        // --- Static Types (Divider / Text Block) ---
        if (block.type === 'divider') {
            const hr = document.createElement('div');
            hr.className = 'block-divider';
            hr.innerHTML = `<h3>${block.maintext || 'Section'}</h3>`;
            container.appendChild(hr);
            return;
        }

        if (block.type === 'text_block') {
            const staticTxt = document.createElement('div');
            staticTxt.className = 'question-block block-text-static';
            staticTxt.innerHTML = `<div style="white-space: pre-wrap;">${block.maintext}</div>`;
            container.appendChild(staticTxt);
            return;
        }

        // --- Standard Questions ---
        const blockDiv = document.createElement('div');
        blockDiv.className = 'question-block';
        blockDiv.dataset.blockId = block.id;
        blockDiv.dataset.type = block.type;

        // Header Logic (Gap Fill hides standard question usually)
        let headerHtml = '';
        if (block.type !== 'gap_fill') {
            headerHtml = `<div class="question-text">${index + 1}. ${block.maintext || block.question}</div>`;
        } else {
            headerHtml = `<div class="question-text">${index + 1}. Fill in the blanks:</div>`;
        }

        let contentHtml = headerHtml;
        if (block.subtext) contentHtml += `<div class="subtext">${block.subtext}</div>`;
        if (block.image_url) contentHtml += `<img src="${block.image_url}" style="max-width:100%; margin-bottom:15px; border-radius:5px;">`;
        if (block.link_url) contentHtml += `<div style="margin-bottom:15px;"><a href="${block.link_url}" target="_blank">Resource Link</a></div>`;

        contentHtml += `<div class="options-container">`;

        // --- INPUT RENDERING ---

        // 1. Text Input / Range (Free text/number)
        if (block.type === 'text' || block.type === 'range') {
            const typeAttr = block.type === 'range' ? 'number step="any"' : 'text';
            contentHtml += `<input type="${typeAttr}" class="quiz-input form-control" style="width:100%; padding:10px;" placeholder="Your Answer...">`;
        }

        // 2. Choice (Single / Multiple)
        else if (block.type === 'single' || block.type === 'multiple') {
            const inputType = block.type === 'single' ? 'radio' : 'checkbox';
            block.answers.forEach(opt => {
                contentHtml += `
                    <label class="quiz-option-label">
                        <input type="${inputType}" name="block_${block.id}" value="${opt.id}" class="quiz-input-choice">
                        ${opt.text}
                    </label>
                `;
            });
        }

        // 3. Ordering / Sentence Ordering (Drag & Drop)
        else if (block.type === 'ordering' || block.type === 'sentence_ordering') {
            contentHtml += `<ul class="sortable-list" id="sortable_${block.id}">`;
            // Randomize display order so user has to do work
            const shuffledAnswers = [...block.answers].sort(() => Math.random() - 0.5);

            shuffledAnswers.forEach(opt => {
                contentHtml += `<li class="sortable-item" data-option-id="${opt.id}">${opt.text}</li>`;
            });
            contentHtml += `</ul>`;
        }

        // 4. Matching (Left text -> Right dropdown)
        else if (block.type === 'matching') {
            // Right Side Options (The values to match against)
            // Extract unique match texts from answers
            const rightOptions = block.answers.map(a => ({ text: a.match_text })).filter(a => a.text);
            // Randomize right side
            rightOptions.sort(() => Math.random() - 0.5);

            block.answers.forEach(leftItem => {
                if (!leftItem.text) return; // Skip invalid rows

                let optionsHtml = `<option value="">-- Select --</option>`;
                rightOptions.forEach(opt => {
                    optionsHtml += `<option value="${opt.text}">${opt.text}</option>`;
                });

                // We attach the ID of the answer (Left side) to the row
                contentHtml += `
                    <div class="matching-row" data-answer-id="${leftItem.id}">
                        <div class="matching-left">${leftItem.text}</div>
                        <div class="matching-right">
                             <select class="quiz-input-matching" style="width:100%; padding:8px;">${optionsHtml}</select>
                        </div>
                    </div>
                `;
            });
        }

        // 5. Gap Fill (Text with {1} -> Dropdowns)
        else if (block.type === 'gap_fill') {
            let text = block.gap_text || "";
            // Replace {1}, {2} placeholders with Select inputs
            text = text.replace(/{(\d+)}/g, (match, number) => {
                const index = parseInt(number);
                const gapOptions = block.answers.filter(a => a.gap_index === index);

                if (gapOptions.length === 0) return `[Gap ${index}]`;

                let opts = `<option value="">?</option>`;
                gapOptions.forEach(opt => {
                    opts += `<option value="${opt.id}">${opt.text}</option>`;
                });

                return `<select class="quiz-input-gap gap-select" data-gap-index="${index}">${opts}</select>`;
            });

            contentHtml += `<div class="gap-fill-content">${text}</div>`;
        }

        contentHtml += `</div>`;
        blockDiv.innerHTML = contentHtml;
        container.appendChild(blockDiv);

        // Activate SortableJS if needed
        if (block.type === 'ordering' || block.type === 'sentence_ordering') {
            new Sortable(blockDiv.querySelector('.sortable-list'), {
                animation: 150,
                ghostClass: 'sortable-ghost'
            });
        }
    });
}

// --- Main Logic ---

async function initQuiz() {
    quizId = getQuizIdFromUrl();
    if (!quizId || !getToken()) {
        alert("Invalid access.");
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
        if (quizData.anticheat_enabled) badges += "🔒 Anti-Cheat ";
        if (quizData.kiosk_enabled) badges += "📱 Kiosk ";
        document.getElementById('quizModeBadge').textContent = badges;

        renderBlocks(quizData.blocks);
        startTimer(quizData.date_end);

        // Setup Listeners for Anti-Cheat
        if (quizData.anticheat_enabled) {
            document.addEventListener('visibilitychange', () => {
                if (document.hidden) triggerLockout("Tab switched");
            });
            window.addEventListener('blur', () => {
                triggerLockout("Focus lost");
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

    const answersPayload = [];
    const blockDivs = document.querySelectorAll('.question-block');

    blockDivs.forEach(div => {
        const blockId = parseInt(div.dataset.blockId);
        const type = div.dataset.type;

        // 1. TEXT / RANGE
        if (type === 'text' || type === 'range') {
            const input = div.querySelector('.quiz-input');
            if (input && input.value.trim()) {
                answersPayload.push({
                    block_id: blockId,
                    answer_text: input.value.trim()
                });
            }
        }

        // 2. SINGLE / MULTIPLE CHOICE
        else if (type === 'single' || type === 'multiple') {
            const inputs = div.querySelectorAll('.quiz-input-choice:checked');
            inputs.forEach(inp => {
                answersPayload.push({
                    block_id: blockId,
                    option_id: parseInt(inp.value)
                });
            });
        }

        // 3. ORDERING (Visual Order)
        else if (type === 'ordering' || type === 'sentence_ordering') {
            const items = div.querySelectorAll('.sortable-item');
            items.forEach((item) => {
                answersPayload.push({
                    block_id: blockId,
                    option_id: parseInt(item.dataset.optionId)
                });
            });
        }

        // 4. MATCHING
        else if (type === 'matching') {
            const rows = div.querySelectorAll('.matching-row');
            rows.forEach(row => {
                const select = row.querySelector('select');
                const leftId = row.dataset.answerId;

                if (select && select.value) {
                    answersPayload.push({
                        block_id: blockId,
                        option_id: parseInt(leftId),     // ID of the Left Side (Database Row ID)
                        answer_text: select.value        // String value of Right Side
                    });
                }
            });
        }

        // 5. GAP FILL
        else if (type === 'gap_fill') {
            const selects = div.querySelectorAll('.quiz-input-gap');
            selects.forEach(sel => {
                if (sel.value) {
                    answersPayload.push({
                        block_id: blockId,
                        option_id: parseInt(sel.value) // ID of the option selected
                    });
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
                answers: answersPayload
            })
        });

        if (!response.ok) throw new Error(await handleApiError(response));

        const result = await response.json();

        // Success UI
        document.getElementById('quizApp').innerHTML = `
            <div style="text-align:center; padding:50px;">
                <h1 style="color:green; font-size:3em;">✓ Submitted!</h1>
                <p>Your answers have been recorded successfully.</p>
                <div style="background:white; padding:20px; border-radius:10px; max-width:400px; margin:20px auto; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                    <h2 style="margin-top:0;">Result: ${result.percentage.toFixed(1)}%</h2>
                    ${result.grade_value
                ? `<h3 style="color:#007bff; font-size: 2em; margin: 10px 0;">Grade: ${result.grade_value}</h3>`
                : '<p><em>(No grade assigned)</em></p>'
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