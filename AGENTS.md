# Agent Instructions

## Automated Task Script Creation Workflow

When the user types **"next"** or **"n"**, follow this workflow to process tasks from `plan/plan.md`:

### Step 1: Parse and Identify Next Tasks

1. Read the file `plan/plan.md`
2. Parse all markdown tables to find task rows
3. Identify tasks where:
   - Status contains `[ ] Pending` (brackets with a space: `[ ]`)
   - Implementation Date is empty (appears as `|  |` in the table)
4. Sort tasks by Task ID (e.g., 1.1.1, 1.1.2, 1.1.3, etc.)
   - Note: Task IDs appear as `**1.1.1**` (bolded) in the markdown, but sort by the numeric value
5. Select the **next 3 consecutive pending tasks** in order

### Step 2: Create Scripts for Tasks

For each of the 3 selected tasks:

1. **Read the Task Details**: Extract the Task ID, Description, and Technical Details/Commands
2. **Create Script File**: 
   - Determine the appropriate script type (Python or Shell) based on the task content:
     - Use **Python** (.py) for tasks involving data processing, API calls, file operations with logic, or when Python libraries are mentioned
     - Use **Shell** (.sh) for tasks involving system commands, environment setup, package installation, or simple command sequences
   - Create script file in the `scripts/` directory with naming format: `task_{TaskID}_{TaskName}.py` or `task_{TaskID}_{TaskName}.sh`
     - Sanitize Task ID for filename (remove dots and underscores, keep only numbers): `1.1.1` → `111`
     - Sanitize Task Name for filename: convert to lowercase, replace spaces with underscores, remove special characters (keep only alphanumeric and underscores)
     - Example: Task ID `1.1.1` with Description "GPU Availability Check" → `task_111_gpu_availability_check.sh`
     - Example: Task ID `1.2.3` with Description "Verify Logging Integration" → `task_123_verify_logging_integration.py`
3. **Write Script Content**:
   - Include shebang line (`#!/bin/bash` for shell, `#!/usr/bin/env python3` for Python)
   - Add a header comment with Task ID, Description, and Implementation Date
   - Convert Technical Details/Commands into executable script code:
     - For shell scripts: Write commands as-is, add error handling (`set -e` for exit on error)
       - **Virtual Environment**: Always ensure virtual environment exists and is activated
         - Use `uv venv` to create virtual environment if it doesn't exist
         - Activate virtual environment using `source .venv/bin/activate` or use `uv run` for commands
         - For dependency installation: Always use `uv sync` (never `pip install`)
         - Update `pyproject.toml` with new dependencies before running `uv sync`
     - For Python scripts: Write Python code that executes the equivalent operations
       - **Virtual Environment**: Use `uv run` to execute Python scripts, or ensure venv is activated
       - For shebang: Use `#!/usr/bin/env -S uv run python` or activate venv before execution
       - Assume dependencies are already installed via `uv sync` in the virtual environment
       - Add a comment noting that dependencies must be in `pyproject.toml`
   - Add output/logging to indicate task progress and completion
   - Make the script executable (for shell scripts, add `chmod +x`)
4. **Script Structure**:
   - Shell scripts should include: `set -e` (exit on error), proper error messages, and status output
   - Python scripts should include: `if __name__ == "__main__"`, try-except error handling, and informative print statements

5. **Test and Fix Script**:
   - **CRITICAL**: After creating each script, immediately test it to ensure it works correctly
   - **Virtual Environment Setup**: Before testing, ensure virtual environment exists:
     - Run `uv venv` to create `.venv` if it doesn't exist
     - Run `uv sync` to install dependencies in the virtual environment
   - For shell scripts: Run the script using `bash scripts/task_{TaskID}_{TaskName}.sh` or make it executable and run directly
     - Scripts should handle venv activation internally or use `uv run` for Python commands
   - For Python scripts: Run the script using `uv run python scripts/task_{TaskID}_{TaskName}.py` or ensure venv is activated
   - Check for errors, missing dependencies, import issues, syntax errors, or logical problems
   - If the script fails:
     - Analyze the error output
     - Fix the issue in the script
     - Re-test the script
     - Repeat this process until the script executes successfully without errors
   - Only proceed to update task status after the script has been successfully tested and verified to work
   - If testing reveals that the script cannot be fixed (e.g., missing system dependencies that cannot be installed), mark the task as failed with appropriate notes

