// static/js/builder.js

// A helper function to get the JWT token
function getToken() {
    return localStorage.getItem('authToken');
}

// This will hold the entire state of our project
let projectState = {};
let projectId = null;

// --- DYNAMIC HTML GENERATION FUNCTIONS ---

function createAnswerElement(answer = {}, blockType = 'SINGLE') {
    const answerId = answer.id || null;
    const answerText = answer.text || '';
    const isCorrect = answer.is_correct || false;

    // Use checkbox for SINGLE/MULTIPLE, but it's less relevant for TEXT
    const inputType = (blockType === 'SINGLE' || blockType === 'MULTIPLE') ? 'checkbox' : 'checkbox';

    const div = document.createElement('div');
    div.className = 'answer-item';
    div.setAttribute('data-answer-id', answerId);
    div.innerHTML = `
        <input type="text" class="answer-text" value="${answerText}" placeholder="Answer option">
        <label>
            <input type="${inputType}" class="answer-correct" ${isCorrect ? 'checked' : ''}> Correct
        </label>
        <button class="delete-answer-btn">Remove Answer</button>
    `;
    return div;
}

function createBlockElement(block = {}) {
    const blockId = block.id || null;
    const questionText = block.question || '';
    const blockType = block.type || 'SINGLE'; // Default to single choice for new blocks

    const div = document.createElement('div');
    div.className = 'block-item';
    div.setAttribute('data-block-id', blockId);
    // Add the type as a class for easier targeting
    div.classList.add(`type-${blockType}`);

    div.innerHTML = `
        <div class="block-header">
            <div class="drag-handle">☰</div> <!-- Drag handle for reordering -->
            <h4>Question</h4>
            <select class="block-type">
                <option value="SINGLE" ${blockType === 'SINGLE' ? 'selected' : ''}>Single Choice</option>
                <option value="MULTIPLE" ${blockType === 'MULTIPLE' ? 'selected' : ''}>Multiple Choice</option>
                <option value="TEXT" ${blockType === 'TEXT' ? 'selected' : ''}>Text Input</option>
            </select>
            <button class="delete-block-btn">Delete Question</button>
        </div>
        <textarea class="block-question" rows="3" placeholder="Enter your question here...">${questionText}</textarea>
        <div class="answers-container">
            <h5>Answers</h5>
        </div>
        <button class="add-answer-btn">Add Answer</button>
    `;

    const answersContainer = div.querySelector('.answers-container');
    if (block.answers && block.answers.length > 0) {
        block.answers.forEach(answer => {
            answersContainer.appendChild(createAnswerElement(answer, blockType));
        });
    }

    return div;
}

function renderProjectForm(projectData) {
    const container = document.body;
    const existingForm = document.getElementById('builder-form');
    if (existingForm) existingForm.remove();

    const form = document.createElement('div');
    form.id = 'builder-form';
    form.innerHTML = `
        <h2>Project Editor</h2>
        <div class="project-meta">
            <label>Project Name</label>
            <input type="text" id="project-name-input" value="${projectData.name}">
            <label>Project Description</label>
            <textarea id="project-desc-input" rows="4">${projectData.desc || ''}</textarea>
        </div>
        <div id="blocks-container">
            <h3>Questions</h3>
        </div>
        <div class="builder-actions">
            <button id="add-block-btn">Add Question</button>
            <button id="save-project-btn" class="primary-btn">Save Project</button>
        </div>
    `;

    const blocksContainer = form.querySelector('#blocks-container');
    if (projectData.blocks && projectData.blocks.length > 0) {
        projectData.blocks.sort((a, b) => a.order - b.order).forEach(block => {
            blocksContainer.appendChild(createBlockElement(block));
        });
    }

    container.appendChild(form);

    // INITIALIZE DRAG-AND-DROP
    new Sortable(blocksContainer, {
        animation: 150,
        handle: '.drag-handle', // Restrict dragging to the handle
    });
}


// --- DATA HANDLING FUNCTIONS ---

