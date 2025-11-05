// static/js/groups.js

// Helper function for date formatting
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

// Robust Error Handling Function
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
    let currentUser = null; // Variable to store the logged-in user's data

    // --- Form Elements ---
    const createGroupForm = document.getElementById('formCreateGroup');
    const joinGroupForm = document.getElementById('formJoinGroup');
    const updateGroupForm = document.getElementById('formUpdateGroup');
    const regenerateCodeForm = document.getElementById('formRegenerateCode');
    const transferGroupForm = document.getElementById('formTransferGroup');

    // --- Input Elements ---
    const groupNameInput = document.getElementById('groupNameInput');
    const groupInviteInput = document.getElementById('groupInviteInput');
    const groupTransferIdInput = document.getElementById('groupTransferId');
    const groupTransferUserInput = document.getElementById('groupTransferUser');
    const groupUpdateIdInput = document.getElementById('groupUpdateId');
    const groupUpdateNameInput = document.getElementById('groupUpdateName');
    const groupUpdateAnticheatInput = document.getElementById('groupUpdateAnticheat');
    const groupUpdateKioskInput = document.getElementById('groupUpdateKiosk');
    const groupRegenerateIdInput = document.getElementById('groupRegenerateId');

    // --- Fetch current user's data on page load ---
    const fetchCurrentUser = async () => {
        if (!token) return;
        try {
            const response = await fetch('/api/users/profile/me', {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            if (!response.ok) return;
            const profileData = await response.json();
            currentUser = profileData.user;
        } catch (error) {
            console.error("Could not fetch current user details:", error);
        }
    };


    // Fetches all groups for the user and displays them on the page
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

                    // --- REVISED: Button logic for all roles ---
                    let primaryAction = '';
                    if (group.rank === 'ADMIN' || group.rank === 'SUPERUSER') {
                        primaryAction = `<button class="delete-btn" data-group-id="${group.id}">Delete Group</button>`;
                    } else if (group.rank === 'MEMBER') {
                        primaryAction = `<button class="leave-btn" data-group-id="${group.id}">Leave Group</button>`;
                    }

                    const memberButtonText = (group.rank === 'ADMIN' || group.rank === 'SUPERUSER') ? 'Manage Members' : 'View Members';
                    const memberButton = `<button class="view-members-btn" data-group-id="${group.id}" data-rank="${group.rank}">${memberButtonText}</button>`;
                    
                    const formattedDate = formatDateTime(group.date_created);

                    groupElement.innerHTML = `
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <h3>${group.name} | ID: ${group.id}</h3>
                            <div class="group-actions">
                                ${primaryAction}
                                ${memberButton}
                            </div>
                        </div>
                        <p><strong>Invite Code:</strong> ${group.invite_code}</p>
                        <p><strong>Created on:</strong> ${formattedDate}</p>
                        <p><strong>Your Rank:</strong> ${group.rank}</p> 
                        <p><strong>Anti-Cheat:</strong> ${group.anticheat ? 'Enabled' : 'Disabled'} | <strong>Kiosk Mode:</strong> ${group.kiosk ? 'Enabled' : 'Disabled'}</p>
                        <div class="member-list-container" id="members-${group.id}" style="display: none;"></div>
                    `;
                    groupsContainer.appendChild(groupElement);
                });
            }
        } catch (error) {
            groupsContainer.innerHTML = `<p style="color: red;">Error: ${error.message}</p>`;
        }
    };
    
    // --- UPDATED: Function now accepts the user's rank in the group ---
    const fetchAndDisplayMembers = async (groupId, container, currentUserRank) => {
        container.innerHTML = '<p>Loading members...</p>';
        try {
            const response = await fetch(`/api/groups/${groupId}/members`, {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            if (!response.ok) throw new Error(await handleApiError(response));
            const members = await response.json();
            
            let membersHTML = '<h4>Group Members:</h4><ul>';
            members.forEach(member => {
                let kickButtonHTML = '';
                // --- REVISED: Show kick button ONLY if the viewer is an admin ---
                if ((currentUserRank === 'ADMIN' || currentUserRank === 'SUPERUSER') && currentUser && currentUser.id !== member.user.id) {
                    kickButtonHTML = `<button class="kick-member-btn" data-group-id="${groupId}" data-user-id="${member.user.id}">Kick</button>`;
                }

                const displayName = member.user.profile.nickname || member.user.username;

                // --- ADDED: style="color: white;" to the list item ---
                membersHTML += `
                    <li style="color: white; display: flex; justify-content: space-between; align-items: center; padding: 5px 0;">
                        <span>${displayName} (${member.rank})</span>
                        ${kickButtonHTML}
                    </li>
                `;
            });
            membersHTML += '</ul>';
            container.innerHTML = membersHTML;

        } catch (error) {
            container.innerHTML = `<p style="color: red;">Error: ${error.message}</p>`;
        }
    };


    // Event listener for all actions within the groups container
    groupsContainer.addEventListener('click', async (event) => {
        if (!token) return alert('Please log in.');

        const processAction = async (url, method, confirmMsg) => {
            if (confirm(confirmMsg)) {
                try {
                    const response = await fetch(url, { method: method, headers: { 'Authorization': `Bearer ${token}` }});
                    if (!response.ok) throw new Error(await handleApiError(response));
                    fetchAndDisplayGroups();
                } catch (error) { alert(`Error: ${error.message}`); }
            }
        };

        if (event.target.matches('.delete-btn')) {
            const groupId = event.target.dataset.groupId;
            processAction(`/api/groups/${groupId}`, 'DELETE', `Are you sure you want to DELETE group ID ${groupId}? This cannot be undone.`);
        }
        if (event.target.matches('.leave-btn')) {
            const groupId = event.target.dataset.groupId;
            processAction(`/api/groups/${groupId}/leave`, 'DELETE', `Are you sure you want to LEAVE group ID ${groupId}?`);
        }
        
        // --- UPDATED: Now handles the generic ".view-members-btn" ---
        if (event.target.matches('.view-members-btn')) {
            const button = event.target;
            const groupId = button.dataset.groupId;
            const currentUserRank = button.dataset.rank; // Get the rank from the button
            const container = document.getElementById(`members-${groupId}`);

            if (container.style.display === 'none') {
                container.style.display = 'block';
                button.textContent = 'Hide Members';
                fetchAndDisplayMembers(groupId, container, currentUserRank); // Pass the rank
            } else {
                container.style.display = 'none';
                button.textContent = (currentUserRank === 'ADMIN' || currentUserRank === 'SUPERUSER') ? 'Manage Members' : 'View Members';
                container.innerHTML = '';
            }
        }
        
        if (event.target.matches('.kick-member-btn')) {
            const groupId = event.target.dataset.groupId;
            const userIdToKick = event.target.dataset.userId;
            const adminRank = document.querySelector(`.view-members-btn[data-group-id="${groupId}"]`).dataset.rank;
            
            if (confirm(`Are you sure you want to kick user ID ${userIdToKick} from the group?`)) {
                try {
                    const response = await fetch(`/api/groups/${groupId}/members/${userIdToKick}`, {
                        method: 'DELETE',
                        headers: { 'Authorization': `Bearer ${token}` }
                    });
                    if (!response.ok) throw new Error(await handleApiError(response));
                    
                    const container = document.getElementById(`members-${groupId}`);
                    fetchAndDisplayMembers(groupId, container, adminRank);

                } catch (error) {
                    alert(`Error: ${error.message}`);
                }
            }
        }
    });

    // --- FORM SUBMISSION HANDLERS (No changes below this line) ---

    createGroupForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        if (!token) return alert('You must be logged in to create a group.');
        const groupName = groupNameInput.value.trim();
        if (!groupName) return alert('Please enter a name for the group.');
        try {
            const response = await fetch('/api/groups/', { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }, body: JSON.stringify({ name: groupName }) });
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
            const response = await fetch('/api/groups/join', { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }, body: JSON.stringify({ invite_code: inviteCode }) });
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
    await fetchCurrentUser();
    fetchAndDisplayGroups();
});