### Step 3: Update Task Status

After creating the script for each task:

1. **Update Status**: 
   - Change `[ ] Pending` to `[x] Script Created` only for scripts that have been successfully created AND tested
   - Change `[ ] Pending` to `[x] Failed` if script creation or testing fails after all reasonable attempts to fix it
   - Preserve the exact spacing and formatting of the table

2. **Update Implementation Date**:
   - Set the Implementation Date to the current date in **ISO format: YYYY-MM-DD**
   - Example: `2024-01-15`
   - Use the actual current date when updating

3. **Add Script Reference**:
   - Optionally, add a note in the Technical Details or create a mapping document that links Task IDs to their corresponding script files

### Step 4: Commit and Push Changes

After updating all 3 tasks:

1. **Stage Changes**: 
   - Stage `docs/plan/plan.md` with `git add docs/plan/plan.md`
   - Stage all created and tested script files: `git add scripts/task_*.py scripts/task_*.sh`
   - Stage any other files that were created or modified during script creation and testing

2. **Create Commit Message**:
   - Format: `Create scripts for tasks [Task IDs]: [Brief descriptions]`
   - Example: `Create scripts for tasks 1.1.1, 1.1.2, 1.1.3: GPU check, CUDA verification, VRAM health check`
   - Include all 3 Task IDs and brief descriptions

3. **Commit**: 
   - Run `git commit -m "[commit message]"`

4. **Push**: 
   - Run `git push` to push changes to the remote repository

### Dependency Management

**CRITICAL**: All Python dependencies must be managed using `uv` and TOML files:

1. **Dependency Declaration (`pyproject.toml`)**:
   - Always declare Python dependencies in `pyproject.toml` at the project root
   - Never use `requirements.txt` files or `pip install` commands in scripts
   - Add dependencies to the `[project.dependencies]` or `[project.optional-dependencies]` section in `pyproject.toml`
   - Example structure:
     ```toml
     [project]
     name = "sam3-training"
     dependencies = [
         "python-dotenv>=1.0.0",
         "wandb>=0.15.0",
     ]
     ```

2. **Virtual Environment Management**:
   - **CRITICAL**: Always use `uv venv` to create and manage virtual environments
   - Create virtual environment with: `uv venv` (creates `.venv` directory by default)
   - Never rely on system Python or assume a virtual environment is activated
   - Shell scripts must ensure venv exists and is activated before running Python commands:
     - Option 1: Create venv if missing: `uv venv` then `source .venv/bin/activate`
     - Option 2: Use `uv run` for Python commands (automatically uses venv)
   - Python scripts should be executed via `uv run python script.py` or ensure venv is activated
   - The virtual environment (`.venv`) should be created at project root

3. **Dependency Installation**:
   - Always use `uv sync` to install dependencies instead of `pip install`
   - `uv sync` automatically creates `.venv` if it doesn't exist and installs dependencies there
   - For shell scripts that need to install dependencies: 
     - First ensure venv exists: `uv venv` (if needed)
     - Then use `uv sync` command to install dependencies in the venv
   - For Python scripts: Dependencies should already be installed via `uv sync` in the virtual environment
   - Never use `pip install` in scripts or documentation

