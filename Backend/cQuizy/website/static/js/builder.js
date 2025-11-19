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
        addQuestionBtn.title = addQuestionBtn.disabled ? 'Egy projektnek nem lehet több, mint 100 kérdése.' : 'Új kérdés hozzáadása';
    }
    const allBlocks = document.querySelectorAll('.block-item');
    allBlocks.forEach(block => {
        const addAnswerBtn = block.querySelector('.add-answer-btn');
        if (addAnswerBtn) {
            const answerCount = block.querySelectorAll('.answer-item').length;
            addAnswerBtn.disabled = answerCount >= 10;
            addAnswerBtn.title = addAnswerBtn.disabled ? 'Egy kérdésnek nem lehet több, mint 10 válasza.' : 'Új válasz hozzáadása';
        }
    });
}

// --- DINAMIKUS HTML GENERÁLÓ FÜGGVÉNYEK ---

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
        <input type="text" class="answer-text" value="${answerText}" placeholder="Válaszlehetőség">
        <label>
            <input type="checkbox" class="answer-correct" ${isCorrect ? 'checked' : ''}> Helyes
        </label>
        <button class="delete-answer-btn">Válasz törlése</button>
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
            <h4>Kérdés</h4>
            <select class="block-type">
                <option value="SINGLE" ${blockType === 'SINGLE' ? 'selected' : ''}>Egy válaszos</option>
                <option value="MULTIPLE" ${blockType === 'MULTIPLE' ? 'selected' : ''}>Több válaszos</option>
                <option value="TEXT" ${blockType === 'TEXT' ? 'selected' : ''}>Szöveges</option>
            </select>
            <button class="delete-block-btn">Kérdés törlése</button>
        </div>
        <textarea class="block-question" rows="3" placeholder="Ide írd a kérdést...">${questionText}</textarea>
        <textarea class="block-subtext" rows="2" placeholder="Opcionális segédszöveg vagy instrukciók...">${subtext}</textarea>
        <div class="block-optional-fields">
            <input type="url" class="block-image-url" value="${imageUrl}" placeholder="Opcionális kép URL">
            <input type="url" class="block-link-url" value="${linkUrl}" placeholder="Opcionális link URL">
        </div>
        <div class="answers-container">
            <h5>Válaszok</h5>
        </div>
        <button class="add-answer-btn">Válasz hozzáadása</button>
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
    // Előző tartalom törlése
    const existingContainer = document.querySelector('.builder-container');
    if (existingContainer) existingContainer.remove();

    // ÚJ: Létrehozzuk a fő konténert, ami középre igazít
    const builderContainer = document.createElement('div');
    builderContainer.className = 'builder-container';

    const form = document.createElement('div');
    form.id = 'builder-form';
    form.innerHTML = `
        <h2>Projekt szerkesztő</h2>
        <div class="project-meta">
            <label>Projekt neve</label>
            <input type="text" id="project-name-input" value="${projectData.name}">
            <label>Projekt leírása</label>
            <textarea id="project-desc-input" rows="4">${projectData.desc || ''}</textarea>
        </div>
        <div id="blocks-container">
            <h3>Kérdések</h3>
        </div>
        <div class="builder-actions">
            <button id="add-block-btn">Kérdés hozzáadása</button>
            <button id="save-project-btn" class="primary-btn">Projekt mentése</button>
        </div>
    `;
    const blocksContainer = form.querySelector('#blocks-container');
    if (projectData.blocks && projectData.blocks.length > 0) {
        projectData.blocks.sort((a, b) => a.order - b.order).forEach(block => {
            blocksContainer.appendChild(createBlockElement(block));
        });
    }

    // A formot a konténerhez, a konténert pedig a body-hoz adjuk
    builderContainer.appendChild(form);
    container.appendChild(builderContainer);

    new Sortable(blocksContainer, {
        animation: 150,
        handle: '.drag-handle',
    });
    updateButtonStates();
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
        alert("A projekt neve nem lehet üres.");
        return false;
    }
    const blockElements = document.querySelectorAll('.block-item');
    for (let i = 0; i < blockElements.length; i++) {
        const blockEl = blockElements[i];
        const questionNum = i + 1;
        const questionText = blockEl.querySelector('.block-question').value;
        if (!questionText.trim()) {
            alert(`Hiba: A(z) #${questionNum}. kérdés nem lehet üres.`);
            return false;
        }
        const blockType = blockEl.querySelector('.block-type').value;
        const answerElements = blockEl.querySelectorAll('.answer-item');

        if ((blockType === 'SINGLE' || blockType === 'MULTIPLE') && answerElements.length < 2) {
            alert(`Hiba a(z) #${questionNum}. kérdésnél: A feleletválasztós kérdéseknek legalább két válaszlehetőséggel kell rendelkezniük.`);
            return false;
        }

        for (let j = 0; j < answerElements.length; j++) {
            const answerEl = answerElements[j];
            const answerNum = j + 1;
            const answerText = answerEl.querySelector('.answer-text').value;
            if (!answerText.trim()) {
                alert(`Hiba a(z) #${questionNum}. kérdésnél: A(z) #${answerNum}. válasz nem lehet üres.`);
                return false;
            }
        }
    }
    return true; // Minden ellenőrzés sikeres
}

// --- ADATKEZELŐ FÜGGVÉNYEK ---

async function loadProjectData() {
    const urlParams = new URLSearchParams(window.location.search);
    projectId = urlParams.get('projectId');
    if (!projectId) {
        document.body.innerHTML = '<h1>Nincs megadva projekt azonosító. <a href="/projects/">Vissza a projektekhez</a></h1>';
        return;
    }
    try {
        const response = await fetch(`/api/blueprints/${projectId}/`, { headers: { 'Authorization': `Bearer ${getToken()}` } });
        if (response.status === 401) {
            alert("Lejárt a munkameneted. Kérlek, jelentkezz be újra.");
            window.location.href = '/login/';
            return;
        }
        if (!response.ok) throw new Error('A projektadatok betöltése sikertelen.');
        projectState = await response.json();
        renderProjectForm(projectState);
    } catch (error) {
        document.body.innerHTML = `<h1>Hiba: ${error.message}</h1>`;
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
            alert("Lejárt a munkameneted. Kérlek, jelentkezz be újra.");
            window.location.href = '/login/';
            return;
        }
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(errorData.detail || 'A projekt mentése sikertelen.');
        }
        alert('A projekt sikeresen mentve!');
        loadProjectData();
    } catch (error) {
        alert(`Mentési hiba: ${error.message}`);
    }
}

// --- ESEMÉNYKEZELŐK ---

document.addEventListener('DOMContentLoaded', () => {
    if (!getToken()) {
        alert("A szerkesztő eléréséhez be kell jelentkezned.");
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
            if (confirm('Biztosan törlöd ezt a kérdést és az összes válaszát?')) {
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