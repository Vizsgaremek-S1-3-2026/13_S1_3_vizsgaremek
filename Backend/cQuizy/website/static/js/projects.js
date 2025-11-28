// static/js/projects.js

// A helper function to get the JWT token from storage
function getToken() {
    return localStorage.getItem('authToken');
}

// Helper to format a Date object for datetime-local input (YYYY-MM-DDTHH:mm)
function formatLocalTime(date) {
    const pad = (num) => num.toString().padStart(2, '0');
    const year = date.getFullYear();
    const month = pad(date.getMonth() + 1);
    const day = pad(date.getDate());
    const hours = pad(date.getHours());
    const minutes = pad(date.getMinutes());
    return `${year}-${month}-${day}T${hours}:${minutes}`;
}

// Function to set default values for date inputs
function setDatetimeDefaults() {
    const startInput = document.getElementById('projectInsertDateStartInput');
    const endInput = document.getElementById('projectInsertDateEndInput');

    if (startInput && endInput) {
        const now = new Date();
        const oneHourLater = new Date(now.getTime() + 60 * 60 * 1000); // Add 1 hour

        startInput.value = formatLocalTime(now);
        endInput.value = formatLocalTime(oneHourLater);
    }
}

// Main function to fetch and display projects
async function loadProjects() {
    const projectsContainer = document.getElementById('projectsContainer');
    projectsContainer.innerHTML = '<p>Loading projects...</p>';

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

        projectsContainer.innerHTML = '';
        projects.forEach(project => {
            const projectElement = document.createElement('div');
            projectElement.className = 'project-item';
            
            projectElement.innerHTML = `
                <h3>${project.name} <span style="font-size: 0.8em; color: #555;">(ID: ${project.id})</span></h3>
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
    event.preventDefault();

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
        window.location.href = `/builder/?projectId=${newProject.id}`;

    } catch (error) {
        alert(`Error creating project: ${error.message}`);
    }
}

// Function to handle Quiz Creation (Insert Project into Group)
async function handleInsertProject(event) {
    event.preventDefault();

    const projectId = document.getElementById('projectInsertProjectIdInput').value;
    const groupId = document.getElementById('projectInsertGroupIdInput').value;
    const dateStartRaw = document.getElementById('projectInsertDateStartInput').value;
    const dateEndRaw = document.getElementById('projectInsertDateEndInput').value;

    if (!projectId || !groupId || !dateStartRaw || !dateEndRaw) {
        alert("All fields are required to insert a project.");
        return;
    }

    try {
        // Convert the local time strings to ISO format for the API
        const dateStart = new Date(dateStartRaw).toISOString();
        const dateEnd = new Date(dateEndRaw).toISOString();

        const response = await fetch('/api/quizzes/', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${getToken()}`,
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                project_id: parseInt(projectId),
                group_id: parseInt(groupId),
                date_start: dateStart,
                date_end: dateEnd
            }),
        });

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.detail || 'Failed to insert project.');
        }

        const quiz = await response.json();
        alert(`Success! Project "${quiz.project_name}" assigned to group "${quiz.group_name}".`);
        
        // Clear form and reset dates to current time
        document.getElementById('formInsertProject').reset();
        setDatetimeDefaults();

    } catch (error) {
        alert(`Error creating quiz: ${error.message}\n(Check IDs and Admin permissions)`);
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

        if (response.status !== 204) {
            throw new Error('Failed to delete project.');
        }
        loadProjects();

    } catch (error) {
        alert(`Error: ${error.message}`);
    }
}

// Event Listeners
document.addEventListener('DOMContentLoaded', () => {
    // 1. Load projects
    loadProjects();

    // 2. Set default times for the Insert form
    setDatetimeDefaults();

    // 3. Attach listeners
    const createForm = document.getElementById('formCreateProject');
    if (createForm) {
        createForm.addEventListener('submit', handleCreateProject);
    }

    const insertForm = document.getElementById('formInsertProject');
    if (insertForm) {
        insertForm.addEventListener('submit', handleInsertProject);
    }

    const projectsContainer = document.getElementById('projectsContainer');
    if (projectsContainer) {
        projectsContainer.addEventListener('click', (event) => {
            if (event.target.classList.contains('edit-btn')) {
                const projectId = event.target.dataset.projectId;
                window.location.href = `/builder/?projectId=${projectId}`;
            }
            if (event.target.classList.contains('delete-btn')) {
                const projectId = event.target.dataset.projectId;
                handleDeleteProject(projectId);
            }
        });
    }
});