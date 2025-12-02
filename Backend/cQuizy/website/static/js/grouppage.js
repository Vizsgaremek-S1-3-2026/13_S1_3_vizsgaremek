// static/js/grouppage.js

// --- Utilities ---
function getToken() {
    return localStorage.getItem('authToken');
}

function getGroupIdFromUrl() {
    const params = new URLSearchParams(window.location.search);
    return params.get('groupId');
}

function darkenColor(color, amount) {
    let usePound = false;
    if (color[0] === "#") {
        color = color.slice(1);
        usePound = true;
    }
    const num = parseInt(color, 16);
    let r = (num >> 16);
    let g = ((num >> 8) & 0x00FF);
    let b = (num & 0x0000FF);

    r = Math.max(0, Math.floor(r * (1 - amount)));
    g = Math.max(0, Math.floor(g * (1 - amount)));
    b = Math.max(0, Math.floor(b * (1 - amount)));

    let newColor = b.toString(16).padStart(2, '0');
    newColor = g.toString(16).padStart(2, '0') + newColor;
    newColor = r.toString(16).padStart(2, '0') + newColor;

    return (usePound ? "#" : "") + newColor;
}

function formatDatePretty(isoString) {
    const date = new Date(isoString);
    return date.toLocaleString();
}

// --- API Calls ---

async function fetchGroupDetails(groupId) {
    const response = await fetch(`/api/groups/${groupId}`, {
        headers: { 'Authorization': `Bearer ${getToken()}` }
    });
    if (!response.ok) throw new Error("Failed to load group details.");
    return await response.json();
}

async function fetchGroupMembers(groupId) {
    const response = await fetch(`/api/groups/${groupId}/members`, {
        headers: { 'Authorization': `Bearer ${getToken()}` }
    });
    if (!response.ok) throw new Error("Failed to load members.");
    return await response.json();
}

async function fetchGroupQuizzes(groupId) {
    const response = await fetch(`/api/quizzes/group/${groupId}`, {
        headers: { 'Authorization': `Bearer ${getToken()}` }
    });
    if (!response.ok) throw new Error("Failed to load quizzes.");
    return await response.json();
}