async function loadProjectData() {
    const urlParams = new URLSearchParams(window.location.search);
    projectId = urlParams.get('projectId');

    if (!projectId) {
        document.body.innerHTML = '<h1>No Project ID specified. <a href="/projects.html">Go back</a></h1>';
        return;
    }

    try {
        const response = await fetch(`/api/blueprints/${projectId}/`, {
            headers: { 'Authorization': `Bearer ${getToken()}` }
        });

        if (response.status === 401) {
            alert("Your session has expired. Please log in again.");
            window.location.href = '/login/';
            return;
        }
        if (!response.ok) throw new Error('Could not load project data.');

        projectState = await response.json();
        renderProjectForm(projectState);

    } catch (error) {
        document.body.innerHTML = `<h1>Error: ${error.message}</h1>`;
    }
}

async function saveProject() {
    const payload = {
        name: document.getElementById('project-name-input').value,
        desc: document.getElementById('project-desc-input').value,
        blocks: []
    };

    // The order is now determined by the element's position in the DOM
    const blockElements = document.querySelectorAll('.block-item');
    blockElements.forEach(blockEl => {
        const blockId = blockEl.dataset.blockId;
        const blockData = {
            id: blockId !== 'null' ? parseInt(blockId) : null,
            question: blockEl.querySelector('.block-question').value,
            type: blockEl.querySelector('.block-type').value, // Get type from dropdown
            answers: []
        };

        const answerElements = blockEl.querySelectorAll('.answer-item');
        answerElements.forEach(answerEl => {
            const answerId = answerEl.dataset.answerId;
            const answerData = {
                id: answerId !== 'null' ? parseInt(answerId) : null,
                text: answerEl.querySelector('.answer-text').value,
                is_correct: answerEl.querySelector('.answer-correct').checked
            };
            blockData.answers.push(answerData);
        });

        payload.blocks.push(blockData);
    });

    try {
        const response = await fetch(`/api/blueprints/${projectId}/`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${getToken()}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        if (response.status === 401) {
            alert("Your session has expired. Please log in again.");
            window.location.href = '/login/';
            return;
        }
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.detail || 'Failed to save project.');
        }

        alert('Project saved successfully!');
        // Reloading is important to get new IDs and confirm the new order
        loadProjectData();

    } catch (error) {
        alert(`Save Error: ${error.message}`);
    }
}


// --- EVENT LISTENERS ---
document.addEventListener('DOMContentLoaded', () => {
    if (!getToken()) {
        alert("You must be logged in to access the builder.");
        window.location.href = '/login/';
        return;
    }

    loadProjectData();

    document.body.addEventListener('click', (event) => {
        if (event.target.id === 'save-project-btn') saveProject();
        if (event.target.id === 'add-block-btn') document.getElementById('blocks-container').appendChild(createBlockElement());
        if (event.target.classList.contains('add-answer-btn')) {
            const blockItem = event.target.closest('.block-item');
            const blockType = blockItem.querySelector('.block-type').value;
            blockItem.querySelector('.answers-container').appendChild(createAnswerElement({}, blockType));
        }
        if (event.target.classList.contains('delete-block-btn')) {
            if (confirm('Delete this question and all its answers?')) event.target.closest('.block-item').remove();
        }
        if (event.target.classList.contains('delete-answer-btn')) event.target.closest('.answer-item').remove();
        
        // Smart Checkbox Logic for Single Choice questions
        if (event.target.classList.contains('answer-correct')) {
            const blockItem = event.target.closest('.block-item');
            if (blockItem.querySelector('.block-type').value === 'SINGLE') {
                // If this box was just checked, uncheck all others
                if (event.target.checked) {
                    const allCheckboxes = blockItem.querySelectorAll('.answer-correct');
                    allCheckboxes.forEach(checkbox => {
                        if (checkbox !== event.target) {
                            checkbox.checked = false;
                        }
                    });
                }
            }
        }
    });

    // Listener for when the type changes
    document.body.addEventListener('change', event => {
        if (event.target.classList.contains('block-type')) {
            const blockItem = event.target.closest('.block-item');
            const newType = event.target.value;
            // Remove old type class, add new one
            blockItem.className = 'block-item'; // Reset classes
            blockItem.classList.add(`type-${newType}`);
        }
    });
});