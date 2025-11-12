// static/js/profile.js

document.addEventListener('DOMContentLoaded', () => {
    // First, we get the authentication token from local storage.
    const token = localStorage.getItem('authToken');
    // If no token exists, the user is not logged in. We immediately redirect
    // them to the login page to prevent them from seeing a broken profile page.
    if (!token) {
        window.location.href = '/login/';
        return; // Stop executing the rest of the script.
    }

    // --- 1. FUNCTION TO LOAD AND DISPLAY USER DATA ---
    const loadUserData = async () => {
        try {
            // We fetch the current user's data from the new '/api/users/me' endpoint.
            const response = await fetch('/api/users/me', {
                headers: { 'Authorization': `Bearer ${token}` }
            });

            // If the response is not 'ok' (e.g., 401 Unauthorized if the token is bad),
            // it means our token is invalid. We should log the user out.
            if (!response.ok) {
                localStorage.removeItem('authToken');
                window.location.href = '/login/';
                return;
            }

            // The response is good, so we parse the JSON body.
            const user = await response.json();

            // We determine the name to display. If the user has a nickname, we use that.
            // Otherwise, we fall back to their username.
            const displayName = user.nickname || user.username;
            document.getElementById('welcomeName').textContent = `Welcome, ${displayName}!`;
            
            // Populate the main profile elements with the user's data.
            document.getElementById('profilePfp').src = user.pfp_url;

            // Populate the "current" data fields in the various forms to give the user context.
            document.getElementById('currentNickname').textContent = `Current Nickname: ${user.nickname || 'Not set'}`;
            document.getElementById('currentName').textContent = `Current Name: ${user.first_name} ${user.last_name}`;
            document.getElementById('currentEmail').textContent = `Current Email: ${user.email}`;
            document.getElementById('currentUsername').textContent = `Your Username: ${user.username}`;

        } catch (error) {
            console.error('Failed to load user data:', error);
            alert('Could not load your data. Please try again later.');
        }
    };

    // We call this function once when the page loads to populate it with data.
    loadUserData();

    // --- 2. HELPER FUNCTION FOR MAKING AUTHENTICATED API CALLS ---
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
                // After a successful update, we call loadUserData() again to refresh
                // the displayed information with the latest data from the server.
                loadUserData();
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

    // --- 3. ADD EVENT LISTENERS FOR ALL SEPARATE FORMS ---

    // Event listener for the "Set Nickname" form
    document.getElementById('formSetNickname').addEventListener('submit', (e) => {
        e.preventDefault();
        const nickname = e.target.querySelector('input[type="text"]').value;
        // All simple profile updates go to the PATCH /me endpoint.
        apiCall('/api/users/me', 'PATCH', { nickname });
    });

    // Event listener for the "Set Name" form
    document.getElementById('formSetName').addEventListener('submit', (e) => {
        e.preventDefault();
        const inputs = e.target.querySelectorAll('input[type="text"]');
        const firstName = inputs[0].value;
        const lastName = inputs[1].value;
        // This also goes to the PATCH /me endpoint.
        apiCall('/api/users/me', 'PATCH', { first_name: firstName, last_name: lastName });
    });
    
    // Event listener for the "Change Profile picture" form
    document.getElementById('formSetPfp').addEventListener('submit', (e) => {
        e.preventDefault();
        const pfp_url = e.target.querySelector('input[type="text"]').value;
        // This also goes to the PATCH /me endpoint.
        apiCall('/api/users/me', 'PATCH', { pfp_url });
    });

    // Event listener for the "Change Email" form
    document.getElementById('formSetEmail').addEventListener('submit', (e) => {
        e.preventDefault();
        const email = e.target.querySelector('input[type="text"]').value;
        const password = e.target.querySelector('input[type="password"]').value;
        // This is a high-risk action and uses its own endpoint.
        apiCall('/api/users/me/change-email', 'POST', { email, password });
    });

    // Event listener for the "Change Password" form
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
        // This is a high-risk action and uses its own endpoint.
        apiCall('/api/users/me/change-password', 'POST', { old_password, new_password });
    });

    // Event listener for the "Delete Account" form
    document.getElementById('formSetDelete').addEventListener('submit', async (e) => {
        e.preventDefault();
        // We get the password for confirmation from the password input field.
        const password = e.target.querySelector('input[type="password"]').value;
        // The username input is not needed for the API call, but we can keep the frontend check.
        const usernameInput = e.target.querySelector('input[type="text"]').value;
        const currentUsername = document.getElementById('currentUsername').textContent.replace('Your Username: ', '');

        if (usernameInput !== currentUsername) {
            alert('The username you entered does not match your current username.');
            return;
        }

        if (confirm('Are you absolutely sure you want to delete your account? This action cannot be undone.')) {
            // We use the new '/api/users/me' DELETE endpoint.
            const response = await fetch('/api/users/me', {
                method: 'DELETE',
                headers: { 
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}` 
                },
                // The API now requires the password in the request body for security.
                body: JSON.stringify({ password: password })
            });

            if (response.ok) {
                localStorage.removeItem('authToken');
                alert('Account deleted successfully.');
                window.location.href = '/';
            } else {
                 const errorData = await response.json();
                 alert(`Error: ${errorData.detail || 'An unknown error occurred.'}`);
            }
        }
    });
});