// RF100VL Supercategories
const RF100VL_SUPERCATEGORIES = [
    '-grccs', 'zebrasatasturias', 'cod-mw-warzone', 'canalstenosis',
    'label-printing-defect-version-2', 'new-defects-in-wood', 'orionproducts',
    'aquarium-combined', 'varroa-mites-detection--test-set', 'clashroyalechardetector',
    'stomata-cells', 'halo-infinite-angel-videogame', 'pig-detection',
    'urine-analysis1', 'aerial-sheep', 'orgharvest', 'actions', 'mahjong',
    'liver-disease', 'needle-base-tip-min-max', 'wheel-defect-detection',
    'aircraft-turnaround-dataset', 'xray', 'wildfire-smoke', 'spinefrxnormalvindr',
    'ufba-425', 'speech-bubbles-detection', 'train', 'pill', 'truck-movement',
    'car-logo-detection', 'inbreast', 'sea-cucumbers-new-tiles', 'uavdet-small',
    'penguin-finder-seg', 'aerial-airport', 'bibdetection', 'taco-trash-annotations-in-context',
    'bees', 'recode-waste', 'screwdetectclassification', 'wine-labels', 'aerial-cows',
    'into-the-vale', 'gwhd2021', 'lacrosse-object-detection', 'defect-detection',
    'dataconvert', 'x-ray-id', 'ball', 'tube', '2024-frc', 'crystal-clean-brain-tumors-mri-dataset',
    'grapes-5', 'human-detection-in-floods', 'buoy-onboarding',
    'apoce-aerial-photographs-for-object-detection-of-construction-equipment',
    'l10ul502', 'floating-waste', 'deeppcb', 'ism-band-packet-detection', 'weeds4',
    'invoice-processing', 'thermal-cheetah', 'tomatoes-2', 'marine-sharks', 'peixos-fish',
    'sssod', 'aerial-pool', 'countingpills', 'asphaltdistressdetection', 'roboflow-trained-dataset',
    'everdaynew', 'underwater-objects', 'soda-bottles', 'dentalai', 'jellyfish', 'deepfruits',
    'activity-diagrams', 'circuit-voltages', 'all-elements', 'macro-segmentation',
    'exploratorium-daphnia', 'signatures', 'conveyor-t-shirts', 'fruitjes', 'grass-weeds',
    'infraredimageofpowerequipment', '13-lkc01', 'wb-prova', 'flir-camera-objects',
    'paper-parts', 'football-player-detection', 'trail-camera', 'smd-components',
    'water-meter', 'nih-xray', 'the-dreidel-project', 'electric-pylon-detection-in-rsi',
    'cable-damage'
];

// API Base URL
const API_BASE = window.location.origin;

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    initializeTabs();
    initializeForms();
    initializeDashboard();
    populateSupercategories();
    setupClusterModeToggle();
});

// Tab Management
function initializeTabs() {
    const tabButtons = document.querySelectorAll('.tab-button');
    const tabContents = document.querySelectorAll('.tab-content');

    tabButtons.forEach(button => {
        button.addEventListener('click', () => {
            const targetTab = button.getAttribute('data-tab');

            // Update buttons
            tabButtons.forEach(btn => btn.classList.remove('active'));
            button.classList.add('active');

            // Update content
            tabContents.forEach(content => content.classList.remove('active'));
            document.getElementById(`${targetTab}-tab`).classList.add('active');

            // Refresh dashboard if switching to it
            if (targetTab === 'jobs') {
                loadJobs();
            }
        });
    });
}

// Populate RF100VL supercategories dropdown
function populateSupercategories() {
    const select = document.getElementById('rf100vl-supercategory');
    RF100VL_SUPERCATEGORIES.forEach(cat => {
        const option = document.createElement('option');
        option.value = cat;
        option.textContent = cat;
        select.appendChild(option);
    });
}

