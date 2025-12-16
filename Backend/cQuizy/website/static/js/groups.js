// static/js/groups.js

/**
 * Creates a darker shade of a given hex color.
 */
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

function formatDateTime(isoString) {
    const date = new Date(isoString);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');
    return `${year}. ${month}. ${day}. ${hours}:${minutes}:${seconds}`;
}

async function handleApiError(response) {
    try {
        const errorData = await response.json();
        return errorData.detail || JSON.stringify(errorData);
    } catch (e) {
        return response.statusText || 'An unexpected error occurred.';
    }
}

document.addEventListener('DOMContentLoaded', async function() {
    const groupsContainer = document.getElementById('groupsContainer');
    const token = localStorage.getItem('authToken');

    // Form References
    const createGroupForm = document.getElementById('formCreateGroup');
    const joinGroupForm = document.getElementById('formJoinGroup');
    const updateGroupForm = document.getElementById('formUpdateGroup');
    const regenerateCodeForm = document.getElementById('formRegenerateCode');
    const transferGroupForm = document.getElementById('formTransferGroup');

    // Input References
    const groupNameInput = document.getElementById('groupNameInput');
    const groupColorInput = document.getElementById('groupColorInput');
    const groupInviteInput = document.getElementById('groupInviteInput');
    const groupTransferIdInput = document.getElementById('groupTransferId');
    const groupTransferUserInput = document.getElementById('groupTransferUser');
    const groupUpdateIdInput = document.getElementById('groupUpdateId');
    const groupUpdateNameInput = document.getElementById('groupUpdateName');
    const groupUpdateColorInput = document.getElementById('groupUpdateColor');
    const groupUpdateColorCheck = document.getElementById('groupUpdateColorCheck');
    const groupUpdateAnticheatInput = document.getElementById('groupUpdateAnticheat');
    const groupUpdateKioskInput = document.getElementById('groupUpdateKiosk');
    const groupRegenerateIdInput = document.getElementById('groupRegenerateId');


    /**
     * Fetches all groups for the current user and renders them.
     */
    const fetchAndDisplayGroups = async () => {
        if (!token) {
            groupsContainer.innerHTML = '<p>Please log in to see your groups.</p>';
            return;
        }
        try {
            const response = await fetch('/api/groups/', {
                method: 'GET',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }
            });
            if (!response.ok) throw new Error(await handleApiError(response));
            
            const groups = await response.json();
            groupsContainer.innerHTML = '';

            if (groups.length === 0) {
                groupsContainer.innerHTML = '<p>You are not a member of any groups yet. Create or join one!</p>';
            } else {
                groups.forEach(group => {
                    const groupElement = document.createElement('div');
                    groupElement.className = 'groupItem';
                    const darkerColor = darkenColor(group.color, 0.3);
                    groupElement.style.background = `linear-gradient(to bottom right, ${darkerColor}, ${group.color})`;
                    
                    let primaryAction = '';
                    if (group.rank === 'ADMIN' || group.rank === 'SUPERUSER') {
                        primaryAction = `<button class="delete-btn" data-group-id="${group.id}">Delete Group</button>`;
                    } else {
                        primaryAction = `<button class="leave-btn" data-group-id="${group.id}">Leave Group</button>`;
                    }

                    // CHANGED: Replaced View Members with Group Page button
                    const groupPageButton = `<button class="group-page-btn" data-group-id="${group.id}">Group Page</button>`;
                    
                    const formattedDate = formatDateTime(group.date_created);
                    
                    groupElement.innerHTML = `
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <h3>${group.name} | ID: ${group.id}</h3>
                            <div class="group-actions">
                                ${primaryAction}
                                ${groupPageButton}
                            </div>
                        </div>
                        <p><strong>Invite Code:</strong> ${group.invite_code_formatted}</p>
                        <p><strong>Created on:</strong> ${formattedDate}</p>
                        <p><strong>Your Rank:</strong> ${group.rank}</p> 
                        <p><strong>Anti-Cheat:</strong> ${group.anticheat ? 'Enabled' : 'Disabled'} | <strong>Kiosk Mode:</strong> ${group.kiosk ? 'Enabled' : 'Disabled'}</p>
                    `;
                    groupsContainer.appendChild(groupElement);
                });
            }
        } catch (error) {
            groupsContainer.innerHTML = `<p style="color: red;">Error: ${error.message}</p>`;
        }
    };

    // Event listener for button clicks inside the groups container
    groupsContainer.addEventListener('click', async (event) => {
        if (!token) return alert('Please log in.');

        const deleteBtn = event.target.closest('.delete-btn');
        const leaveBtn = event.target.closest('.leave-btn');
        const groupPageBtn = event.target.closest('.group-page-btn'); // NEW

        const processAction = async (url, method, confirmMsg) => {
            if (confirm(confirmMsg)) {
                try {
                    const response = await fetch(url, { method: method, headers: { 'Authorization': `Bearer ${token}` }});
                    if (!response.ok) throw new Error(await handleApiError(response));
                    fetchAndDisplayGroups();
                } catch (error) { alert(`Error: ${error.message}`); }
            }
        };

        if (deleteBtn) {
            const groupId = deleteBtn.dataset.groupId;
            processAction(`/api/groups/${groupId}`, 'DELETE', `Are you sure you want to DELETE group ID ${groupId}? This cannot be undone.`);
            return;
        }

        if (leaveBtn) {
            const groupId = leaveBtn.dataset.groupId;
            processAction(`/api/groups/${groupId}/leave`, 'DELETE', `Are you sure you want to LEAVE group ID ${groupId}?`);
            return;
        }
        
        // NEW: Handle redirection to Group Page
        if (groupPageBtn) {
            const groupId = groupPageBtn.dataset.groupId;
            window.location.href = `/grouppage/?groupId=${groupId}`;
            return;
        }
    });

    // --- FORM SUBMISSION HANDLERS ---
    
    createGroupForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        if (!token) return alert('You must be logged in to create a group.');
        const groupName = groupNameInput.value.trim();
        const groupColor = groupColorInput.value;
        if (!groupName) return alert('Please enter a name for the group.');
        try {
            const response = await fetch('/api/groups/', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
                body: JSON.stringify({ name: groupName, color: groupColor })
            });
            if (!response.ok) throw new Error(await handleApiError(response));
            createGroupForm.reset();
            fetchAndDisplayGroups();
        } catch (error) { alert(`Error: ${error.message}`); }
    });

    joinGroupForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        if (!token) return alert('You must be logged in to join a group.');
        const inviteCode = groupInviteInput.value.trim();
        if (!inviteCode) return alert('Please enter an invite code.');
        try {
            const response = await fetch('/api/groups/join', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
                body: JSON.stringify({ invite_code: inviteCode })
            });
            if (!response.ok) throw new Error(await handleApiError(response));
            joinGroupForm.reset();
            fetchAndDisplayGroups();
        } catch (error) { alert(`Error: ${error.message}`); }
    });

    updateGroupForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        if (!token) return alert('You must be logged in.');
        const groupId = groupUpdateIdInput.value.trim();
        if (!groupId) return alert('Please provide the Group ID to update.');
        const newName = groupUpdateNameInput.value.trim();
        
        const payload = {
            anticheat: groupUpdateAnticheatInput.checked,
            kiosk: groupUpdateKioskInput.checked
        };
        
        if (newName !== '') {
            payload.name = newName;
        }

        if (groupUpdateColorCheck.checked) {
            payload.color = groupUpdateColorInput.value;
        }

        try {
            const response = await fetch(`/api/groups/${groupId}`, {
                method: 'PATCH',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
                body: JSON.stringify(payload)
            });
            if (!response.ok) throw new Error(await handleApiError(response));
            alert('Group settings updated successfully!');
            updateGroupForm.reset();
            fetchAndDisplayGroups();
        } catch (error) {
            alert(`Error: ${error.message}`);
        }
    });

    regenerateCodeForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        if (!token) return alert('You must be logged in.');
        const groupId = groupRegenerateIdInput.value.trim();
        if (!groupId) return alert('Please provide the Group ID.');
        if (!confirm(`Are you sure you want to generate a new invite code for group ${groupId}? The old code will no longer work.`)) {
            return;
        }
        try {
            const response = await fetch(`/api/groups/${groupId}/regenerate-invite`, {
                method: 'POST',
                headers: { 'Authorization': `Bearer ${token}` }
            });
            if (!response.ok) throw new Error(await handleApiError(response));
            alert('New invite code generated successfully!');
            regenerateCodeForm.reset();
            fetchAndDisplayGroups();
        } catch (error) {
            alert(`Error: ${error.message}`);
        }
    });

    transferGroupForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        if (!token) return alert('You must be logged in.');
        const groupId = groupTransferIdInput.value.trim();
        const newOwnerId = groupTransferUserInput.value.trim();
        if (!groupId || !newOwnerId) return alert("Please provide both a Group ID and the new owner's User ID.");
        try {
            const response = await fetch(`/api/groups/${groupId}/transfer`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
                body: JSON.stringify({ user_id: parseInt(newOwnerId) })
            });
            if (!response.ok) throw new Error(await handleApiError(response));
            alert('Ownership transferred successfully!');
            transferGroupForm.reset();
            fetchAndDisplayGroups();
        } catch (error) {
            alert(`Error: ${error.message}`);
        }
    });

    // --- Initial Load ---
    fetchAndDisplayGroups();
});