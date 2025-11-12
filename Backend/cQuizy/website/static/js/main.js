// static/js/main.js

/**
 * This script handles the dynamic updating of the website's navigation header.
 * It checks if a user is logged in by verifying a token with the backend API
 * and then renders the appropriate header for a logged-in or logged-out state.
 */

// We add an event listener to the document that waits for the initial HTML
// content to be fully loaded and parsed before running our script.
document.addEventListener('DOMContentLoaded', () => {
    // This function will run as soon as the page is ready.
    updateHeader();
});

/**
 * Asynchronously checks for an authentication token in localStorage and fetches
 * the current user's data from the API to determine the login state.
 */
async function updateHeader() {
    // Find the container in the navigation bar where the dynamic buttons will be placed.
    const navRightContainer = document.querySelector('.nav-right');
    // Retrieve the JWT authentication token from the browser's local storage.
    const token = localStorage.getItem('authToken');

    if (token) {
        // A token exists in storage. Let's verify it with the server to ensure it's still valid.
        try {
            // Make an authenticated GET request to our API's '/api/users/me' endpoint.
            // This endpoint returns the data for the user associated with the provided token.
            const response = await fetch('/api/users/me', {
                method: 'GET',
                headers: {
                    // The 'Authorization' header is the standard way to send a JWT.
                    'Authorization': `Bearer ${token}`
                }
            });

            if (response.ok) {
                // The token is valid (response status is 2xx).
                // We can now parse the JSON body of the response to get the user's data.
                const user = await response.json();
                renderLoggedInHeader(navRightContainer, user);
            } else {
                // The token is invalid (e.g., expired, malformed, or the user was deleted).
                // The server responded with a 4xx error.
                // For security, we remove the bad token from storage and show the default header.
                localStorage.removeItem('authToken');
                renderLoggedOutHeader(navRightContainer);
            }
        } catch (error) {
            // This catch block handles network errors, such as if the server is down
            // or the user has lost internet connection.
            console.error("Error verifying token with the server:", error);
            renderLoggedOutHeader(navRightContainer);
        }
    } else {
        // No token was found in localStorage. We assume the user is not logged in.
        renderLoggedOutHeader(navRightContainer);
    }
}

/**
 * Renders the header for an authenticated user, displaying their name and profile picture.
 * @param {HTMLElement} container - The container element to inject the HTML into.
 * @param {object} user - The user data object returned from the API.
 */
function renderLoggedInHeader(container, user) {
    // This function replaces the HTML inside the .nav-right div
    // with a template for a logged-in user.
    // We use a template literal for clean, multi-line HTML.
    // It's good practice to show the user's nickname if they have one,
    // otherwise, fall back to showing their username.
    container.innerHTML = `
        <a class="nav-button" href="/session-logout/">Log Out</a>
        <a class="nav-item profile-link" href="/profile/">
            <span>${user.nickname || user.username}</span>
            <img class="nav-pfp" src="${user.pfp_url}" alt="Profile Picture">
        </a>
    `;

    // ** UNIFIED LOGOUT LOGIC **
    // After creating the logout button, we need to attach our logout logic to it.
    const logoutButton = container.querySelector('a[href="/session-logout/"]');
    
    // We add a 'click' event listener. This function will run right after the user
    // clicks the button, but *before* the browser navigates to the href URL.
    logoutButton.addEventListener('click', (event) => {
        // This clears the JWT token that our JavaScript API uses for authentication.
        localStorage.removeItem('authToken');
        // After this listener finishes, the browser's default action takes over,
        // navigating to '/session-logout/', which is a Django view that will
        // clear the server-side session cookie (used for the Django Admin).
    });
}

/**
 * Renders the default header for a logged-out user with "Log In" and "Register" buttons.
 * @param {HTMLElement} container - The container element to inject the HTML into.
 */
function renderLoggedOutHeader(container) {
    // This function sets the default HTML for a visitor or logged-out user.
    container.innerHTML = `
        <a class="nav-button" href="/login/">Log In</a>
        <a class="nav-button" href="/register/">Register</a>
    `;
}