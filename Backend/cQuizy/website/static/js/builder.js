// static/js/builder.js

function getToken() {
    return localStorage.getItem('authToken');
}

let projectState = {};
let projectId = null;

function updateButtonStates() {
    const addQuestionBtn = document.getElementById('add-block-btn');
    if (addQuestionBtn) {
        const questionCount = document.querySelectorAll('.block-item').length;
        addQuestionBtn.disabled = questionCount >= 100;
        addQuestionBtn.title = addQuestionBtn.disabled ? 'A project cannot have more than 100 questions.' : 'Add New Question';
    }
    const allBlocks = document.querySelectorAll('.block-item');
    allBlocks.forEach(block => {
        const addAnswerBtn = block.querySelector('.add-answer-btn');
        if (addAnswerBtn) {
            const answerCount = block.querySelectorAll('.answer-item').length;
            addAnswerBtn.disabled = answerCount >= 10;
            addAnswerBtn.title = addAnswerBtn.disabled ? 'A question cannot have more than 10 answers.' : 'Add New Answer';
        }
    });
}

// --- DYNAMIC HTML GENERATION FUNCTIONS ---

function createAnswerElement(answer = {}, blockType = 'SINGLE') {
    const answerId = answer.id || null;
    const answerText = answer.text || '';
    const isCorrect = answer.is_correct || false;

    const div = document.createElement('div');
    div.className = 'answer-item';
    if (blockType === 'TEXT') {
        div.classList.add('correct-hidden');
    }

    div.setAttribute('data-answer-id', answerId);
    div.innerHTML = `
        <input type="text" class="answer-text" value="${answerText}" placeholder="Answer Option">
        <label>
            <input type="checkbox" class="answer-correct" ${isCorrect ? 'checked' : ''}> Correct
        </label>
        <button class="delete-answer-btn">Delete Answer</button>
    `;
    return div;
}

function createBlockElement(block = {}) {
    const blockId = block.id || null;
    const questionText = block.question || '';
    const subtext = block.subtext || '';
    const imageUrl = block.image_url || '';
    const linkUrl = block.link_url || '';
    const blockType = block.type || 'SINGLE';
    const div = document.createElement('div');
    div.className = 'block-item';
    div.setAttribute('data-block-id', blockId);
    div.innerHTML = `
        <div class="block-header">
            <div class="drag-handle">☰</div>
            <h4>Question</h4>
            <select class="block-type">
                <option value="SINGLE" ${blockType === 'SINGLE' ? 'selected' : ''}>Single Choice</option>
                <option value="MULTIPLE" ${blockType === 'MULTIPLE' ? 'selected' : ''}>Multiple Choice</option>
                <option value="TEXT" ${blockType === 'TEXT' ? 'selected' : ''}>Text Input</option>
            </select>
            <button class="delete-block-btn">Delete Question</button>
        </div>
        <textarea class="block-question" rows="3" placeholder="Enter the question here...">${questionText}</textarea>
        <textarea class="block-subtext" rows="2" placeholder="Optional subtext or instructions...">${subtext}</textarea>
        <div class="block-optional-fields">
            <input type="url" class="block-image-url" value="${imageUrl}" placeholder="Optional Image URL">
            <input type="url" class="block-link-url" value="${linkUrl}" placeholder="Optional Link URL">
        </div>
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
    // Remove previous content
    const existingContainer = document.querySelector('.builder-container');
    if (existingContainer) existingContainer.remove();

    // Create the main container
    const builderContainer = document.createElement('div');
    builderContainer.className = 'builder-container';

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
            <button id="open-import-modal-btn" style="background-color: #17a2b8; color: white;">Insert Existing</button>
            <button id="save-project-btn" class="primary-btn">Save Project</button>
        </div>
    `;
    const blocksContainer = form.querySelector('#blocks-container');
    if (projectData.blocks && projectData.blocks.length > 0) {
        projectData.blocks.sort((a, b) => a.order - b.order).forEach(block => {
            blocksContainer.appendChild(createBlockElement(block));
        });
    }

    // Append form to container, then container to body
    builderContainer.appendChild(form);
    container.appendChild(builderContainer);

    new Sortable(blocksContainer, {
        animation: 150,
        handle: '.drag-handle',
    });
    updateButtonStates();
    attachModalEvents();
}

function generateJsonPayload() {
    const payload = {
        name: document.getElementById('project-name-input').value,
        desc: document.getElementById('project-desc-input').value.trim() || null,
        blocks: []
    };
    const blockElements = document.querySelectorAll('.block-item');
    blockElements.forEach(blockEl => {
        const blockId = blockEl.dataset.blockId;
        const blockType = blockEl.querySelector('.block-type').value;
        const blockData = {
            id: blockId !== 'null' ? parseInt(blockId) : null,
            question: blockEl.querySelector('.block-question').value,
            type: blockType,
            subtext: blockEl.querySelector('.block-subtext').value.trim() || null,
            image_url: blockEl.querySelector('.block-image-url').value.trim() || null,
            link_url: blockEl.querySelector('.block-link-url').value.trim() || null,
            answers: []
        };
        const answerElements = blockEl.querySelectorAll('.answer-item');
        answerElements.forEach(answerEl => {
            const answerId = answerEl.dataset.answerId;
            const answerData = {
                id: answerId !== 'null' ? parseInt(answerId) : null,
                text: answerEl.querySelector('.answer-text').value,
                is_correct: (blockType === 'TEXT') ? true : answerEl.querySelector('.answer-correct').checked
            };
            blockData.answers.push(answerData);
        });
        payload.blocks.push(blockData);
    });
    return payload;
}

