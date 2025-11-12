// static/js/login.js

// We wait for the entire HTML document to be loaded before we try to find elements.
document.addEventListener('DOMContentLoaded', () => {
    // Get references to the form and the message display area.
    const loginForm = document.getElementById('loginForm');
    const messageDiv = document.getElementById('message');

    // Attach an asynchronous event listener to the form's 'submit' event.
    loginForm.addEventListener('submit', async (event) => {
        // 1. Prevent the default browser action of reloading the page on form submission.
        //    This allows us to handle the login process with JavaScript.
        event.preventDefault();

        // 2. Get the current values from the username and password input fields.
        const username = document.getElementById('login-username').value;
        const password = document.getElementById('login-password').value;

        // 3. Send the user's data to our API endpoint using a POST request.
        try {
            const response = await fetch('/api/users/login', {
                method: 'POST',
                headers: {
                    // We must tell the server that we are sending JSON data.
                    'Content-Type': 'application/json',
                },
                // The body of the request must be a JSON string.
                body: JSON.stringify({ username: username, password: password })
            });

            // After the server responds, we parse its JSON response.
            const data = await response.json();

            // 4. Check if the login was successful. A successful response has a 2xx status code.
            if (response.ok) {
                // 5. If successful, store the received JWT in the browser's localStorage.
                //    This token will be used for all future authenticated API requests.
                localStorage.setItem('authToken', data.token);
                // Redirect the user to the homepage after a successful login.
                window.location.href = '/';
            } else {
                // The server responded with an error (e.g., 401 Unauthorized).
                // --- THIS IS THE CORRECTED LINE ---
                // Our new API sends error messages in the 'detail' key.
                messageDiv.textContent = data.detail || 'Login failed. Please check your credentials.';
                messageDiv.style.color = 'red';
            }
        } catch (error) {
            // This 'catch' block handles network errors, like if the server is down.
            console.error('Error during login:', error);
            messageDiv.textContent = 'An unexpected error occurred. Please try again later.';
            messageDiv.style.color = 'red';
        }
    });
});