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

    // Check answer limits per block
    const allBlocks = document.querySelectorAll('.block-item');
    allBlocks.forEach(block => {
        const addAnswerBtn = block.querySelector('.add-answer-btn');
        if (addAnswerBtn) {
            const answerCount = block.querySelectorAll('.answer-item').length;
            // Static blocks don't use answers, so we can hide the button logic elsewhere
            addAnswerBtn.disabled = answerCount >= 20;
        }
    });
}

// --- DYNAMIC HTML GENERATION FUNCTIONS ---

function createAnswerElement(answer = {}, blockType = 'single') {
    const answerId = answer.id || null;
    const isCorrect = answer.is_correct || false;
    const points = answer.points || 1;

    const div = document.createElement('div');
    div.className = 'answer-item';
    div.setAttribute('data-answer-id', answerId);

    // Build the specific inputs based on block type
    let inputsHtml = '';

    if (blockType === 'matching') {
        // MATCHING: Left Side (Text) + Right Side (Match Text)
        inputsHtml = `
            <input type="text" class="answer-text" value="${answer.text || ''}" placeholder="Left Side (e.g., Poet)" style="flex:1">
            <span style="font-weight:bold;">⮕</span>
            <input type="text" class="answer-match" value="${answer.match_text || ''}" placeholder="Right Side (e.g., Poem)" style="flex:1">
        `;
    } else if (blockType === 'gap_fill') {
        // GAP FILL: Answer Text + Gap Index
        inputsHtml = `
            <input type="text" class="answer-text" value="${answer.text || ''}" placeholder="Word to fill" style="flex:2">
            <input type="number" class="answer-gap-index" value="${answer.gap_index || ''}" placeholder="{Index}" min="1" style="width: 80px;">
        `;
    } else if (blockType === 'range') {
        // RANGE: Numeric Value + Tolerance
        inputsHtml = `
            <input type="number" step="any" class="answer-numeric" value="${answer.numeric_value !== null && answer.numeric_value !== undefined ? answer.numeric_value : ''}" placeholder="Correct Value" style="flex:1">
            <span style="font-weight:bold;">±</span>
            <input type="number" step="any" class="answer-tolerance" value="${answer.tolerance !== null && answer.tolerance !== undefined ? answer.tolerance : ''}" placeholder="Tolerance" style="flex:1">
        `;
    } else {
        // STANDARD (Single, Multiple, Text, Ordering, Sentence)
        inputsHtml = `
            <input type="text" class="answer-text" value="${answer.text || ''}" placeholder="Answer Option" style="flex:1">
        `;
    }

    // Checkbox logic
    let checkboxHtml = '';
    // "Text Answer" and logic types usually imply correctness differently, 
    // but Single/Multiple definitely need the checkbox.
    if (['single', 'multiple', 'text'].includes(blockType)) {
        checkboxHtml = `
            <label style="white-space:nowrap; margin-left:5px;">
                <input type="checkbox" class="answer-correct" ${isCorrect ? 'checked' : ''}> Correct
            </label>
         `;
    }

    // Points logic
    const pointsHtml = `
        <input type="number" class="answer-points" value="${points}" style="width: 50px; text-align:center;" title="Points">
    `;

    div.innerHTML = `
        <div class="answer-inputs-group">
            ${inputsHtml}
        </div>
        ${checkboxHtml}
        ${pointsHtml}
        <button class="delete-answer-btn" style="background:#ff4444; color:white; border:none; padding:5px 10px; cursor:pointer;">X</button>
    `;

    return div;
}