// Setup cluster mode toggle
function setupClusterModeToggle() {
    const rf100vlMode = document.getElementById('rf100vl-mode');
    const odinwMode = document.getElementById('odinw-mode');
    const rf100vlClusterSettings = document.getElementById('rf100vl-cluster-settings');
    const odinwClusterSettings = document.getElementById('odinw-cluster-settings');

    rf100vlMode.addEventListener('change', (e) => {
        if (e.target.value === 'cluster') {
            rf100vlClusterSettings.classList.add('visible');
        } else {
            rf100vlClusterSettings.classList.remove('visible');
        }
    });

    odinwMode.addEventListener('change', (e) => {
        if (e.target.value === 'cluster') {
            odinwClusterSettings.classList.add('visible');
        } else {
            odinwClusterSettings.classList.remove('visible');
        }
    });
}

// Form Initialization
function initializeForms() {
    const rf100vlForm = document.getElementById('rf100vl-form');
    const odinwForm = document.getElementById('odinw-form');

    rf100vlForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        await submitTrainingJob('rf100vl', rf100vlForm);
    });

    odinwForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        await submitTrainingJob('odinw', odinwForm);
    });
}

// Submit Training Job
async function submitTrainingJob(datasetType, form) {
    const formData = new FormData(form);
    const data = {};

    // Convert form data to object, handling checkboxes and empty values
    for (const [key, value] of formData.entries()) {
        if (value !== '') {
            if (key.startsWith('skip_') || key === 'dry_run') {
                data[key] = true;
            } else if (key === 'num_gpus' || key === 'num_nodes') {
                data[key] = parseInt(value) || null;
            } else {
                data[key] = value;
            }
        }
    }

    // Handle checkboxes that weren't checked
    const checkboxes = form.querySelectorAll('input[type="checkbox"]');
    checkboxes.forEach(checkbox => {
        if (!checkbox.checked) {
            const key = checkbox.name;
            if (key.startsWith('skip_') || key === 'dry_run') {
                data[key] = false;
            }
        }
    });

    // Remove null/empty values
    Object.keys(data).forEach(key => {
        if (data[key] === null || data[key] === '') {
            delete data[key];
        }
    });

    try {
        showNotification('Submitting training job...', 'info');
        const response = await fetch(`${API_BASE}/api/train/${datasetType}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(data),
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || 'Failed to submit job');
        }

        const job = await response.json();
        showNotification(`Job ${job.job_id.substring(0, 8)} submitted successfully!`, 'success');

        // Switch to jobs tab and refresh
        document.querySelector('[data-tab="jobs"]').click();
        await loadJobs();

        // If async mode, show logs modal
        if (data.execution_mode === 'async') {
            setTimeout(() => {
                viewJobLogs(job.job_id);
            }, 1000);
        }
    } catch (error) {
        showNotification(`Error: ${error.message}`, 'error');
        console.error('Submit error:', error);
    }
}

// Dashboard Initialization
function initializeDashboard() {
    const refreshButton = document.getElementById('refresh-jobs');
    const statusFilter = document.getElementById('status-filter');

    refreshButton.addEventListener('click', () => loadJobs());
    statusFilter.addEventListener('change', () => loadJobs());

    // Auto-refresh every 5 seconds
    setInterval(() => {
        if (document.getElementById('jobs-tab').classList.contains('active')) {
            loadJobs();
        }
    }, 5000);
}

// Load Jobs
async function loadJobs() {
    const statusFilter = document.getElementById('status-filter').value;
    const url = statusFilter
        ? `${API_BASE}/api/jobs?status=${statusFilter}`
        : `${API_BASE}/api/jobs`;

    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error('Failed to load jobs');

        const data = await response.json();
        displayJobs(data.jobs);
    } catch (error) {
        showNotification(`Error loading jobs: ${error.message}`, 'error');
        console.error('Load jobs error:', error);
    }
}

// Display Jobs
function displayJobs(jobs) {
    const tbody = document.getElementById('jobs-tbody');
    tbody.innerHTML = '';

    if (jobs.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" style="text-align: center; padding: 20px;">No jobs found</td></tr>';
        return;
    }

    jobs.forEach(job => {
        const row = document.createElement('tr');
        const createdDate = new Date(job.created_at).toLocaleString();
        const shortId = job.job_id.substring(0, 8);

        row.innerHTML = `
            <td>${shortId}</td>
            <td>${job.dataset_type.toUpperCase()}</td>
            <td><span class="status-badge status-${job.status}">${job.status}</span></td>
            <td>${createdDate}</td>
            <td class="action-buttons">
                ${job.status === 'running' || job.status === 'pending' 
                    ? `<button class="btn-small btn-cancel" onclick="cancelJob('${job.job_id}')">Cancel</button>` 
                    : ''}
                <button class="btn-small btn-view-logs" onclick="viewJobLogs('${job.job_id}')">View Logs</button>
                ${job.status !== 'running' && job.status !== 'pending'
                    ? `<button class="btn-small btn-delete" onclick="deleteJob('${job.job_id}')">Delete</button>`
                    : ''}
            </td>
        `;
        tbody.appendChild(row);
    });
}

// View Job Logs
function viewJobLogs(jobId) {
    const modal = document.getElementById('log-modal');
    const logContent = document.getElementById('log-content');
    const modalTitle = document.getElementById('log-modal-title');

    modal.classList.add('active');
    logContent.textContent = 'Connecting...';
    modalTitle.textContent = `Job Logs: ${jobId.substring(0, 8)}`;

    // Connect via WebSocket
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const ws = new WebSocket(`${protocol}//${window.location.host}/api/jobs/${jobId}/logs`);

    ws.onmessage = (event) => {
        if (event.data.startsWith('{')) {
            // JSON message (status update)
            try {
                const data = JSON.parse(event.data);
                if (data.status) {
                    logContent.textContent += `\n\n[Job ${data.status}]`;
                    if (data.exit_code !== undefined) {
                        logContent.textContent += ` Exit code: ${data.exit_code}`;
                    }
                }
            } catch (e) {
                // Not JSON, treat as log line
                logContent.textContent += event.data + '\n';
            }
        } else {
            // Text log line
            logContent.textContent += event.data + '\n';
        }
        // Auto-scroll to bottom
        logContent.scrollTop = logContent.scrollHeight;
    };

    ws.onerror = (error) => {
        logContent.textContent += '\n\n[Connection error]';
        console.error('WebSocket error:', error);
    };

    ws.onclose = () => {
        logContent.textContent += '\n\n[Connection closed]';
    };

    // Close modal handlers
    const closeBtn = document.querySelector('.close');
    const closeModal = () => {
        ws.close();
        modal.classList.remove('active');
    };

    closeBtn.onclick = closeModal;
    modal.onclick = (e) => {
        if (e.target === modal) closeModal();
    };
}

// Cancel Job
async function cancelJob(jobId) {
    if (!confirm('Are you sure you want to cancel this job?')) return;

    try {
        const response = await fetch(`${API_BASE}/api/jobs/${jobId}/cancel`, {
            method: 'POST',
        });

        if (!response.ok) throw new Error('Failed to cancel job');

        showNotification('Job cancelled successfully', 'success');
        await loadJobs();
    } catch (error) {
        showNotification(`Error cancelling job: ${error.message}`, 'error');
        console.error('Cancel job error:', error);
    }
}

// Delete Job
async function deleteJob(jobId) {
    if (!confirm('Are you sure you want to delete this job?')) return;

    try {
        const response = await fetch(`${API_BASE}/api/jobs/${jobId}`, {
            method: 'DELETE',
        });

        if (!response.ok) throw new Error('Failed to delete job');

        showNotification('Job deleted successfully', 'success');
        await loadJobs();
    } catch (error) {
        showNotification(`Error deleting job: ${error.message}`, 'error');
        console.error('Delete job error:', error);
    }
}

// Show Notification
function showNotification(message, type = 'info') {
    const notifications = document.getElementById('notifications');
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;

    notifications.appendChild(notification);

    setTimeout(() => {
        notification.style.animation = 'slideIn 0.3s reverse';
        setTimeout(() => notification.remove(), 300);
    }, 5000);
}