async function kickMember(groupId, userId) {
    if (!confirm(`Are you sure you want to kick user ID ${userId}?`)) return;

    try {
        const response = await fetch(`/api/groups/${groupId}/members/${userId}`, {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${getToken()}` }
        });
        if (!response.ok) throw new Error("Failed to kick member.");

        alert("Member kicked successfully.");
        loadPageData();
    } catch (error) {
        alert(error.message);
    }
}

// --- Rendering ---

function renderHeader(group) {
    const header = document.getElementById('groupHeader');
    document.getElementById('groupName').textContent = group.name;
    document.getElementById('groupIdDisplay').textContent = group.id;
    document.getElementById('groupInviteCode').textContent = group.invite_code_formatted;

    document.getElementById('groupAnticheatBadge').innerHTML = group.anticheat
        ? '🔒 Anti-Cheat: <b>ON</b> &nbsp;'
        : '🔓 Anti-Cheat: OFF &nbsp;';

    document.getElementById('groupKioskBadge').innerHTML = group.kiosk
        ? '📱 Kiosk Mode: <b>ON</b>'
        : '📱 Kiosk Mode: OFF';

    const darkColor = darkenColor(group.color, 0.4);
    header.style.background = `linear-gradient(to bottom right, ${darkColor}, ${group.color})`;
}

function renderMembers(members, currentUserRank) {
    const container = document.getElementById('membersList');
    container.innerHTML = '';

    if (members.length === 0) {
        container.innerHTML = '<p>No members found.</p>';
        return;
    }

    const ul = document.createElement('ul');
    ul.style.listStyle = 'none';
    ul.style.padding = '0';

    members.forEach(member => {
        const li = document.createElement('li');
        li.className = 'list-item';

        const isAdmin = currentUserRank === 'ADMIN' || currentUserRank === 'SUPERUSER';

        let actionBtn = '';
        if (isAdmin && member.rank !== 'ADMIN') {
            actionBtn = `<button class="delete-btn" onclick="kickMember(${member.group_id}, ${member.user.id})">Kick</button>`;
        }

        li.innerHTML = `
            <div>
                <strong>${member.user.nickname || member.user.username}</strong>
                <span style="font-size:0.8em; color:#666;">(${member.rank})</span>
            </div>
            <div>
                ${actionBtn}
            </div>
        `;
        ul.appendChild(li);
    });
    container.appendChild(ul);
}

function renderQuizzes(quizzes, groupRank) {
    const container = document.getElementById('quizzesList');
    container.innerHTML = '';

    if (quizzes.length === 0) {
        container.innerHTML = '<p>No quizzes assigned to this group yet.</p>';
        return;
    }

    const now = new Date();
    const isTeacher = groupRank === 'ADMIN' || groupRank === 'SUPERUSER';

    quizzes.forEach(quiz => {
        const startDate = new Date(quiz.date_start);
        const endDate = new Date(quiz.date_end);

        let statusHtml = '';
        let startBtnHtml = '';
        let adminBtnHtml = '';

        // 1. Determine Status
        if (now < startDate) {
            statusHtml = `<span class="quiz-status status-upcoming">Upcoming</span>`;
            // Even if upcoming, admins might want to see the button disabled or maybe enabled for testing?
            // For now, let's keep standard logic:
            startBtnHtml = `<button disabled style="opacity:0.5; cursor:not-allowed; border:none; padding:8px 16px; border-radius:5px;">Starts Soon</button>`;
        } else if (now > endDate) {
            statusHtml = `<span class="quiz-status status-ended">Ended</span>`;
            startBtnHtml = `<button disabled style="opacity:0.5; cursor:not-allowed; border:none; padding:8px 16px; border-radius:5px;">Closed</button>`;
        } else {
            statusHtml = `<span class="quiz-status status-active">Active</span>`;
            startBtnHtml = `<button onclick="window.location.href='/quiz/?quizId=${quiz.id}'" style="background-color: #28a745; color: white; border:none; padding:8px 16px; border-radius:5px; cursor:pointer;">Start Quiz</button>`;
        }

        // 2. Add Admin Button if applicable
        if (isTeacher) {
            adminBtnHtml = `<button onclick="window.location.href='/quizadmin/?quizId=${quiz.id}'" style="background-color: var(--secondary-color); color: var(--primary-background); font-weight:bold; border:none; padding:8px 16px; border-radius:5px; cursor:pointer;">Admin Panel</button>`;
        }

        const div = document.createElement('div');
        div.className = 'list-item';
        div.innerHTML = `
            <div>
                <h3 style="margin: 0 0 5px 0;">${quiz.project_name}</h3>
                <small>Start: ${formatDatePretty(startDate)}</small><br>
                <small>End: ${formatDatePretty(endDate)}</small>
            </div>
            <div style="text-align: right;">
                ${statusHtml}
                <div style="margin-top: 10px; display: flex; gap: 10px; justify-content: flex-end;">
                    ${adminBtnHtml}
                    ${startBtnHtml}
                </div>
            </div>
        `;
        container.appendChild(div);
    });
}

// --- Main Logic ---

async function loadPageData() {
    const groupId = getGroupIdFromUrl();
    if (!groupId) {
        alert("No Group ID specified.");
        window.location.href = '/groups/';
        return;
    }

    try {
        const group = await fetchGroupDetails(groupId);
        renderHeader(group);

        const members = await fetchGroupMembers(groupId);
        renderMembers(members, group.rank);

        const quizzes = await fetchGroupQuizzes(groupId);
        // Pass the rank so renderQuizzes knows whether to show the Admin Panel button
        renderQuizzes(quizzes, group.rank);

    } catch (error) {
        console.error(error);
        document.getElementById('quizzesList').innerHTML = `<p style="color:red">Error: ${error.message}</p>`;
    }
}

window.kickMember = kickMember;

document.addEventListener('DOMContentLoaded', loadPageData);