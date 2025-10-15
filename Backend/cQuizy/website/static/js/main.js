// static/js/main.js

document.addEventListener('DOMContentLoaded', () => {
    // This function will run as soon as the page's HTML is loaded
    updateHeader();
});

async function updateHeader() {
    const navRightContainer = document.querySelector('.nav-right');
    const token = localStorage.getItem('authToken');

    if (token) {
        // A token exists in storage. Let's verify it with the server.
        try {
            const response = await fetch('/api/users/profile/me', {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${token}`
                }
            });

            if (response.ok) {
                // The token is valid and we got the user's profile data
                const profile = await response.json();
                renderLoggedInHeader(navRightContainer, profile);
            } else {
                // The token is invalid (maybe expired or fake).
                // Clear the bad token and show the default header.
                localStorage.removeItem('authToken');
                renderLoggedOutHeader(navRightContainer);
            }
        } catch (error) {
            // This happens if the server is down or there's a network issue.
            console.error("Error verifying token:", error);
            renderLoggedOutHeader(navRightContainer);
        }
    } else {
        // No token was found in localStorage. Show the default header.
        renderLoggedOutHeader(navRightContainer);
    }
}

function renderLoggedInHeader(container, profile) {
    // This function replaces the HTML inside the .nav-right div
    // with the template for a logged-in user.
    container.innerHTML = `
        <a class="nav-button" href="/session-logout/">Log Out</a>
        <a class="nav-item profile-link" href="/profile/">
            <span>${profile.username}</span>
            <img class="nav-pfp" src="${profile.pfp_url}" alt="Profile Picture">
        </a>
    `;

    // ** THE UNIFIED LOGOUT LOGIC **
    // Find the new logout button we just created.
    const logoutButton = container.querySelector('a[href="/session-logout/"]');
    
    // Add an event listener that runs *before* the browser navigates away.
    logoutButton.addEventListener('click', (event) => {
        // This clears the JWT token that our API uses.
        localStorage.removeItem('authToken');
        // After this runs, the browser will continue to navigate to the href,
        // which will clear the Django session cookie.
    });
}

function renderLoggedOutHeader(container) {
    // This function sets the default HTML for a logged-out user.
    container.innerHTML = `
        <a class="nav-button" href="/login/">Log In</a>
        <a class="nav-button" href="/register/">Register</a>
    `;
}