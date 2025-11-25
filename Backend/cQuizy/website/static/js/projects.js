// static/js/projects.js

// A helper function to get the JWT token from where you store it (e.g., localStorage)
function getToken() {
    return localStorage.getItem('authToken');
}

// Main function to fetch and display projects
async function loadProjects() {
    const projectsContainer = document.getElementById('projectsContainer');
    projectsContainer.innerHTML = '<p>Loading projects...</p>'; // Show loading message

    try {
        const response = await fetch('/api/blueprints/', {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${getToken()}`,
                'Content-Type': 'application/json',
            },
        });

        if (!response.ok) {
            throw new Error('Failed to fetch projects.');
        }

        const projects = await response.json();

        if (projects.length === 0) {
            projectsContainer.innerHTML = '<p>No projects found. Create one to get started!</p>';
            return;
        }

        // Clear loading message and render projects
        projectsContainer.innerHTML = '';
        projects.forEach(project => {
            const projectElement = document.createElement('div');
            projectElement.className = 'project-item'; // For styling
            projectElement.innerHTML = `
                <h3>${project.name}</h3>
                <p>${project.desc || 'No description.'}</p>
                <div class="project-actions">
                    <button class="edit-btn" data-project-id="${project.id}">Edit</button>
                    <button class="delete-btn" data-project-id="${project.id}">Delete</button>
                </div>
            `;
            projectsContainer.appendChild(projectElement);
        });

    } catch (error) {
        projectsContainer.innerHTML = `<p style="color: red;">Error: ${error.message}</p>`;
    }
}

// Function to handle project creation
async function handleCreateProject(event) {
    event.preventDefault(); // Stop the form from submitting the traditional way

    const name = document.getElementById('projectNameInput').value;
    const desc = document.getElementById('projectDescriptionInput').value;

    try {
        const response = await fetch('/api/blueprints/', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${getToken()}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ name, desc }),
        });

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.detail || 'Failed to create project.');
        }

        const newProject = await response.json();
        
        // CORRECTED URL: Redirect to the Django URL, not the HTML file.
        window.location.href = `/builder/?projectId=${newProject.id}`;

    } catch (error) {
        alert(`Error creating project: ${error.message}`);
    }
}

// Function to handle project deletion
async function handleDeleteProject(projectId) {
    if (!confirm('Are you sure you want to delete this project?')) {
        return;
    }

    try {
        const response = await fetch(`/api/blueprints/${projectId}/`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${getToken()}`,
            },
        });

        if (response.status !== 204) { // 204 No Content is the success status
            throw new Error('Failed to delete project.');
        }

        // Reload the project list to reflect the deletion
        loadProjects();

    } catch (error) {
        alert(`Error: ${error.message}`);
    }
}


// Event Listeners
document.addEventListener('DOMContentLoaded', () => {
    // Load projects when the page is ready
    loadProjects();

    // Attach event listener to the create form
    const createForm = document.getElementById('formCreateProject');
    createForm.addEventListener('submit', handleCreateProject);

    // Use event delegation for edit and delete buttons for better performance
    const projectsContainer = document.getElementById('projectsContainer');
    projectsContainer.addEventListener('click', (event) => {
        if (event.target.classList.contains('edit-btn')) {
            const projectId = event.target.dataset.projectId;
            // CORRECTED URL: Redirect to the Django URL, not the HTML file.
            window.location.href = `/builder/?projectId=${projectId}`;
        }
        if (event.target.classList.contains('delete-btn')) {
            const projectId = event.target.dataset.projectId;
            handleDeleteProject(projectId);
        }
    });
});