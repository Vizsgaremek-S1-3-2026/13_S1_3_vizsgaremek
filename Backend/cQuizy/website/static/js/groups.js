// static/js/groups.js

/**
 * Helper function to format ISO 8601 date strings into a more readable format.
 * @param {string} isoString - The ISO date string from the API.
 * @returns {string} A formatted date string (e.g., "2025. 11. 12. 09:30:00").
 */
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

/**
 * A robust helper function to parse and return a user-friendly error message
 * from a failed API response.
 * @param {Response} response - The raw response object from a failed fetch call.
 * @returns {Promise<string>} A promise that resolves to the error message.
 */
async function handleApiError(response) {
    try {
        const errorData = await response.json();
        // Ninja often returns errors in a 'detail' key.
        return errorData.detail || JSON.stringify(errorData);
    } catch (e) {
        // If the response body isn't JSON, fall back to the status text.
        return response.statusText || 'An unexpected error occurred.';
    }
}

document.addEventListener('DOMContentLoaded', async function() {
    // This is the main container where all the group information will be displayed.
    const groupsContainer = document.getElementById('groupsContainer');
    // We need the auth token for all our API calls.
    const token = localStorage.getItem('authToken');

    // --- References to all form elements on the page ---
    const createGroupForm = document.getElementById('formCreateGroup');
    const joinGroupForm = document.getElementById('formJoinGroup');
    const updateGroupForm = document.getElementById('formUpdateGroup');
    const regenerateCodeForm = document.getElementById('formRegenerateCode');
    const transferGroupForm = document.getElementById('formTransferGroup');

    // --- References to all input elements for the forms ---
    const groupNameInput = document.getElementById('groupNameInput');
    const groupInviteInput = document.getElementById('groupInviteInput');
    const groupTransferIdInput = document.getElementById('groupTransferId');
    const groupTransferUserInput = document.getElementById('groupTransferUser');
    const groupUpdateIdInput = document.getElementById('groupUpdateId');
    const groupUpdateNameInput = document.getElementById('groupUpdateName');
    const groupUpdateAnticheatInput = document.getElementById('groupUpdateAnticheat');
    const groupUpdateKioskInput = document.getElementById('groupUpdateKiosk');
    const groupRegenerateIdInput = document.getElementById('groupRegenerateId');


    /**
     * Fetches all groups for the current user from the API and renders them on the page.
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
            groupsContainer.innerHTML = ''; // Clear the container before rendering

            if (groups.length === 0) {
                groupsContainer.innerHTML = '<p>You are not a member of any groups yet. Create or join one!</p>';
            } else {
                groups.forEach(group => {
                    const groupElement = document.createElement('div');
                    groupElement.className = 'groupItem';

                    // Determine the primary action button based on the user's rank in the group.
                    // Admins and Superusers can delete the group; regular members can only leave it.
                    let primaryAction = '';
                    if (group.rank === 'ADMIN' || group.rank === 'SUPERUSER') {
                        primaryAction = `<button class="delete-btn" data-group-id="${group.id}">Delete Group</button>`;
                    } else {
                        primaryAction = `<button class="leave-btn" data-group-id="${group.id}">Leave Group</button>`;
                    }

                    // We store the user's rank on the "View Members" button so we can access it later
                    // to decide whether to show "Kick" buttons.
                    const memberButton = `<button class="view-members-btn" data-group-id="${group.id}" data-user-rank="${group.rank}">View Members</button>`;
                    
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
    
    /**
     * Fetches and displays the member list for a specific group inside its container.
     * @param {string} groupId - The ID of the group to fetch members for.
     * @param {HTMLElement} container - The container element to render the list into.
     * @param {string} currentUserRank - The rank of the user viewing the list ('ADMIN', 'MEMBER', etc.).
     */
    const displayMembers = async (groupId, container, currentUserRank) => {
        container.innerHTML = '<p>Loading members...</p>';
        try {
            const response = await fetch(`/api/groups/${groupId}/members`, {
                headers: { 'Authorization': `Bearer ${token}` }
            });
            if (!response.ok) throw new Error(await handleApiError(response));
            const members = await response.json();
            
            let membersHTML = '<h4>Group Members:</h4><ul>';
            const canKick = currentUserRank === 'ADMIN' || currentUserRank === 'SUPERUSER';
            
            members.forEach(member => {
                // --- THIS IS THE CORRECTED LINE ---
                // The nickname is now directly on the user object, not a nested profile object.
                const displayName = member.user.nickname || member.user.username;
                
                // Determine if a "Kick" button should be shown for this member.
                let kickButtonHTML = '';
                // The user can kick if they are an admin AND the target member is not also an admin.
                if (canKick && member.rank !== 'ADMIN') {
                    kickButtonHTML = `<button class="kick-btn" data-group-id="${groupId}" data-user-id="${member.user.id}">Kick</button>`;
                }

                membersHTML += `
                    <li style="color: white; display: flex; justify-content: space-between; align-items: center; padding: 5px 0;">
                        <span>${displayName} (${member.rank}) | User ID: ${member.user.id}</span>
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


    // We use a single event listener on the main container to handle all button clicks
    // inside the group items. This is more efficient than adding a listener to every button.
    groupsContainer.addEventListener('click', async (event) => {
        if (!token) return alert('Please log in.');

        const deleteBtn = event.target.closest('.delete-btn');
        const leaveBtn = event.target.closest('.leave-btn');
        const viewMembersBtn = event.target.closest('.view-members-btn');
        const kickBtn = event.target.closest('.kick-btn');

        // A generic function to handle actions that require confirmation.
        const processAction = async (url, method, confirmMsg) => {
            if (confirm(confirmMsg)) {
                try {
                    const response = await fetch(url, { method: method, headers: { 'Authorization': `Bearer ${token}` }});
                    if (!response.ok) throw new Error(await handleApiError(response));
                    // After a successful action, refresh the whole list of groups.
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
        
        if (viewMembersBtn) {
            const groupId = viewMembersBtn.dataset.groupId;
            const userRank = viewMembersBtn.dataset.userRank;
            const container = document.getElementById(`members-${groupId}`);

            // Toggle the visibility of the member list container.
            if (container.style.display === 'none') {
                container.style.display = 'block';
                viewMembersBtn.textContent = 'Hide Members';
                // Fetch and display the members when showing the list.
                displayMembers(groupId, container, userRank);
            } else {
                container.style.display = 'none';
                viewMembersBtn.textContent = 'View Members';
                container.innerHTML = ''; // Clear the list when hiding.
            }
            return;
        }

        // Handle the click on a "Kick" button.
        if (kickBtn) {
            const groupId = kickBtn.dataset.groupId;
            const userId = kickBtn.dataset.userId;

            if (confirm(`Are you sure you want to remove user ID ${userId} from the group?`)) {
                try {
                    const response = await fetch(`/api/groups/${groupId}/members/${userId}`, {
                        method: 'DELETE',
                        headers: { 'Authorization': `Bearer ${token}` }
                    });
                    if (!response.ok) throw new Error(await handleApiError(response));
                    
                    // After a successful kick, we just refresh the member list for that specific group
                    // instead of the whole page, which is a better user experience.
                    const container = kickBtn.closest('.member-list-container');
                    const viewButton = container.parentElement.querySelector('.view-members-btn');
                    const currentUserRank = viewButton.dataset.userRank;
                    displayMembers(groupId, container, currentUserRank);

                } catch (error) {
                    alert(`Error: ${error.message}`);
                }
            }
            return;
        }
    });

    // --- FORM SUBMISSION HANDLERS ---
    // All of the form handlers below were already correct and did not need changes.

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
    // This is the first thing that runs after the page is ready and the listeners are set up.
    fetchAndDisplayGroups();
});