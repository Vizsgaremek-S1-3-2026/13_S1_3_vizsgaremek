// static/js/profile.js

document.addEventListener('DOMContentLoaded', () => {
    const token = localStorage.getItem('authToken');
    if (!token) {
        window.location.href = '/login/';
        return;
    }

    // --- 1. FUNCTION TO LOAD AND DISPLAY PROFILE DATA ---
    const loadProfileData = async () => {
        try {
            const response = await fetch('/api/users/profile/me', {
                headers: { 'Authorization': `Bearer ${token}` }
            });

            if (!response.ok) {
                localStorage.removeItem('authToken');
                window.location.href = '/login/';
                return;
            }

            const profile = await response.json();

            // --- CORRECTED LOGIC FOR 'welcomeName' ID ---
            // Determine the name to display. If nickname is null or an empty string, fall back to the username.
            const displayName = profile.nickname || profile.username;
            document.getElementById('welcomeName').textContent = `Welcome, ${displayName}!`;
            
            // Populate main profile elements
            document.getElementById('profilePfp').src = profile.pfp_url;

            // Populate "current" data fields in forms
            // Also adjust the "Current Nickname" display based on whether it's set
            document.getElementById('currentNickname').textContent = `Current Nickname: ${profile.nickname || 'Not set'}`;
            document.getElementById('currentName').textContent = `Current Name: ${profile.first_name} ${profile.last_name}`;
            document.getElementById('currentEmail').textContent = `Current Email: ${profile.email}`;
            document.getElementById('currentUsername').textContent = `Your Username: ${profile.username}`;

        } catch (error) {
            console.error('Failed to load profile data:', error);
            alert('Could not load profile data. Please try again later.');
        }
    };

    // Initial load
    loadProfileData();

    // --- 2. HELPER FUNCTION FOR API CALLS ---
    const apiCall = async (endpoint, method, body) => {
        try {
            const response = await fetch(endpoint, {
                method: method,
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`,
                },
                body: JSON.stringify(body)
            });
            if (response.ok) {
                alert('Update successful!');
                loadProfileData(); // Refresh data on success
            } else {
                const errorData = await response.json();
                const errorMessage = errorData.detail || 'An unknown error occurred.';
                alert(`Error: ${JSON.stringify(errorMessage)}`);
            }
        } catch (error) {
            console.error('API call failed:', error);
            alert('An error occurred while communicating with the server. Please check your connection.');
        }
    };

    // --- 3. ADD EVENT LISTENERS FOR ALL FORMS ---

    // Nickname
    document.getElementById('formSetNickname').addEventListener('submit', (e) => {
        e.preventDefault();
        const nickname = e.target.querySelector('input[type="text"]').value;
        apiCall('/api/users/profile/me', 'PATCH', { nickname });
    });

    // Name
    document.getElementById('formSetName').addEventListener('submit', (e) => {
        e.preventDefault();
        const inputs = e.target.querySelectorAll('input[type="text"]');
        const firstName = inputs[0].value;
        const lastName = inputs[1].value;
        apiCall('/api/users/profile/change-name', 'PATCH', { first_name: firstName, last_name: lastName });
    });
    
    // Profile Picture
    document.getElementById('formSetPfp').addEventListener('submit', (e) => {
        e.preventDefault();
        const pfp_url = e.target.querySelector('input[type="text"]').value;
        apiCall('/api/users/profile/me', 'PATCH', { pfp_url });
    });

    // Email
    document.getElementById('formSetEmail').addEventListener('submit', (e) => {
        e.preventDefault();
        const email = e.target.querySelector('input[type="text"]').value;
        const password = e.target.querySelector('input[type="password"]').value;
        apiCall('/api/users/profile/change-email', 'POST', { email, password });
    });

    // Password
    document.getElementById('formSetPassword').addEventListener('submit', (e) => {
        e.preventDefault();
        const inputs = e.target.querySelectorAll('input[type="password"]');
        const old_password = inputs[0].value;
        const new_password = inputs[1].value;
        const repeat_password = inputs[2].value;

        if (new_password !== repeat_password) {
            alert('The new passwords do not match. Please try again.');
            return;
        }
        apiCall('/api/users/profile/change-password', 'POST', { old_password, new_password });
    });

    // Delete Account
    document.getElementById('formSetDelete').addEventListener('submit', async (e) => {
        e.preventDefault();
        const username = e.target.querySelector('input[type="text"]').value;
        const currentUsername = document.getElementById('currentUsername').textContent.replace('Your Username: ', '');

        if (username !== currentUsername) {
            alert('The username you entered does not match.');
            return;
        }

        if (confirm('Are you absolutely sure you want to delete your account? This cannot be undone.')) {
            const response = await fetch('/api/users/profile/me', {
                method: 'DELETE',
                headers: { 
                    'Authorization': `Bearer ${token}` 
                },
            });

            if (response.ok) {
                localStorage.removeItem('authToken');
                alert('Account deleted successfully.');
                window.location.href = '/';
            } else {
                 const errorData = await response.json();
                 alert(`Error: ${errorData.detail}`);
            }
        }
    });
});