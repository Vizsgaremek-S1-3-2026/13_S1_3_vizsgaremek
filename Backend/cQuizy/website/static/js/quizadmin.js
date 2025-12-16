// static/js/quizadmin.js

let quizId = null;
let currentSubmissionId = null;
let currentGroupId = null;
let eventPollingInterval = null;

function getToken() {
    return localStorage.getItem('authToken');
}

function getQuizId() {
    const p = new URLSearchParams(window.location.search);
    return p.get('quizId');
}

document.addEventListener('DOMContentLoaded', async () => {
    quizId = getQuizId();
    if (!quizId) {
        alert("No Quiz ID provided.");
        window.location.href = '/groups/';
        return;
    }

    document.getElementById('quizIdDisplay').innerText = `ID: ${quizId}`;

    loadStats();
    loadEvents();
    loadSubmissions();

    eventPollingInterval = setInterval(() => {
        loadEvents();
    }, 3000);
});

// --- STATS LOGIC ---
async function loadStats() {
    try {
        const response = await fetch(`/api/quizzes/${quizId}/stats`, {
            headers: { 'Authorization': `Bearer ${getToken()}` }
        });
        if (!response.ok) return;

        const stats = await response.json();

        document.getElementById('statAvg').innerText = stats.average_score.toFixed(1) + '%';
        document.getElementById('statMax').innerText = stats.max_score.toFixed(1) + '%';
        document.getElementById('statMin').innerText = stats.min_score.toFixed(1) + '%';
        document.getElementById('statCount').innerText = stats.submission_count;

        // Color coding for Avg
        const avgEl = document.getElementById('statAvg');
        if (stats.average_score >= 80) avgEl.style.color = 'var(--success-color)';
        else if (stats.average_score < 50) avgEl.style.color = 'var(--danger-color)';
        else avgEl.style.color = 'white';

    } catch (e) {
        console.error("Stats error", e);
    }
}

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
            if (a.status === 'ACTIVE' && b.status !== 'ACTIVE') return -1;
            if (a.status !== 'ACTIVE' && b.status === 'ACTIVE') return 1;
            return new Date(b.created_at) - new Date(a.created_at);
        });

        if (events.length === 0) {
            container.innerHTML = '<p style="text-align:center; color:#666;">No events recorded.</p>';
            return;
        }

        events.forEach(ev => {
            if (ev.status === 'ACTIVE') activeCount++;

            const div = document.createElement('div');
            div.className = `event-item ${ev.status.toLowerCase()}`;

            const time = new Date(ev.created_at).toLocaleTimeString();

            let btn = '';
            if (ev.status === 'ACTIVE') {
                btn = `<button onclick="resolveEvent(${ev.id})" style="margin-top:5px; padding:4px 10px; font-size:0.7em; background:white; color:black; border-radius:4px; border:none; cursor:pointer; font-weight:bold;">UNLOCK</button>`;
            }

            div.innerHTML = `
                <div style="display:flex; justify-content:space-between;">
                    <strong style="color:white;">${ev.student_name}</strong>
                    <span style="font-size:0.8em; color:#999;">${time}</span>
                </div>
                <div style="color:${ev.status === 'ACTIVE' ? '#ff8080' : '#aaa'}; font-size:0.9em; margin-top:2px;">
                    ${ev.desc}
                </div>
                ${btn}
            `;
            container.appendChild(div);
        });

        document.getElementById('activeCount').innerText = `${activeCount} Active`;
        if (activeCount > 0) document.getElementById('activeCount').style.background = 'var(--danger-color)';
        else document.getElementById('activeCount').style.background = '#444';

    } catch (error) {
        console.error(error);
    }
}

async function resolveEvent(eventId) {
    if (!confirm("Unlock this student?")) return;
    try {
        await fetch(`/api/quizzes/events/${eventId}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${getToken()}` },
            body: JSON.stringify({ action: 'unlock' })
        });
        loadEvents();
    } catch (e) {
        alert(e);
    }
}