function validateForm() {
    const projectName = document.getElementById('project-name-input').value;
    if (!projectName.trim()) {
        alert("Project name cannot be empty.");
        return false;
    }
    const blockElements = document.querySelectorAll('.block-item');
    for (let i = 0; i < blockElements.length; i++) {
        const blockEl = blockElements[i];
        const questionNum = i + 1;
        const questionText = blockEl.querySelector('.block-question').value;
        if (!questionText.trim()) {
            alert(`Error: Question #${questionNum} cannot be empty.`);
            return false;
        }
        const blockType = blockEl.querySelector('.block-type').value;
        const answerElements = blockEl.querySelectorAll('.answer-item');

        if ((blockType === 'SINGLE' || blockType === 'MULTIPLE') && answerElements.length < 2) {
            alert(`Error at Question #${questionNum}: Multiple choice questions must have at least two answers.`);
            return false;
        }

        for (let j = 0; j < answerElements.length; j++) {
            const answerEl = answerElements[j];
            const answerNum = j + 1;
            const answerText = answerEl.querySelector('.answer-text').value;
            if (!answerText.trim()) {
                alert(`Error at Question #${questionNum}: Answer #${answerNum} cannot be empty.`);
                return false;
            }
        }
    }
    return true; // All checks passed
}

// --- DATA HANDLING FUNCTIONS ---

async function loadProjectData() {
    const urlParams = new URLSearchParams(window.location.search);
    projectId = urlParams.get('projectId');
    if (!projectId) {
        document.body.innerHTML = '<h1>No project ID specified. <a href="/projects/">Back to projects</a></h1>';
        return;
    }
    try {
        const response = await fetch(`/api/blueprints/${projectId}/`, { headers: { 'Authorization': `Bearer ${getToken()}` } });
        if (response.status === 401) {
            alert("Session expired. Please log in again.");
            window.location.href = '/login/';
            return;
        }
        if (!response.ok) throw new Error('Failed to load project data.');
        projectState = await response.json();
        renderProjectForm(projectState);
    } catch (error) {
        document.body.innerHTML = `<h1>Error: ${error.message}</h1>`;
    }
}

