# Agent Instructions

## Automated Task Script Creation Workflow

When the user types **"next"** or **"n"**, process tasks from `plan/plan.md`:

### Step 1: Parse and Identify Next Tasks

1. Read `plan/plan.md` and parse hierarchical task structure:
   - Format: `**TaskID - Task Name**` followed by `**Status:** Pending` and `**Implementation Datetime:** TBD`
2. Sort tasks by Task ID (numeric: 1.0, 1.1, 1.2, etc.)
3. Select the **next 3 consecutive pending tasks** in order

### Step 2: Create Scripts for Tasks

For each selected task:

1. **Extract**: Task ID, Description, and Technical Details
2. **Create Script File**: 
   - Type: **Python** (.py) for data processing/logic, **Shell** (.sh) for system commands/setup
   - Naming: `task_{TaskID}_{TaskName}.{py|sh}` in `scripts/` directory
   - Sanitize: Task ID `1.1.1` → `111`, Task Name → lowercase_with_underscores
3. **Write Script Content**:
   - Shebang: `#!/bin/bash` (shell) or `#!/usr/bin/env -S uv run python` (Python)
   - Header: Task ID, Description, Implementation Date
   - **Virtual Environment**: Always use `uv venv` and `uv sync` (never `pip install`)
     - Shell: `uv venv` then `source .venv/bin/activate` or use `uv run`
     - Python: Execute via `uv run python script.py` or ensure venv activated
   - Error handling: `set -e` (shell), try-except (Python)
   - Add progress logging
4. **Test Script**: **MANDATORY** - Test immediately after creation, fix issues, re-test until successful

### Step 3: Update Task Status

For each successfully tested script:
- Change `**Status:** Pending` → `**Status:** Script Created`
- Change `**Implementation Datetime:** TBD` → `**Implementation Datetime:** YYYY-MM-DD HH:MM:SS`
- Preserve exact formatting of `plan/plan.md`

### Step 4: Commit and Push

After all 3 tasks:
1. `git add plan/plan.md scripts/task_*.py scripts/task_*.sh`
2. `git commit -m "Create scripts for tasks [IDs]: [descriptions]"`
3. `git push`

## Dependency Management

**CRITICAL**: Use `uv` exclusively, never `pip`:

- **Dependencies**: Declare in `pyproject.toml` at project root
- **Virtual Environment**: `uv venv` creates `.venv` at project root
- **Installation**: `uv sync` (automatically uses `.venv`)
- **Execution**: 
  - Shell scripts: `uv venv` → `source .venv/bin/activate` or `uv run`
  - Python scripts: `uv run python script.py`

## Configuration Management

- **Settings** (`config.py`): Non-sensitive config values at project root
- **Secrets** (`.env`): Sensitive credentials at project root (use `python-dotenv`, ensure `.gitignore`)
- Python scripts: `import config` and `load_dotenv(Path(__file__).parent.parent / '.env')`
- Shell scripts: `source .env`

## SAM3-Specific Requirements

From `plan/plan.md`:

1. **Environment (1.0)**: Verify venv active; for SAM3 deps (task 1.2), use `pip install -e ".[train]"` in `sam3/` directory
2. **Data Validation (2.0)**: Define `roboflow_vl_100_root` and `odinw_data_root` (env vars/args); validate directory structure; verify YAML configs exist in `sam3/train/configs/`
3. **Arguments (3.0)**: Support `--mode local|cluster` (maps to `--use-cluster 0|1`), `--num-gpus`, `--num-nodes`, `--partition`, `--account`, `--qos`, train vs eval configs
4. **Execution (4.0)**: Build `python sam3/train/train.py -c [CONFIG] --use-cluster [0|1] --num-gpus [N]` dynamically; include cluster args when needed
5. **Post-Execution (5.0)**: Display `experiment_log_dir`; suggest TensorBoard command

## Important Notes

- Create `scripts/` directory if missing
- Process tasks sequentially by Task ID
- If <3 tasks remain, process all remaining
- Format: Preserve hierarchical list structure with `*` bullets and `**` bold
- Date: ISO format `YYYY-MM-DD HH:MM:SS` (or `YYYY-MM-DD`)
- Testing: **MANDATORY** - Test each script before marking complete
- Scripts: Well-commented, error handling, clear progress output

## Example Workflow

```
1. Parse plan/plan.md → Find tasks 1.0, 1.1, 1.2 (pending)
2. Create scripts/task_10_environment_preparation.sh
3. Test: `bash scripts/task_10_environment_preparation.sh` → fix issues → re-test
4. Repeat for 1.1, 1.2
5. Update plan/plan.md: Status → Script Created, Datetime → current
6. git add plan/plan.md scripts/task_*.sh && git commit -m "..." && git push
```

## Script Examples

**Shell Script:**
```bash
#!/bin/bash
# Task ID: 1.1.1
# Description: GPU Availability Check
# Created: 2024-01-15

set -e
if ! command -v nvidia-smi &> /dev/null; then
    echo "Error: nvidia-smi not found" && exit 1
fi
nvidia-smi
echo "GPU check completed."
```

**Python Script:**
```python
#!/usr/bin/env -S uv run python
"""Task ID: 1.3.4, Description: Verify Logging Integration"""

import sys
from pathlib import Path
from dotenv import load_dotenv
import config

load_dotenv(Path(__file__).parent.parent / '.env')

def main():
    import wandb
    wandb.login(key=os.getenv('WANDB_API_KEY'))
    print(f"WandB initialized for {config.WANDB_PROJECT_NAME}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```