function createBlockElement(block = {}) {
    const blockId = block.id || null;

    // In API it is 'maintext', but for legacy compatibility we check 'question' too
    const mainText = block.maintext || block.question || '';

    const gapText = block.gap_text || '';
    const subtext = block.subtext || '';
    const imageUrl = block.image_url || '';
    const linkUrl = block.link_url || '';

    // Default to 'single' if undefined
    const blockType = block.type || 'single';

    const div = document.createElement('div');
    div.className = 'block-item';
    div.setAttribute('data-block-id', blockId);

    // Render HTML
    div.innerHTML = `
        <div class="block-header">
            <div class="drag-handle">☰</div>
            <select class="block-type" style="width: auto; font-weight:bold;">
                <optgroup label="Standard Questions">
                    <option value="single" ${blockType === 'single' ? 'selected' : ''}>Single Choice</option>
                    <option value="multiple" ${blockType === 'multiple' ? 'selected' : ''}>Multiple Choice</option>
                    <option value="text" ${blockType === 'text' ? 'selected' : ''}>Text Answer</option>
                </optgroup>
                <optgroup label="Logic Puzzles">
                    <option value="matching" ${blockType === 'matching' ? 'selected' : ''}>Matching Pairs</option>
                    <option value="ordering" ${blockType === 'ordering' ? 'selected' : ''}>Ordering</option>
                    <option value="sentence_ordering" ${blockType === 'sentence_ordering' ? 'selected' : ''}>Sentence Ordering</option>
                    <option value="gap_fill" ${blockType === 'gap_fill' ? 'selected' : ''}>Gap Fill</option>
                    <option value="range" ${blockType === 'range' ? 'selected' : ''}>Range / Estimation</option>
                </optgroup>
                <optgroup label="Static Content">
                    <option value="text_block" ${blockType === 'text_block' ? 'selected' : ''}>Text Block (No Answer)</option>
                    <option value="divider" ${blockType === 'divider' ? 'selected' : ''}>Divider</option>
                </optgroup>
            </select>
            <div style="flex-grow:1; text-align:right;">
                <button class="delete-block-btn" style="background:darkred; color:white; border:none; padding:5px;">Delete</button>
            </div>
        </div>

        <!-- Main Inputs -->
        
        <!-- Standard 'Question' input (hidden for Gap Fill) -->
        <div class="field-maintext ${blockType === 'gap_fill' ? 'hidden' : ''}">
             <textarea class="block-maintext" rows="2" placeholder="Enter Question, Title, or Text Content...">${mainText}</textarea>
        </div>

        <!-- Special 'Gap Text' input (only for Gap Fill) -->
        <div class="field-gap-text ${blockType !== 'gap_fill' ? 'hidden' : ''}">
             <textarea class="block-gap-text" rows="3" placeholder="Enter text with placeholders like {1}, {2}... Example: The capital of France is {1}.">${gapText}</textarea>
             <small style="color:#666; display:block; margin-bottom:5px;">Use {1}, {2} etc. to mark gaps.</small>
        </div>

        <textarea class="block-subtext" rows="1" placeholder="Optional instructions (Subtext)...">${subtext}</textarea>
        
        <div class="block-optional-fields" style="display:flex; gap:10px;">
            <input type="url" class="block-image-url" value="${imageUrl}" placeholder="Image URL (optional)">
            <input type="url" class="block-link-url" value="${linkUrl}" placeholder="Link URL (optional)">
        </div>

        <!-- Answers Section (Hidden for Static blocks) -->
        <div class="answers-wrapper ${['text_block', 'divider'].includes(blockType) ? 'hidden' : ''}">
            <div class="answers-container">
                <h5 style="margin: 10px 0 5px;">Answers</h5>
                <!-- Answers injected here -->
            </div>
            <button class="add-answer-btn" style="width:100%; padding:5px; background:#e9e9e9; border:1px dashed #999;">+ Add Option</button>
        </div>
    `;

    // Inject Existing Answers
    const answersContainer = div.querySelector('.answers-container');
    if (block.answers && block.answers.length > 0) {
        block.answers.sort((a, b) => a.order - b.order).forEach(answer => {
            answersContainer.appendChild(createAnswerElement(answer, blockType));
        });
    }

    return div;
}

