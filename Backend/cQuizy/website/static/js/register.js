// static/js/register.js

// We wait for the entire HTML document to be loaded before we attach event listeners.
document.addEventListener('DOMContentLoaded', () => {
    // Get references to the form, the message display area, and the submit button.
    const registerForm = document.getElementById('registerForm');
    const messageDiv = document.getElementById('message');
    const submitButton = registerForm.querySelector('button[type="submit"]');

    // This is a state variable to prevent the user from submitting the form multiple times
    // while waiting for a response from the server.
    let isSubmitting = false;

    registerForm.addEventListener('submit', async (event) => {
        // Prevent the default browser action of reloading the page on form submission.
        event.preventDefault();

        // If the form is already in the process of submitting, we do nothing.
        // This prevents creating duplicate accounts if the user clicks the button rapidly.
        if (isSubmitting) {
            return;
        }

        // --- ENGAGE THE SUBMISSION LOCK ---
        // We set our state variable and disable the button to provide clear visual feedback.
        isSubmitting = true;
        submitButton.disabled = true;
        submitButton.textContent = 'Registering...';
        messageDiv.textContent = ''; // Clear any previous error messages.

        // Gather all the data from the form's input fields.
        const lastName = document.getElementById('register-lastname').value;
        const firstName = document.getElementById('register-firstname').value;
        const username = document.getElementById('register-username').value;
        const nickname = document.getElementById('register-nickname').value;
        const email = document.getElementById('register-email').value;
        const password = document.getElementById('register-password').value;
        const pfpUrl = document.getElementById('register-pfp-url').value;

        // Construct the payload object that we will send to the API.
        const payload = {
            last_name: lastName,
            first_name: firstName,
            username: username,
            nickname: nickname,
            email: email,
            password: password,
        };
        
        // Only include the pfp_url in the payload if the user actually entered something.
        if (pfpUrl.trim() !== '') {
            payload.pfp_url = pfpUrl;
        }
        
        try {
            // Send the registration data to our API endpoint.
            const response = await fetch('/api/users/register', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            // After the server responds, we check if the registration was successful.
            if (response.ok) {
                messageDiv.textContent = 'Registration successful! You will be redirected to the login page.';
                messageDiv.style.color = 'green';
                // We wait for 2 seconds to allow the user to read the success message
                // before redirecting them to the login page.
                setTimeout(() => { window.location.href = '/login'; }, 2000);
                // We don't need to unlock the form here because we are navigating away.
            } else {
                // The server responded with an error (e.g., 400 Bad Request, 422 Unprocessable Entity).
                const data = await response.json();

                // --- THIS IS THE CORRECTED LINE ---
                // Our new API sends validation errors in the 'detail' key.
                // We handle both single string errors and potential list of validation errors.
                let errorMessage = 'An unknown error occurred.';
                if (data.detail && typeof data.detail === 'string') {
                    errorMessage = data.detail;
                } else if (data.detail && Array.isArray(data.detail)) {
                    // Pydantic validation errors come in a list. We'll format the first one.
                    errorMessage = `${data.detail[0].loc[1]}: ${data.detail[0].msg}`;
                }

                messageDiv.textContent = errorMessage;
                messageDiv.style.color = 'red';

                // --- UNLOCK THE FORM ON FAILURE ---
                // We must re-enable the form so the user can correct their input and try again.
                isSubmitting = false; 
                submitButton.disabled = false;
                submitButton.textContent = 'Register';
            }

        } catch (error) {
            // This 'catch' block handles network errors.
            console.error('Registration failed:', error);
            messageDiv.textContent = 'Could not connect to the server. Please check your internet connection.';
            messageDiv.style.color = 'red';
            
            // --- UNLOCK THE FORM ON FAILURE ---
            isSubmitting = false;
            submitButton.disabled = false;
            submitButton.textContent = 'Register';
        }
    });
});