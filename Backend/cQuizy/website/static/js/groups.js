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

document.addEventListener('DOMContentLoaded', function() {
    // Get all necessary elements from the HTML
    const createGroupForm = document.getElementById('formCreateGroup');
    const groupNameInput = document.getElementById('groupNameInput');
    const joinGroupForm = document.getElementById('formJoinGroup');
    const groupInviteInput = document.getElementById('groupInviteInput');
    const groupsContainer = document.getElementById('groupsContainer');

    // Fetches all groups for the user and displays them on the page
    const fetchAndDisplayGroups = async () => {
        const token = localStorage.getItem('authToken');
        if (!token) {
            groupsContainer.innerHTML = '<p>Please log in to see your groups.</p>';
            return;
        }
        try {
            const response = await fetch('/api/groups/', {
                method: 'GET',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` }
            });
            if (!response.ok) throw new Error('Failed to fetch groups. Your session might have expired.');
            
            const groups = await response.json();
            groupsContainer.innerHTML = '';

            if (groups.length === 0) {
                groupsContainer.innerHTML = '<p>You are not a member of any groups yet. Create or join one!</p>';
            } else {
                groups.forEach(group => {
                    const groupElement = document.createElement('div');
                    groupElement.className = 'groupItem';

                    // --- UPDATED LOGIC FOR CONDITIONAL BUTTONS ---
                    let actionButtonHTML = '';
                    // A "Delete" button appears for actual Admins OR for Superusers
                    if (group.rank === 'ADMIN' || group.rank === 'SUPERUSER') {
                        actionButtonHTML = `<button class="delete-btn" data-group-id="${group.id}">Delete Group</button>`;
                    } 
                    // A "Leave" button ONLY appears for actual Members
                    else if (group.rank === 'MEMBER') {
                        actionButtonHTML = `<button class="leave-btn" data-group-id="${group.id}">Leave Group</button>`;
                    }

                    const formattedDate = formatDateTime(group.date_created);

                    // Build the complete HTML for the group item
                    groupElement.innerHTML = `
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <h3>${group.name} | ID: ${group.id}</h3>
                            ${actionButtonHTML}
                        </div>
                        <p><strong>Invite Code:</strong> ${group.invite_code}</p>
                        <p><strong>Created on:</strong> ${formattedDate}</p>
                        <p><strong>Your Rank:</strong> ${group.rank}</p> 
                    `;
                    groupsContainer.appendChild(groupElement);
                });
            }
        } catch (error) {
            groupsContainer.innerHTML = `<p style="color: red;">Error: ${error.message}</p>`;
        }
    };

    // Single event listener on the container to handle clicks for both Delete and Leave buttons
    groupsContainer.addEventListener('click', async (event) => {
        const token = localStorage.getItem('authToken');
        if (!token) return alert('Please log in.');

        // Handle Delete Button Click
        if (event.target.matches('.delete-btn')) {
            const groupId = event.target.dataset.groupId;
            if (confirm(`Are you sure you want to DELETE group ID ${groupId}? This cannot be undone.`)) {
                try {
                    const response = await fetch(`/api/groups/${groupId}`, {
                        method: 'DELETE',
                        headers: { 'Authorization': `Bearer ${token}` }
                    });
                    if (!response.ok) throw new Error((await response.json()).detail || 'Failed to delete group.');
                    fetchAndDisplayGroups(); // Refresh the list
                } catch (error) {
                    alert(`Error: ${error.message}`);
                }
            }
        }

        // Handle Leave Button Click
        if (event.target.matches('.leave-btn')) {
            const groupId = event.target.dataset.groupId;
            if (confirm(`Are you sure you want to LEAVE group ID ${groupId}?`)) {
                try {
                    const response = await fetch(`/api/groups/${groupId}/leave`, {
                        method: 'DELETE',
                        headers: { 'Authorization': `Bearer ${token}` }
                    });
                    if (!response.ok) throw new Error((await response.json()).detail || 'Failed to leave group.');
                    fetchAndDisplayGroups(); // Refresh the list
                } catch (error) {
                    alert(`Error: ${error.message}`);
                }
            }
        }
    });

    // Handles the submission of the "Create Group" form
    createGroupForm.addEventListener('submit', async (event) => {
        event.preventDefault(); // Prevents the page from reloading
        const token = localStorage.getItem('authToken');
        if (!token) return alert('You must be logged in to create a group.');
        const groupName = groupNameInput.value.trim();
        if (!groupName) return alert('Please enter a name for the group.');
        try {
            const response = await fetch('/api/groups/', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
                body: JSON.stringify({ name: groupName })
            });
            if (!response.ok) throw new Error((await response.json()).detail || 'Failed to create group.');
            groupNameInput.value = '';
            fetchAndDisplayGroups();
        } catch (error) {
            alert(`Error: ${error.message}`);
        }
    });

    // Handles the submission of the "Join Group" form
    joinGroupForm.addEventListener('submit', async (event) => {
        event.preventDefault(); // Prevents the page from reloading
        const token = localStorage.getItem('authToken');
        if (!token) return alert('You must be logged in to join a group.');
        const inviteCode = groupInviteInput.value.trim();
        if (!inviteCode) return alert('Please enter an invite code.');
        try {
            const response = await fetch('/api/groups/join', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
                body: JSON.stringify({ invite_code: inviteCode })
            });
            if (!response.ok) throw new Error((await response.json()).detail || 'Failed to join group.');
            groupInviteInput.value = '';
            fetchAndDisplayGroups();
        } catch (error) {
            alert(`Error: ${error.message}`);
        }
    });

    // Initial action: Fetch and display the groups as soon as the page loads.
    fetchAndDisplayGroups();
});