// static/js/quizadmin.js

let quizId = null;
let currentSubmissionId = null;
let currentGroupId = null;
let eventPollingInterval = null;

// --- Utils ---
function getToken() { return localStorage.getItem('authToken'); }
function getQuizId() { const p = new URLSearchParams(window.location.search); return p.get('quizId'); }

async function handleApiError(response) {
    try { const d = await response.json(); return d.detail || JSON.stringify(d); }
    catch { return response.statusText; }
}

function formatTime(iso) {
    return new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

// --- Main Init ---
document.addEventListener('DOMContentLoaded', async () => {
    quizId = getQuizId();
    if (!quizId) { alert("No Quiz ID provided."); window.location.href = '/groups/'; return; }

    try {
        document.getElementById('quizAdminTitle').innerText = `Quiz Manager (ID: ${quizId})`;
    } catch (e) { console.error(e); }

    loadEvents();
    eventPollingInterval = setInterval(loadEvents, 3000);
    loadSubmissions();
});

// --- EVENTS LOGIC ---
async function loadEvents() {
    try {
        const response = await fetch(`/api/quizzes/events/${quizId}`, {
            headers: { 'Authorization': `Bearer ${getToken()}` }
        });
        if (!response.ok) return;

        const events = await response.json();
        const container = document.getElementById('eventsContainer');
        container.innerHTML = '';

        let activeCount = 0;
        events.sort((a, b) => {
            if (a.status === 'active' && b.status !== 'active') return -1;
            if (a.status !== 'active' && b.status === 'active') return 1;
            return new Date(b.created_at) - new Date(a.created_at);
        });

        events.forEach(ev => {
            if (ev.status === 'active') activeCount++;
            const card = document.createElement('div');
            card.className = `event-card status-${ev.status}`;

            let actionHtml = '';
            if (ev.status === 'active') {
                actionHtml = `<button class="resolve-btn" onclick="resolveEvent(${ev.id})">Unlock Student</button>`;
            }

            card.innerHTML = `
                <div class="event-header">
                    <span>${ev.student_name}</span>
                    <span class="event-time">${formatTime(ev.created_at)}</span>
                </div>
                <div style="font-size:0.9em; margin-bottom:5px;">Type: <b>${ev.type}</b></div>
                <div style="font-size:0.9em; color:#ccc;">${ev.type === 'tab_switch' ? 'Student left the tab.' : 'System Event'}</div>
                ${actionHtml}
            `;
            container.appendChild(card);
        });
        document.getElementById('activeCount').innerText = activeCount;
    } catch (error) { console.error("Event Poll Error", error); }
}

async function resolveEvent(eventId) {
    if (!confirm("Unlock this student? They will be allowed to continue.")) return;
    try {
        const response = await fetch(`/api/quizzes/events/${eventId}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${getToken()}` },
            body: JSON.stringify({ action: 'unlock', note: 'Unlocked by Admin' })
        });
        if (!response.ok) throw new Error(await handleApiError(response));
        loadEvents();
    } catch (error) { alert(`Error: ${error.message}`); }
}

// --- SUBMISSIONS LOGIC ---
async function loadSubmissions() {
    const tbody = document.getElementById('submissionsBody');
    tbody.innerHTML = '<tr><td colspan="4">Loading...</td></tr>';

    try {
        const response = await fetch(`/api/quizzes/${quizId}/submissions`, {
            headers: { 'Authorization': `Bearer ${getToken()}` }
        });
        if (!response.ok) throw new Error(await handleApiError(response));

        const subs = await response.json();
        tbody.innerHTML = '';

        if (subs.length === 0) {
            tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;">No submissions yet.</td></tr>';
            return;
        }

        subs.forEach(sub => {
            const tr = document.createElement('tr');
            tr.className = 'submission-row';
            tr.onclick = () => openSubmissionModal(sub.id);

            const gradeHtml = sub.grade_value
                ? `<span class="grade-badge">${sub.grade_value}</span>`
                : '<span style="opacity:0.5">-</span>';

            tr.innerHTML = `
                <td><b>${sub.student_name}</b></td>
                <td>${sub.percentage.toFixed(1)}%</td>
                <td>${gradeHtml}</td>
                <td style="font-size:0.8em;">${new Date(sub.date_submitted).toLocaleDateString()}</td>
            `;
            tbody.appendChild(tr);
        });
    } catch (error) {
        tbody.innerHTML = `<tr><td colspan="4" style="color:red">${error.message}</td></tr>`;
    }
}

// --- MODAL LOGIC ---

async function fetchGradeRules(groupId) {
    // Populate the Grade Dropdown
    try {
        const response = await fetch(`/api/groups/${groupId}/grade-rules`, {
            headers: { 'Authorization': `Bearer ${getToken()}` }
        });
        if (!response.ok) return; // Maybe group has no rules, that's fine

        const rules = await response.json();
        const select = document.getElementById('modalGradeSelect');
        // Clear existing options except first
        select.innerHTML = '<option value="">No Grade</option>';

        // Add manual options just in case
        // But mainly use rules
        rules.forEach(rule => {
            const opt = document.createElement('option');
            opt.value = rule.name;
            opt.text = `${rule.name} (${rule.min_percentage}-${rule.max_percentage}%)`;
            select.appendChild(opt);
        });
    } catch (e) { console.error("Failed to load grade rules", e); }
}

