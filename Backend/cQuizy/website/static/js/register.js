// static/js/register.js

document.addEventListener('DOMContentLoaded', () => {
    const registerForm = document.getElementById('registerForm');
    const messageDiv = document.getElementById('message');
    
    // Get a reference to the submit button
    const submitButton = registerForm.querySelector('button[type="submit"]');

    registerForm.addEventListener('submit', async (event) => {
        // 1. Prevent the form from doing a full page reload
        event.preventDefault();

        // 2. Disable the button to prevent multiple clicks and update its text
        submitButton.disabled = true;
        submitButton.textContent = 'Registering...';
        messageDiv.textContent = ''; // Clear any previous error messages

        // 3. Gather all the data from the input fields
        const lastName = document.getElementById('register-lastname').value;
        const firstName = document.getElementById('register-firstname').value;
        const username = document.getElementById('register-username').value;
        const nickname = document.getElementById('register-nickname').value;
        const email = document.getElementById('register-email').value;
        const password = document.getElementById('register-password').value;
        const passwordRepeat = document.getElementById('register-password-repeat').value;
        const pfpUrl = document.getElementById('register-pfp-url').value;

        // 4. Perform a quick client-side check to see if passwords match
        if (password !== passwordRepeat) {
            messageDiv.textContent = 'Passwords do not match.';
            messageDiv.style.color = 'red';
            // Re-enable the button so the user can correct their mistake
            submitButton.disabled = false;
            submitButton.textContent = 'Register';
            return; // Stop the function here
        }

        // 5. Create the JSON payload. The keys MUST match your Django Ninja RegisterSchema.
        const payload = {
            last_name: lastName,
            first_name: firstName,
            username: username,
            nickname: nickname,
            email: email,
            password: password,
        };
        
        // Only add the pfp_url to the payload IF the user actually typed something.
        // If we don't send the key, the Django model's `default` will be used.
        if (pfpUrl.trim() !== '') {
            payload.pfp_url = pfpUrl;
        }
        
        // 6. Send the data to your API using fetch
        try {
            const response = await fetch('/api/users/register', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(payload)
            });

            if (response.ok) {
                // Success! No need to re-enable the button, as we are navigating away.
                messageDiv.textContent = 'Registration successful! Redirecting to login...';
                messageDiv.style.color = 'green';
                
                // Wait a moment so the user can read the message, then redirect.
                setTimeout(() => {
                    window.location.href = '/login';
                }, 2000); // 2-second delay
                
            } else {
                // The API returned an error (e.g., username taken)
                const data = await response.json();
                messageDiv.textContent = data.error || 'An unknown error occurred.';
                messageDiv.style.color = 'red';
                // IMPORTANT: Re-enable the button if there's an error so the user can try again.
                submitButton.disabled = false;
                submitButton.textContent = 'Register';
            }

        } catch (error) {
            // This catches network errors (e.g., server is down)
            console.error('Registration failed:', error);
            messageDiv.textContent = 'Could not connect to the server. Please try again later.';
            messageDiv.style.color = 'red';
            // Also re-enable the button on network errors
            submitButton.disabled = false;
            submitButton.textContent = 'Register';
        }
    });
});