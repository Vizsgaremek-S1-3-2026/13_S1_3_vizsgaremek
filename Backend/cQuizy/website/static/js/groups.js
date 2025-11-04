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
    // --- Elements for existing forms ---
    const createGroupForm = document.getElementById('formCreateGroup');
    const groupNameInput = document.getElementById('groupNameInput');
    const joinGroupForm = document.getElementById('formJoinGroup');
    const groupInviteInput = document.getElementById('groupInviteInput');
    const groupsContainer = document.getElementById('groupsContainer');

    // --- UPDATED: Get elements for Rename and Transfer forms based on new HTML ---
    const renameGroupForm = document.getElementById('formRenameGroup'); // Using corrected ID
    const groupRenameIdInput = document.getElementById('groupRenameId');
    const groupRenameNameInput = document.getElementById('groupRenameName');
    
    const transferGroupForm = document.getElementById('formTransferGroup');
    const groupTransferIdInput = document.getElementById('groupTransferId');
    const groupTransferUserInput = document.getElementById('groupTransferUser');


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

                    let actionButtonHTML = '';
                    if (group.rank === 'ADMIN' || group.rank === 'SUPERUSER') {
                        actionButtonHTML = `<button class="delete-btn" data-group-id="${group.id}">Delete Group</button>`;
                    } else if (group.rank === 'MEMBER') {
                        actionButtonHTML = `<button class="leave-btn" data-group-id="${group.id}">Leave Group</button>`;
                    }

                    const formattedDate = formatDateTime(group.date_created);

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

    // Event listener for Delete and Leave buttons
    groupsContainer.addEventListener('click', async (event) => {
        const token = localStorage.getItem('authToken');
        if (!token) return alert('Please log in.');

        if (event.target.matches('.delete-btn')) {
            const groupId = event.target.dataset.groupId;
            if (confirm(`Are you sure you want to DELETE group ID ${groupId}? This cannot be undone.`)) {
                try {
                    const response = await fetch(`/api/groups/${groupId}`, {
                        method: 'DELETE',
                        headers: { 'Authorization': `Bearer ${token}` }
                    });
                    if (!response.ok) throw new Error((await response.json()).detail || 'Failed to delete group.');
                    fetchAndDisplayGroups();
                } catch (error) {
                    alert(`Error: ${error.message}`);
                }
            }
        }

        if (event.target.matches('.leave-btn')) {
            const groupId = event.target.dataset.groupId;
            if (confirm(`Are you sure you want to LEAVE group ID ${groupId}?`)) {
                try {
                    const response = await fetch(`/api/groups/${groupId}/leave`, {
                        method: 'DELETE',
                        headers: { 'Authorization': `Bearer ${token}` }
                    });
                    if (!response.ok) throw new Error((await response.json()).detail || 'Failed to leave group.');
                    fetchAndDisplayGroups();
                } catch (error) {
                    alert(`Error: ${error.message}`);
                }
            }
        }
    });

    // Handles "Create Group" form
    createGroupForm.addEventListener('submit', async (event) => {
        event.preventDefault();
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
            createGroupForm.reset();
            fetchAndDisplayGroups();
        } catch (error) {
            alert(`Error: ${error.message}`);
        }
    });

    // Handles "Join Group" form
    joinGroupForm.addEventListener('submit', async (event) => {
        event.preventDefault();
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
            joinGroupForm.reset();
            fetchAndDisplayGroups();
        } catch (error) {
            alert(`Error: ${error.message}`);
        }
    });

    // --- UPDATED: Handles submission for the "Rename Group" form ---
    renameGroupForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        const token = localStorage.getItem('authToken');
        if (!token) return alert('You must be logged in.');

        const groupId = groupRenameIdInput.value.trim();
        const newName = groupRenameNameInput.value.trim();

        if (!groupId || !newName) return alert('Please provide both a Group ID and a new name.');

        try {
            const response = await fetch(`/api/groups/${groupId}/rename`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
                body: JSON.stringify({ name: newName })
            });
            if (!response.ok) throw new Error((await response.json()).detail || 'Failed to rename group.');
            
            alert('Group renamed successfully!');
            renameGroupForm.reset();
            fetchAndDisplayGroups();
        } catch (error) {
            alert(`Error: ${error.message}`);
        }
    });

    // --- UPDATED: Handles submission for the "Transfer Ownership" form ---
    transferGroupForm.addEventListener('submit', async (event) => {
        event.preventDefault();
        const token = localStorage.getItem('authToken');
        if (!token) return alert('You must be logged in.');

        const groupId = groupTransferIdInput.value.trim();
        const newOwnerId = groupTransferUserInput.value.trim();

        if (!groupId || !newOwnerId) return alert("Please provide both a Group ID and the new owner's User ID.");

        try {
            const response = await fetch(`/api/groups/${groupId}/transfer_ownership`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
                body: JSON.stringify({ user_id: parseInt(newOwnerId) })
            });
            if (!response.ok) throw new Error((await response.json()).detail || 'Failed to transfer ownership.');
            
            alert('Ownership transferred successfully!');
            transferGroupForm.reset();
            fetchAndDisplayGroups();
        } catch (error) {
            alert(`Error: ${error.message}`);
        }
    });

    // Initial load
    fetchAndDisplayGroups();
});