function renderProjectForm(projectData) {
    const container = document.body;
    const existingContainer = document.querySelector('.builder-container');
    if (existingContainer) existingContainer.remove();

    const builderContainer = document.createElement('div');
    builderContainer.className = 'builder-container';
    builderContainer.style.maxWidth = '900px';
    builderContainer.style.margin = '0 auto';

    const form = document.createElement('div');
    form.id = 'builder-form';
    form.innerHTML = `
        <div style="background:white; padding:20px; border-radius:8px; box-shadow:0 2px 5px rgba(0,0,0,0.1); margin-bottom:20px;">
            <h2>Project Editor</h2>
            <div class="project-meta">
                <label>Project Name</label>
                <input type="text" id="project-name-input" value="${projectData.name}" style="font-size:1.2em; font-weight:bold;">
                <label>Project Description</label>
                <textarea id="project-desc-input" rows="3">${projectData.desc || ''}</textarea>
            </div>
        </div>

        <div id="blocks-container"></div>
        
        <div class="builder-actions" style="margin-top:20px; text-align:center; padding-bottom:50px;">
            <button id="add-block-btn" style="padding:10px 20px; font-size:16px;">+ Add Question</button>
            <button id="open-import-modal-btn" style="padding:10px 20px; font-size:16px; background-color: #17a2b8; color: white;">Import Existing</button>
            <button id="save-project-btn" class="primary-btn" style="padding:10px 20px; font-size:16px; background-color: #28a745; color: white;">Save Project</button>
        </div>
    `;

    const blocksContainer = form.querySelector('#blocks-container');
    if (projectData.blocks && projectData.blocks.length > 0) {
        projectData.blocks.sort((a, b) => a.order - b.order).forEach(block => {
            blocksContainer.appendChild(createBlockElement(block));
        });
    }

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

        // Base Block Data
        const blockData = {
            id: blockId !== 'null' ? parseInt(blockId) : null,
            type: blockType,
            subtext: blockEl.querySelector('.block-subtext').value.trim() || null,
            image_url: blockEl.querySelector('.block-image-url').value.trim() || null,
            link_url: blockEl.querySelector('.block-link-url').value.trim() || null,
            answers: []
        };

        // Handle Main Text vs Gap Text
        if (blockType === 'gap_fill') {
            blockData.gap_text = blockEl.querySelector('.block-gap-text').value;
            blockData.maintext = null; // Clear maintext if it's gap fill
        } else {
            blockData.maintext = blockEl.querySelector('.block-maintext').value;
            blockData.gap_text = null;
        }

        // Process Answers (Skip for static blocks)
        if (!['text_block', 'divider'].includes(blockType)) {
            const answerElements = blockEl.querySelectorAll('.answer-item');
            answerElements.forEach(answerEl => {
                const answerId = answerEl.dataset.answerId;
                const pointsInput = answerEl.querySelector('.answer-points');

                const answerData = {
                    id: answerId !== 'null' ? parseInt(answerId) : null,
                    points: pointsInput ? parseInt(pointsInput.value) || 0 : 1,
                    is_correct: false, // Default
                    text: null,
                    match_text: null,
                    gap_index: null,
                    numeric_value: null,
                    tolerance: null
                };

                // --- Extract values based on type ---

                // 1. Text / Left Side
                const textInput = answerEl.querySelector('.answer-text');
                if (textInput) answerData.text = textInput.value;

                // 2. Correct Checkbox
                const correctInput = answerEl.querySelector('.answer-correct');
                if (correctInput) answerData.is_correct = correctInput.checked;

                // 3. Match Text (Right Side)
                const matchInput = answerEl.querySelector('.answer-match');
                if (matchInput) answerData.match_text = matchInput.value;

                // 4. Gap Index
                const gapInput = answerEl.querySelector('.answer-gap-index');
                if (gapInput) answerData.gap_index = parseInt(gapInput.value) || null;

                // 5. Numeric & Tolerance
                const numInput = answerEl.querySelector('.answer-numeric');
                const tolInput = answerEl.querySelector('.answer-tolerance');
                if (numInput) answerData.numeric_value = parseFloat(numInput.value);
                if (tolInput) answerData.tolerance = parseFloat(tolInput.value);

                // For TEXT block type, we force correct=True usually, or handle via backend logic
                if (blockType === 'text') {
                    answerData.is_correct = true;
                }

                blockData.answers.push(answerData);
            });
        }

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

    // Simple client-side validation
    // (We could expand this, but the backend does the heavy lifting now)
    return true;
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
    if (!validateForm()) return;

    const payload = generateJsonPayload();
    if (!payload) return;

    try {
        const response = await fetch(`/api/blueprints/${projectId}/`, {
            method: 'PUT',
            headers: { 'Authorization': `Bearer ${getToken()}`, 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        if (response.status === 401) {
            alert("Session expired.");
            window.location.href = '/login/';
            return;
        }

        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.detail || 'Failed to save project.');
        }

        alert('Project saved successfully!');
        loadProjectData(); // Reload to get new IDs
    } catch (error) {
        alert(`Save Error: ${error.message}`);
    }
}

// --- MODAL & SEARCH LOGIC ---

function attachModalEvents() {
    const modal = document.getElementById("blockSearchModal");
    const btn = document.getElementById("open-import-modal-btn");
    const span = document.querySelector(".close-modal");
    const searchBtn = document.getElementById("blockSearchBtn");
    const searchInput = document.getElementById("blockSearchInput");

    if (btn) btn.onclick = () => modal.style.display = "block";
    if (span) span.onclick = () => modal.style.display = "none";
    window.onclick = (e) => { if (e.target == modal) modal.style.display = "none"; }

    if (searchBtn) searchBtn.onclick = () => searchUserBlocks(searchInput.value);
    if (searchInput) {
        searchInput.addEventListener("keypress", (e) => {
            if (e.key === "Enter") {
                e.preventDefault();
                searchUserBlocks(searchInput.value);
            }
        });
    }
}

async function searchUserBlocks(query) {
    const container = document.getElementById('searchResultsContainer');
    const mode = document.getElementById('searchModeSelect').value;
    container.innerHTML = '<p style="text-align:center;">Loading...</p>';

    try {
        let url = `/api/blueprints/my-blocks/?mode=${mode}`;
        if (query && query.trim()) url += `&query=${encodeURIComponent(query)}`;

        const response = await fetch(url, { headers: { 'Authorization': `Bearer ${getToken()}` } });
        if (!response.ok) throw new Error("Search failed.");
        const blocks = await response.json();

        container.innerHTML = '';
        if (blocks.length === 0) {
            container.innerHTML = '<p style="text-align:center;">No questions found.</p>';
            return;
        }

        blocks.forEach(block => {
            const div = document.createElement('div');
            div.className = 'search-result-item';
            div.innerHTML = `
                <div>
                    <strong>${block.type}</strong>: ${block.maintext || block.gap_text || '(No Text)'}
                </div>
                <button class="insert-btn" style="background:#17a2b8; color:white; border:none; padding:5px;">Insert</button>
            `;
            div.querySelector('.insert-btn').onclick = () => {
                insertBlockAsCopy(block);
                document.getElementById("blockSearchModal").style.display = "none";
            };
            container.appendChild(div);
        });

    } catch (error) {
        container.innerHTML = `<p style="color:red; text-align:center;">Error: ${error.message}</p>`;
    }
}

function insertBlockAsCopy(originalBlock) {
    const blockData = JSON.parse(JSON.stringify(originalBlock));
    blockData.id = null;
    if (blockData.answers) {
        blockData.answers.forEach(ans => ans.id = null);
    }
    const newBlockElement = createBlockElement(blockData);
    document.getElementById('blocks-container').appendChild(newBlockElement);
    updateButtonStates();
    newBlockElement.scrollIntoView({ behavior: 'smooth' });
}

// --- EVENT HANDLERS ---

document.addEventListener('DOMContentLoaded', () => {
    if (!getToken()) return; // Redirect handled in loadProjectData
    loadProjectData();

    document.body.addEventListener('click', (event) => {
        const target = event.target;

        // Save
        if (target.id === 'save-project-btn') saveProject();

        // Add Block
        if (target.id === 'add-block-btn') {
            document.getElementById('blocks-container').appendChild(createBlockElement());
            updateButtonStates();
        }

        // Delete Block
        if (target.classList.contains('delete-block-btn')) {
            if (confirm('Delete this question?')) {
                target.closest('.block-item').remove();
                updateButtonStates();
            }
        }

        // Add Answer
        if (target.classList.contains('add-answer-btn')) {
            const blockItem = target.closest('.block-item');
            const type = blockItem.querySelector('.block-type').value;
            blockItem.querySelector('.answers-container').appendChild(createAnswerElement({}, type));
            updateButtonStates();
        }

        // Delete Answer
        if (target.classList.contains('delete-answer-btn')) {
            target.closest('.answer-item').remove();
            updateButtonStates();
        }
    });

    // Handle Type Changing (Show/Hide fields)
    document.body.addEventListener('change', (event) => {
        if (event.target.classList.contains('block-type')) {
            const newType = event.target.value;
            const blockItem = event.target.closest('.block-item');

            // 1. Toggle MainText vs GapText
            const mainTextField = blockItem.querySelector('.field-maintext');
            const gapTextField = blockItem.querySelector('.field-gap-text');

            if (newType === 'gap_fill') {
                mainTextField.classList.add('hidden');
                gapTextField.classList.remove('hidden');
            } else {
                mainTextField.classList.remove('hidden');
                gapTextField.classList.add('hidden');
            }

            // 2. Toggle Answer Container visibility (hide for static)
            const answersWrapper = blockItem.querySelector('.answers-wrapper');
            if (['text_block', 'divider'].includes(newType)) {
                answersWrapper.classList.add('hidden');
            } else {
                answersWrapper.classList.remove('hidden');

                // 3. Re-render answers if switching between logic types
                // (Because the inputs are different structure)
                const container = blockItem.querySelector('.answers-container');
                // We keep the data if possible, but rebuild DOM
                const currentAnswers = [];
                // Collect current values to preserve text if possible...
                // For simplicity in this demo, we might just clear them or keep them weird.
                // Let's just update the inputs of existing ones:

                const answerItems = container.querySelectorAll('.answer-item');
                answerItems.forEach(item => {
                    // It is easier to replace the innerHTML of answer items
                    // We need to construct a dummy answer object from current state
                    const dummyAns = {
                        text: item.querySelector('.answer-text')?.value,
                        // etc...
                    };
                    const newItem = createAnswerElement(dummyAns, newType);
                    item.replaceWith(newItem);
                });
            }
        }
    });
});