// static/js/register.js

document.addEventListener('DOMContentLoaded', () => {
    const registerForm = document.getElementById('registerForm');
    const messageDiv = document.getElementById('message');
    const submitButton = registerForm.querySelector('button[type="submit"]');

    // --- THIS IS THE BULLETPROOF LOCK ---
    let isSubmitting = false;

    registerForm.addEventListener('submit', async (event) => {
        event.preventDefault();

        // If the form is already submitting, do absolutely nothing.
        if (isSubmitting) {
            return;
        }

        // --- ENGAGE THE LOCK ---
        isSubmitting = true;
        submitButton.disabled = true;
        submitButton.textContent = 'Registering...';
        messageDiv.textContent = '';

        // ... (Gather all your data from the form fields) ...
        const lastName = document.getElementById('register-lastname').value;
        const firstName = document.getElementById('register-firstname').value;
        const username = document.getElementById('register-username').value;
        const nickname = document.getElementById('register-nickname').value;
        const email = document.getElementById('register-email').value;
        const password = document.getElementById('register-password').value;
        const pfpUrl = document.getElementById('register-pfp-url').value;

        const payload = {
            last_name: lastName,
            first_name: firstName,
            username: username,
            nickname: nickname,
            email: email,
            password: password,
        };
        
        if (pfpUrl.trim() !== '') {
            payload.pfp_url = pfpUrl;
        }
        
        try {
            const response = await fetch('/api/users/register', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            if (response.ok) {
                messageDiv.textContent = 'Registration successful! Redirecting...';
                messageDiv.style.color = 'green';
                setTimeout(() => { window.location.href = '/login'; }, 2000);
                // We don't unlock here because the page is changing
            } else {
                const data = await response.json();
                messageDiv.textContent = data.error || 'An unknown error occurred.';
                messageDiv.style.color = 'red';
                // --- UNLOCK ON FAILURE ---
                isSubmitting = false; 
                submitButton.disabled = false;
                submitButton.textContent = 'Register';
            }

        } catch (error) {
            console.error('Registration failed:', error);
            messageDiv.textContent = 'Could not connect to the server.';
            messageDiv.style.color = 'red';
            // --- UNLOCK ON FAILURE ---
            isSubmitting = false;
            submitButton.disabled = false;
            submitButton.textContent = 'Register';
        }
    });
});