4. **Implementation Requirements**:
   - Shell scripts that install dependencies must:
     - First ensure virtual environment exists: `uv venv` (if `.venv` doesn't exist)
     - Then use `uv sync` to install dependencies in the venv (not `pip install -r requirements.txt`)
     - Activate venv before running Python commands: `source .venv/bin/activate` or use `uv run`
   - Python scripts should:
     - Be executed via `uv run python script.py` (automatically uses venv)
     - Or ensure venv is activated before execution
     - Assume dependencies are already installed via `uv sync` in the virtual environment
   - If a script needs to ensure dependencies are installed:
     - Run `uv venv` to create venv if missing
     - Run `uv sync` to install dependencies in the venv
   - When creating scripts that require new dependencies, update `pyproject.toml` first, then run `uv sync`

5. **Why `uv venv` and `uv sync` over `pip install`**:
   - Faster installation and dependency resolution
   - Better dependency locking and reproducibility
   - Integrated with modern Python project standards (PEP 517/518)
   - Automatic virtual environment creation and management
   - `uv venv` creates isolated environments without manual activation issues
   - `uv sync` automatically uses the project's virtual environment

### Configuration and Secrets Management

**CRITICAL**: All scripts must follow these configuration management rules:

1. **Settings and Configuration (`config.py`)**:
   - Store all non-sensitive settings, configuration values, and parameters in `config.py` at the project root
   - Examples: project names, default paths, timeout values, feature flags, model parameters, etc.
   - Use Python variables/constants in `config.py` for easy import
   - Example structure:
     ```python
     # config.py
     WANDB_PROJECT_NAME = "sam3-training"
     DEFAULT_BATCH_SIZE = 32
     MODEL_CHECKPOINT_PATH = "./checkpoints"
     LOG_LEVEL = "INFO"
     ```

2. **Secrets and Credentials (`.env` file)**:
   - Store all sensitive information in `.env` file at the project root
   - Examples: API keys, passwords, tokens, database credentials, secret keys, etc.
   - Use `python-dotenv` library (declared in `pyproject.toml` and installed via `uv sync`) to load environment variables from `.env`
   - Access secrets using `os.getenv('VARIABLE_NAME')` after loading `.env`
   - Example structure:
     ```
     # .env
     WANDB_API_KEY=your_api_key_here
     DATABASE_PASSWORD=your_password_here
     SECRET_TOKEN=your_token_here
     ```

3. **Implementation Requirements**:
   - Python scripts must import from `config.py`: `import config`
   - Python scripts must load `.env` using: `load_dotenv(Path(__file__).parent.parent / '.env')`
   - Never hardcode configuration values or secrets directly in script files
   - Ensure `.env` is in `.gitignore` to prevent committing secrets
   - Shell scripts can source `.env` using: `source .env` or `set -a; source .env; set +a`

4. **File Locations**:
   - `config.py` should be at the project root: `/project_root/config.py`
   - `.env` should be at the project root: `/project_root/.env`
   - Scripts should reference these files relative to their location or use absolute paths from project root

### Important Notes

- **Script Directory**: Ensure the `scripts/` directory exists before creating scripts. Create it if it doesn't exist.
- **Table Format Preservation**: When updating status and dates, maintain the exact markdown table structure with pipe separators (`|`)
- **Task Order**: Always process tasks in sequential order by Task ID
- **Partial Completion**: If less than 3 tasks remain, process all remaining pending tasks
- **No Tasks Available**: If no pending tasks are found, inform the user that all tasks are complete
- **Date Format**: Always use ISO format (YYYY-MM-DD) for dates
- **Error Handling**: Continue processing remaining tasks even if script creation or testing fails for one, but clearly mark failed tasks
- **Script Type Selection**: Choose Python for complex logic, data processing, or when Python libraries are needed. Choose Shell for simple command sequences, system setup, or package installation (always use `uv sync` instead of `pip install`).
- **Virtual Environment**: Always use `uv venv` to create virtual environments. Never assume a venv is activated or use system Python directly. Use `uv run` for Python commands or activate `.venv/bin/activate` in shell scripts.
- **Dependency Management**: Always use `uv sync` to install Python dependencies. Declare all dependencies in `pyproject.toml`. Never use `pip install` or `requirements.txt` files. `uv sync` automatically creates and uses the `.venv` directory.
- **Script Quality**: Ensure scripts are well-commented, handle errors gracefully, and provide clear output indicating their progress and completion status.
- **Testing Requirement**: **MANDATORY** - Every script must be tested immediately after creation. Fix all issues found during testing before marking the task as complete. Do not proceed to the next task until the current script has been successfully tested and verified to work.
- **Task Name in Filename**: Always include the sanitized task name in the script filename to make it easier to identify scripts by their purpose.
- **Configuration Management**: 
  - **Settings/Configs**: Always store any settings, configuration values, or non-sensitive parameters in `config.py` at the project root
  - **Secrets**: Always store any secrets, API keys, passwords, tokens, or sensitive credentials in `.env` file at the project root
  - Python scripts should import from `config.py` for settings and use `python-dotenv` to load secrets from `.env`
  - Never hardcode configuration values or secrets directly in scripts
  - Ensure `.env` is listed in `.gitignore` to prevent committing secrets to version control

### Example Workflow

When user types "next":

```
1. Parse plan.md → Find tasks 1.1.1, 1.1.2, 1.1.3 (all pending)
2. Create scripts/ directory if it doesn't exist
3. Create script for task 1.1.1:
   - Extract Task ID: 1.1.1, Description: "GPU Availability Check"
   - Create scripts/task_111_gpu_availability_check.sh (shell script)
   - Content: nvidia-smi command with error handling and verification logic
   - Ensure venv setup if Python commands are used
   - Test script: Run `bash scripts/task_111_gpu_availability_check.sh`
   - Fix any issues found during testing, re-test until successful
4. Create script for task 1.1.2:
   - Extract Task ID: 1.1.2, Description: "CUDA Version Verification"
   - Create scripts/task_112_cuda_version_verification.sh (shell script)
   - Content: nvcc --version command with CUDA version verification
   - Ensure venv setup if Python commands are used
   - Test script: Run `bash scripts/task_112_cuda_version_verification.sh`
   - Fix any issues found during testing, re-test until successful
5. Create script for task 1.1.3:
   - Extract Task ID: 1.1.3, Description: "VRAM Health Check"
   - Create scripts/task_113_vram_health_check.sh (shell script)
   - Content: VRAM availability check using nvidia-smi
   - Ensure venv setup if Python commands are used
   - Test script: Run `bash scripts/task_113_vram_health_check.sh`
   - Fix any issues found during testing, re-test until successful
6. Update plan.md:
   - 1.1.1: `[ ] Pending` → `[x] Script Created`, date → `2024-01-15`
   - 1.1.2: `[ ] Pending` → `[x] Script Created`, date → `2024-01-15`
   - 1.1.3: `[ ] Pending` → `[x] Script Created`, date → `2024-01-15`
7. git add docs/plan/plan.md scripts/task_*.sh scripts/task_*.py
8. git commit -m "Create scripts for tasks 1.1.1, 1.1.2, 1.1.3: GPU check, CUDA verification, VRAM health check"
9. git push
```

### Script Examples

**Example Shell Script (task_111_gpu_availability_check.sh):**
```bash
#!/bin/bash
# Task ID: 1.1.1
# Description: GPU Availability Check
# Created: 2024-01-15

set -e

echo "Checking GPU availability..."

if ! command -v nvidia-smi &> /dev/null; then
    echo "Error: nvidia-smi not found. NVIDIA drivers may not be installed."
    exit 1
fi

nvidia-smi

echo "GPU check completed successfully."
```

**Example Shell Script with Dependencies (task_145_setup_environment.sh):**
```bash
#!/bin/bash
# Task ID: 1.4.5
# Description: Setup Environment
# Created: 2024-01-15

set -e

echo "Setting up environment and installing dependencies..."

# Ensure uv is available
if ! command -v uv &> /dev/null; then
    echo "Error: uv not found. Please install uv first."
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    uv venv
fi

# Activate virtual environment
source .venv/bin/activate

# Sync dependencies from pyproject.toml (instead of pip install)
# uv sync automatically uses the .venv directory
uv sync

echo "Environment setup completed successfully."
```

**Example Python Script (task_134_verify_logging_integration.py):**
```python
#!/usr/bin/env -S uv run python
"""
Task ID: 1.3.4
Description: Verify Logging Integration
Created: 2024-01-15

Note: This script should be executed using 'uv run python script.py' to ensure
the virtual environment is used. Dependencies (wandb, python-dotenv) should be
declared in pyproject.toml and installed via 'uv sync' before running this script.
"""

import sys
import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables from .env file
env_path = Path(__file__).parent.parent / '.env'
load_dotenv(env_path)

# Import configuration from config.py
try:
    import config
except ImportError:
    print("Error: config.py not found. Please create config.py with required settings.", file=sys.stderr)
    sys.exit(1)

def main():
    try:
        import wandb
        
        # Use settings from config.py
        project_name = config.WANDB_PROJECT_NAME
        print(f"Initializing WandB for project: {project_name}")
        
        # Use secrets from .env file
        wandb_api_key = os.getenv('WANDB_API_KEY')
        if not wandb_api_key:
            print("Error: WANDB_API_KEY not found in .env file", file=sys.stderr)
            return 1
        
        # Initialize wandb with API key from .env
        wandb.login(key=wandb_api_key)
        print("Successfully imported and configured wandb")
        
        # Add verification logic here
        print("WandB logging integration verified.")
        return 0
    except ImportError as e:
        print(f"Error: Failed to import wandb: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
```

