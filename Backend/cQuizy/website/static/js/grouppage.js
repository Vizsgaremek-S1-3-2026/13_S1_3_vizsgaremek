// static/js/grouppage.js

function getToken() { return localStorage.getItem('authToken'); }
function getGroupIdFromUrl() { const p = new URLSearchParams(window.location.search); return p.get('groupId'); }

function formatDatePretty(iso) { return new Date(iso).toLocaleString(); }

// Fixed Darken Logic
function darkenColor(color, amount) {
    let usePound = false;
    if (color[0] === "#") { color = color.slice(1); usePound = true; }

    // Parse
    let num = parseInt(color, 16);

    // Handle invalid hex
    if (isNaN(num)) return "#000000";

    let r = (num >> 16);
    let g = ((num >> 8) & 0x00FF);
    let b = (num & 0x0000FF);

    r = Math.max(0, Math.floor(r * (1 - amount)));
    g = Math.max(0, Math.floor(g * (1 - amount)));
    b = Math.max(0, Math.floor(b * (1 - amount)));

    return (usePound ? "#" : "") + (g | (b << 8) | (r << 16)).toString(16).padStart(6, '0');
}

async function fetchGroupDetails(id) {
    const res = await fetch(`/api/groups/${id}`, { headers: { 'Authorization': `Bearer ${getToken()}` } });
    if (!res.ok) throw new Error("Failed to load group.");
    return await res.json();
}
async function fetchGroupMembers(id) {
    const res = await fetch(`/api/groups/${id}/members`, { headers: { 'Authorization': `Bearer ${getToken()}` } });
    return res.ok ? await res.json() : [];
}
async function fetchGroupQuizzes(id) {
    const res = await fetch(`/api/quizzes/group/${id}`, { headers: { 'Authorization': `Bearer ${getToken()}` } });
    return res.ok ? await res.json() : [];
}
async function kickMember(gId, uId) {
    if (!confirm("Kick user?")) return;
    await fetch(`/api/groups/${gId}/members/${uId}`, { method: 'DELETE', headers: { 'Authorization': `Bearer ${getToken()}` } });
    loadPageData();
}

function renderHeader(group) {
    const header = document.getElementById('groupHeader');
    document.getElementById('groupName').textContent = group.name;
    document.getElementById('groupIdDisplay').textContent = group.id;
    document.getElementById('groupInviteCode').textContent = group.invite_code_formatted;

    // Fixed: Forced White Text
    const anticheatHtml = group.anticheat
        ? `<span style="color:white;">🔒 Anti-Cheat: <b>ON</b></span>`
        : `<span style="color:white;">🔓 Anti-Cheat: OFF</span>`;

    const kioskHtml = group.kiosk
        ? `<span style="color:white;">📱 Kiosk: <b>ON</b></span>`
        : `<span style="color:white;">📱 Kiosk: OFF</span>`;

    document.getElementById('groupAnticheatBadge').innerHTML = anticheatHtml;
    document.getElementById('groupKioskBadge').innerHTML = kioskHtml;

    // Fixed: Standard Gradient Direction (135deg)
    const darkColor = darkenColor(group.color, 0.6); // Darken more for better contrast
    header.style.background = `linear-gradient(135deg, ${group.color}, ${darkColor})`;
    header.style.color = "white"; // Ensure header text is white
}

function renderMembers(members, rank) {
    const container = document.getElementById('membersList');
    container.innerHTML = '';
    if (members.length === 0) { container.innerHTML = '<p>No members.</p>'; return; }

    const ul = document.createElement('ul');
    ul.style.listStyle = 'none'; ul.style.padding = '0';

    members.forEach(m => {
        const li = document.createElement('li');
        li.className = 'list-item'; // Uses updated global.css class

        let btn = '';
        // "Kick" button logic
        if ((rank === 'ADMIN' || rank === 'SUPERUSER') && m.rank !== 'ADMIN') {
            btn = `<button class="delete-btn" onclick="kickMember(${m.group_id}, ${m.user.id})">Kick</button>`;
        }

        li.innerHTML = `
            <div>
                <strong>${m.user.nickname || m.user.username}</strong>
                <span style="font-size:0.8em; opacity:0.7; margin-left:10px;">(${m.rank})</span>
            </div>
            ${btn}
        `;
        ul.appendChild(li);
    });
    container.appendChild(ul);
}

function renderQuizzes(quizzes, rank) {
    const container = document.getElementById('quizzesList');
    container.innerHTML = '';
    const now = new Date();

    quizzes.forEach(q => {
        const start = new Date(q.date_start);
        const end = new Date(q.date_end);
        let status = now < start ? '<span style="color:#ffd800">Upcoming</span>' : (now > end ? '<span style="color:#ed2f5b">Ended</span>' : '<span style="color:#2fedc1">Active</span>');

        let btns = '';
        if (rank === 'ADMIN' || rank === 'SUPERUSER') {
            btns += `<button onclick="location.href='/quizadmin/?quizId=${q.id}'" style="background:var(--secondary-color); color:#000; margin-right:5px;">Admin</button>`;
        }
        if (now >= start && now <= end) {
            btns += `<button onclick="location.href='/quiz/?quizId=${q.id}'" style="background:#28a745;">Start</button>`;
        } else {
            btns += `<button disabled style="opacity:0.5;">${now < start ? 'Wait' : 'Closed'}</button>`;
        }

        const div = document.createElement('div');
        div.className = 'list-item';
        div.style.display = 'block'; // Stack content
        div.innerHTML = `
            <div style="display:flex; justify-content:space-between; margin-bottom:5px;">
                <h3 style="margin:0; color:white;">${q.project_name}</h3>
                ${status}
            </div>
            <div style="font-size:0.9em; opacity:0.7; margin-bottom:10px;">
                ${formatDatePretty(start)} - ${formatDatePretty(end)}
            </div>
            <div style="text-align:right;">${btns}</div>
        `;
        container.appendChild(div);
    });
}

async function loadPageData() {
    const id = getGroupIdFromUrl();
    if (!id) return;
    try {
        const g = await fetchGroupDetails(id);
        renderHeader(g);
        const m = await fetchGroupMembers(id);
        renderMembers(m, g.rank);
        const q = await fetchGroupQuizzes(id);
        renderQuizzes(q, g.rank);
    } catch (e) { console.error(e); }
}
document.addEventListener('DOMContentLoaded', loadPageData);