async function saveProject() {
    if (!validateForm()) {
        return;
    }
    const payload = generateJsonPayload();
    if (!payload) return;
    try {
        const response = await fetch(`/api/blueprints/${projectId}/`, {
            method: 'PUT',
            headers: { 'Authorization': `Bearer ${getToken()}`, 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        if (response.status === 401) {
            alert("Session expired. Please log in again.");
            window.location.href = '/login/';
            return;
        }
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.detail || 'Failed to save project.');
        }
        alert('Project saved successfully!');
        loadProjectData();
    } catch (error) {
        alert(`Save Error: ${error.message}`);
    }
}

// --- NEW: IMPORT BLOCK LOGIC ---

function attachModalEvents() {
    const modal = document.getElementById("blockSearchModal");
    const btn = document.getElementById("open-import-modal-btn");
    const span = document.querySelector(".close-modal");
    const searchBtn = document.getElementById("blockSearchBtn");
    const searchInput = document.getElementById("blockSearchInput");
    const resultsContainer = document.getElementById('searchResultsContainer');

    if (btn) {
        btn.onclick = function () {
            modal.style.display = "block";
            // Do not search automatically. Reset container message.
            resultsContainer.innerHTML = '<p style="text-align:center; color:#666;">Type a keyword and click search.</p>';
        }
    }

    if (span) {
        span.onclick = function () {
            modal.style.display = "none";
        }
    }

    window.onclick = function (event) {
        if (event.target == modal) {
            modal.style.display = "none";
        }
    }

    if (searchBtn) {
        searchBtn.onclick = () => searchUserBlocks(searchInput.value);
    }

    // Allow pressing Enter in the input field
    if (searchInput) {
        searchInput.addEventListener("keypress", function (event) {
            if (event.key === "Enter") {
                event.preventDefault();
                searchUserBlocks(searchInput.value);
            }
        });
    }
}

async function searchUserBlocks(query) {
    const container = document.getElementById('searchResultsContainer');
    const modeSelect = document.getElementById('searchModeSelect');
    const mode = modeSelect ? modeSelect.value : 'both';

    container.innerHTML = '<p style="text-align:center; color:#666;">Loading...</p>';

    try {
        // Build URL with params
        let url = `/api/blueprints/my-blocks/?mode=${mode}`;

        if (query && query.trim() !== '') {
            url += `&query=${encodeURIComponent(query)}`;
        }

        const response = await fetch(url, {
            headers: { 'Authorization': `Bearer ${getToken()}` }
        });

        if (!response.ok) throw new Error("Search failed.");

        const blocks = await response.json();

        container.innerHTML = '';

        if (blocks.length === 0) {
            if (query && query.trim() !== '') {
                container.innerHTML = '<p style="text-align:center; color:#666;">No results for this query.</p>';
            } else {
                container.innerHTML = '<p style="text-align:center; color:#666;">No questions found.</p>';
            }
            return;
        }

        blocks.forEach(block => {
            const div = document.createElement('div');
            div.className = 'search-result-item';

            // Build answer list preview
            let answersHtml = '<ul class="result-answers-list">';
            if (block.answers && block.answers.length > 0) {
                block.answers.forEach(ans => {
                    const isCorrectClass = ans.is_correct ? 'correct-answer' : '';
                    answersHtml += `<li class="${isCorrectClass}">${ans.text}</li>`;
                });
            } else {
                answersHtml += '<li><i>No answers</i></li>';
            }
            answersHtml += '</ul>';

            div.innerHTML = `
                <div class="search-result-info">
                    <div class="result-header">
                        <h5>${block.question}</h5>
                        <span class="badge type-${block.type.toLowerCase()}" style="font-size: 10px; padding: 2px 6px; border-radius: 4px; background: #444; color: white;">${block.type}</span>
                    </div>
                    <div class="result-preview" style="background-color: rgba(0,0,0,0.05); border-radius: 8px; padding: 8px;">
                        ${answersHtml}
                    </div>
                </div>
                <button class="insert-btn">Insert</button>
            `;

            div.querySelector('.insert-btn').addEventListener('click', () => {
                insertBlockAsCopy(block);
                document.getElementById("blockSearchModal").style.display = "none";
            });

            container.appendChild(div);
        });

    } catch (error) {
        console.error(error);
        container.innerHTML = `<p style="color:red; text-align:center;">Error: ${error.message}</p>`;
    }
}

function insertBlockAsCopy(originalBlock) {
    // 1. Deep copy
    const blockData = JSON.parse(JSON.stringify(originalBlock));

    // 2. Delete IDs -> Will be treated as new upon save
    blockData.id = null;
    blockData.answers.forEach(ans => {
        ans.id = null;
    });

    // 3. Render
    const newBlockElement = createBlockElement(blockData);

    // 4. Append and scroll
    const blocksContainer = document.getElementById('blocks-container');
    blocksContainer.appendChild(newBlockElement);

    updateButtonStates();

    newBlockElement.scrollIntoView({ behavior: 'smooth' });
    newBlockElement.style.border = "2px solid #28a745";
    setTimeout(() => newBlockElement.style.border = "", 2000);
}

// --- EVENT HANDLERS ---

document.addEventListener('DOMContentLoaded', () => {
    if (!getToken()) {
        alert("You must be logged in to access the editor.");
        window.location.href = '/login/';
        return;
    }
    loadProjectData();

    document.body.addEventListener('click', (event) => {
        if (event.target.id === 'save-project-btn') saveProject();
        if (event.target.id === 'add-block-btn') {
            document.getElementById('blocks-container').appendChild(createBlockElement());
            updateButtonStates();
        }
        if (event.target.classList.contains('add-answer-btn')) {
            const blockItem = event.target.closest('.block-item');
            const blockType = blockItem.querySelector('.block-type').value;
            blockItem.querySelector('.answers-container').appendChild(createAnswerElement({}, blockType));
            updateButtonStates();
        }
        if (event.target.classList.contains('delete-block-btn')) {
            if (confirm('Are you sure you want to delete this question and all its answers?')) {
                event.target.closest('.block-item').remove();
                updateButtonStates();
            }
        }
        if (event.target.classList.contains('delete-answer-btn')) {
            event.target.closest('.answer-item').remove();
            updateButtonStates();
        }
        if (event.target.classList.contains('answer-correct')) {
            const blockItem = event.target.closest('.block-item');
            if (blockItem.querySelector('.block-type').value === 'SINGLE') {
                if (event.target.checked) {
                    const allCheckboxes = blockItem.querySelectorAll('.answer-correct');
                    allCheckboxes.forEach(checkbox => {
                        if (checkbox !== event.target) checkbox.checked = false;
                    });
                }
            }
        }
    });

    document.body.addEventListener('change', (event) => {
        if (event.target.classList.contains('block-type')) {
            const blockItem = event.target.closest('.block-item');
            const newType = event.target.value;
            const answerItems = blockItem.querySelectorAll('.answer-item');
            answerItems.forEach(item => {
                item.classList.toggle('correct-hidden', newType === 'TEXT');
            });
            if (newType === 'SINGLE') {
                const checkedBoxes = blockItem.querySelectorAll('.answer-correct:checked');
                for (let i = 1; i < checkedBoxes.length; i++) {
                    checkedBoxes[i].checked = false;
                }
            }
        }
    });
});