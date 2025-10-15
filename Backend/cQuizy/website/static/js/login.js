document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('loginForm');
    const messageDiv = document.getElementById('message');

    loginForm.addEventListener('submit', async (event) => {
        // 1. Prevent the default page reload
        event.preventDefault();

        // 2. Get the user's input
        const username = document.getElementById('login-username').value;
        const password = document.getElementById('login-password').value;

        // 3. Send the data to your API endpoint
        try {
            const response = await fetch('/api/users/login', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ username: username, password: password })
            });

            const data = await response.json();

            // 4. Check if the login was successful
            if (response.ok) {
                // 5. Store the token and redirect
                localStorage.setItem('authToken', data.token);
                window.location.href = '/'; // Redirect to the homepage
            } else {
                // Display the error message from the API
                messageDiv.textContent = data.error || 'Login failed.';
                messageDiv.style.color = 'red';
            }
        } catch (error) {
            console.error('Error during login:', error);
            messageDiv.textContent = 'An unexpected error occurred.';
            messageDiv.style.color = 'red';
        }
    });
});