async function openSubmissionModal(submissionId) {
    currentSubmissionId = submissionId;
    const modal = document.getElementById('submissionModal');
    const container = document.getElementById('modalAnswersContainer');

    modal.style.display = 'block';
    container.innerHTML = '<p>Loading details...</p>';

    try {
        const response = await fetch(`/api/quizzes/submission/${submissionId}`, {
            headers: { 'Authorization': `Bearer ${getToken()}` }
        });
        if (!response.ok) throw new Error(await handleApiError(response));

        const details = await response.json();
        currentGroupId = details.group_id;

        document.getElementById('modalStudentName').textContent = `${details.student_name}`;
        document.getElementById('modalScoreDisplay').textContent = `Total Score: ${details.percentage.toFixed(1)}%`;

        // Setup Grade Dropdown
        await fetchGradeRules(currentGroupId);
        const gradeSelect = document.getElementById('modalGradeSelect');
        gradeSelect.value = details.grade_value || ""; // Set current grade

        // --- RENDER BLOCKS ---
        container.innerHTML = '';

        // 1. Group answers by Block
        const groupedMap = new Map(); // blockId -> { question: "", order: 0, answers: [] }

        details.answers.forEach(ans => {
            if (!groupedMap.has(ans.block_id)) {
                groupedMap.set(ans.block_id, {
                    id: ans.block_id,
                    order: ans.block_order,
                    question: ans.block_question,
                    answers: []
                });
            }
            groupedMap.get(ans.block_id).answers.push(ans);
        });

        // 2. Sort by Order
        const sortedBlocks = Array.from(groupedMap.values()).sort((a, b) => a.order - b.order);

        // 3. Render
        sortedBlocks.forEach(block => {
            const blockDiv = document.createElement('div');
            blockDiv.className = 'question-block'; // Reusing global css
            blockDiv.style.padding = "15px"; // Override slightly for compact view
            blockDiv.style.marginBottom = "15px";

            let html = `<div style="font-weight:bold; margin-bottom:10px;">${block.order}. ${block.question}</div>`;

            block.answers.forEach(ans => {
                html += `
                    <div style="display:flex; justify-content:space-between; align-items:center; background:rgba(0,0,0,0.1); padding:8px; border-radius:5px; margin-bottom:5px;">
                        <span style="color:var(--text-color); margin-right:10px;">${ans.student_answer}</span>
                        <div style="display:flex; align-items:center; gap:5px;">
                            <label style="font-size:0.8em;">Points:</label>
                            <input type="number" class="points-input" 
                                   data-answer-id="${ans.id}" 
                                   value="${ans.points_awarded}" 
                                   style="width:60px; padding:5px; border-radius:5px; border:1px solid #555;">
                        </div>
                    </div>
                `;
            });

            blockDiv.innerHTML = html;
            container.appendChild(blockDiv);
        });

    } catch (error) {
        container.innerHTML = `<p style="color:red">Error: ${error.message}</p>`;
    }
}

async function savePointChanges() {
    if (!confirm("Recalculate score based on these points?")) return;

    const inputs = document.querySelectorAll('.points-input');
    const updates = [];

    inputs.forEach(inp => {
        updates.push({
            submitted_answer_id: parseInt(inp.dataset.answerId),
            new_points: parseInt(inp.value)
        });
    });

    try {
        const response = await fetch(`/api/quizzes/submission/${currentSubmissionId}/update-points`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${getToken()}` },
            body: JSON.stringify({ updates: updates })
        });
        if (!response.ok) throw new Error(await handleApiError(response));

        alert("Points updated and score recalculated!");
        // Refresh modal to see new percentage/grade
        openSubmissionModal(currentSubmissionId);
        // Refresh table
        loadSubmissions();

    } catch (error) {
        alert(`Error: ${error.message}`);
    }
}

async function saveGradeOverride() {
    const select = document.getElementById('modalGradeSelect');
    const newGrade = select.value;

    // Allow empty grade? Assuming yes to clear it.

    try {
        const response = await fetch(`/api/quizzes/submission/${currentSubmissionId}/update-grade`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${getToken()}` },
            body: JSON.stringify({ new_grade: newGrade })
        });
        if (!response.ok) throw new Error(await handleApiError(response));

        alert("Grade updated!");
        loadSubmissions(); // Update table
    } catch (error) {
        alert(`Error: ${error.message}`);
    }
}

function closeModal() {
    document.getElementById('submissionModal').style.display = 'none';
}

window.onclick = function (event) {
    const modal = document.getElementById('submissionModal');
    if (event.target == modal) {
        modal.style.display = "none";
    }
}