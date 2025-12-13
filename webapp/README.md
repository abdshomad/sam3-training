# SAM3 Training Web Application

A FastAPI-based web application for launching and monitoring SAM3 training jobs for RF100VL and ODinW datasets.

## Features

- **RF100VL Training**: Submit training jobs with full parameter support
- **ODinW Training**: Submit training jobs with config type selection
- **Job Management**: View, monitor, cancel, and delete training jobs
- **Real-time Logs**: Stream training logs via WebSocket
- **Execution Modes**: Support for both synchronous and asynchronous job execution
- **Cluster Support**: Configure SLURM cluster parameters for distributed training

## Installation

The web application dependencies are included in the main `pyproject.toml`. Install them with:

```bash
uv sync
```

## Running the Application

### Option 1: Using the run script

```bash
./webapp/run_server.sh
```

### Option 2: Using uvicorn directly

```bash
uv run uvicorn webapp.main:app --host 0.0.0.0 --port 8000 --reload
```

### Option 3: Using Python directly

```bash
uv run python -m webapp.main
```

The application will be available at `http://localhost:8000`

## Usage

1. **Submit Training Jobs**:
   - Navigate to the RF100VL or ODinW tab
   - Fill in the training parameters
   - Choose execution mode (sync/async)
   - Click "Submit Training Job"

2. **Monitor Jobs**:
   - Go to the Job Dashboard tab
   - View all jobs with their status
   - Filter by status if needed
   - Click "View Logs" to see real-time training output

3. **Manage Jobs**:
   - Cancel running jobs
   - Delete completed/failed jobs
   - View detailed job information

## API Endpoints

- `POST /api/train/rf100vl` - Submit RF100VL training job
- `POST /api/train/odinw` - Submit ODinW training job
- `GET /api/jobs` - List all jobs (optional status filter)
- `GET /api/jobs/{job_id}` - Get job details
- `GET /api/jobs/{job_id}/status` - Get job status
- `WS /api/jobs/{job_id}/logs` - Stream job logs (WebSocket)
- `POST /api/jobs/{job_id}/cancel` - Cancel running job
- `DELETE /api/jobs/{job_id}` - Delete job record
- `GET /api/health` - Health check

## Parameters

### RF100VL Parameters

- `supercategory`: Supercategory to train on (or "all" for job array)
- `mode`: Execution mode (local/cluster)
- `num_gpus`: Number of GPUs per node
- `num_nodes`: Number of nodes for distributed training
- `partition`, `account`, `qos`: SLURM cluster settings
- `roboflow_root`: Path to Roboflow dataset
- `experiment_dir`: Path to experiment logs
- `bpe_path`: Path to BPE vocabulary file
- `base_config`: Base config file path
- `skip_*`: Various skip options
- `dry_run`: Show what would be done without executing
- `execution_mode`: sync or async

### ODinW Parameters

- `config_type`: text_only, text_and_visual, visual_only, text_only_positive
- `mode`: Execution mode (local/cluster)
- `num_gpus`, `num_nodes`: Resource allocation
- `partition`, `account`, `qos`: SLURM cluster settings
- `odinw_root`: Path to ODinW dataset
- `experiment_dir`: Path to experiment logs
- `bpe_path`: Path to BPE vocabulary file
- `base_config`: Base config file path (overrides config_type)
- `skip_*`: Various skip options
- `dry_run`: Show what would be done without executing
- `execution_mode`: sync or async

## Architecture

- **Backend**: FastAPI with async support
- **Frontend**: Vanilla HTML/CSS/JavaScript
- **Job Management**: In-memory job storage with status tracking
- **Log Streaming**: WebSocket-based real-time log streaming
- **Script Execution**: Wraps existing training scripts (`train_rf100vl.sh`, `train_odinw.sh`)

## File Structure

```
webapp/
├── main.py                 # FastAPI application entry point
├── job_manager.py          # Job storage and management
├── routes.py               # API route handlers
├── training_executor.py    # Script execution wrapper
├── models.py               # Pydantic models
├── run_server.sh           # Server startup script
├── static/
│   ├── index.html         # Main UI
│   ├── style.css          # Styling
│   └── app.js             # Frontend logic
└── README.md              # This file
```

## Notes

- Jobs are stored in-memory and will be lost on server restart
- For production use, consider adding persistent storage (database)
- Logs are kept in memory (last 10,000 lines per job) and also written to files in `experiments/logs/`
- The application uses the existing training scripts, so all their features are available through the web interface