// --- SUBMISSIONS LOGIC ---
async function loadSubmissions() {
    const tbody = document.getElementById('submissionsBody');
    try {
        const response = await fetch(`/api/quizzes/${quizId}/submissions`, {
            headers: { 'Authorization': `Bearer ${getToken()}` }
        });
        const subs = await response.json();

        loadStats(); // Refresh stats when we load submissions

        tbody.innerHTML = '';
        if (subs.length === 0) {
            tbody.innerHTML = '<tr><td colspan="4" style="text-align:center; padding:20px;">No submissions yet</td></tr>';
            return;
        }

        subs.forEach(sub => {
            const tr = document.createElement('tr');
            tr.onclick = () => openSubmissionModal(sub.id);
            tr.style.cursor = "pointer";

            let gradeBadge = sub.grade_value ?
                `<span class="grade-badge">${sub.grade_value}</span>` :
                `<span style="color:#666;">-</span>`;

            tr.innerHTML = `
                <td style="font-weight:bold; color:white;">${sub.student_name}</td>
                <td style="color:var(--secondary-color);">${sub.percentage.toFixed(1)}%</td>
                <td>${gradeBadge}</td>
                <td style="font-size:0.8em; color:#888;">${new Date(sub.date_submitted).toLocaleDateString()}</td>
            `;
            tbody.appendChild(tr);
        });
    } catch (e) {
        console.error(e);
    }
}

// --- MODAL LOGIC ---

async function fetchGradeRules(groupId) {
    try {
        const response = await fetch(`/api/groups/${groupId}/grade-rules`, {
            headers: { 'Authorization': `Bearer ${getToken()}` }
        });
        if (!response.ok) return;
        const rules = await response.json();
        const select = document.getElementById('modalGradeSelect');
        select.innerHTML = '<option value="">No Grade</option>';
        rules.forEach(r => {
            const opt = document.createElement('option');
            opt.value = r.name;
            opt.text = `${r.name} (${r.min_percentage}-${r.max_percentage}%)`;
            select.appendChild(opt);
        });
    } catch (e) { }
}

async function openSubmissionModal(subId) {
    currentSubmissionId = subId;
    document.getElementById('submissionModal').style.display = 'flex';
    document.getElementById('modalAnswersContainer').innerHTML = 'Loading...';

    const response = await fetch(`/api/quizzes/submission/${subId}`, {
        headers: { 'Authorization': `Bearer ${getToken()}` }
    });
    const data = await response.json();
    currentGroupId = data.group_id;

    document.getElementById('modalStudentName').innerText = data.student_name;
    document.getElementById('modalScoreDisplay').innerText = data.percentage.toFixed(1) + '%';

    await fetchGradeRules(data.group_id);
    document.getElementById('modalGradeSelect').value = data.grade_value || "";

    // Render Blocks
    const container = document.getElementById('modalAnswersContainer');
    container.innerHTML = '';

    // Grouping logic for QA
    const grouped = {};
    data.answers.forEach(a => {
        if (!grouped[a.block_id]) grouped[a.block_id] = { q: a.block_question, ans: [] };
        grouped[a.block_id].ans.push(a);
    });

    Object.values(grouped).forEach((group) => {
        const div = document.createElement('div');
        div.style.background = "#1a1a1a";
        div.style.padding = "15px";
        div.style.marginBottom = "10px";
        div.style.borderRadius = "8px";

        let html = `<div style="color:white; margin-bottom:5px;"><strong>Q:</strong> ${group.q}</div>`;

        group.ans.forEach(a => {
            html += `
                <div style="display:flex; justify-content:space-between; margin-top:5px; border-top:1px solid #333; padding-top:5px;">
                    <span style="color:#ccc;">${a.student_answer}</span>
                    <div style="display:flex; align-items:center;">
                        <span style="font-size:0.8em; margin-right:5px;">Pts:</span>
                        <input type="number" class="points-input" data-id="${a.id}" value="${a.points_awarded}" style="width:50px; padding:4px; text-align:center;">
                    </div>
                </div>
            `;
        });
        div.innerHTML = html;
        container.appendChild(div);
    });
}

function closeModal() {
    document.getElementById('submissionModal').style.display = 'none';
}

window.onclick = function (e) {
    if (e.target == document.getElementById('submissionModal')) closeModal();
}

async function savePointChanges() {
    const inputs = document.querySelectorAll('.points-input');
    const updates = Array.from(inputs).map(i => ({
        submitted_answer_id: parseInt(i.dataset.id),
        new_points: parseInt(i.value)
    }));

    await fetch(`/api/quizzes/submission/${currentSubmissionId}/update-points`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${getToken()}` },
        body: JSON.stringify({ updates })
    });
    alert("Recalculated!");
    loadSubmissions();
    closeModal();
}

async function saveGradeOverride() {
    const val = document.getElementById('modalGradeSelect').value;
    await fetch(`/api/quizzes/submission/${currentSubmissionId}/update-grade`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${getToken()}` },
        body: JSON.stringify({ new_grade: val })
    });
    alert("Grade Saved.");
    loadSubmissions();
}