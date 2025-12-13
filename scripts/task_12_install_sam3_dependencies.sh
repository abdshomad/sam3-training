#!/bin/bash
# Task ID: 1.2
# Description: Install SAM3 Dependencies
# Created: 2025-12-12 21:43:32

set -e

echo "=========================================="
echo "Task 1.2: Install SAM3 Dependencies"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SAM3_DIR="${PROJECT_ROOT}/sam3"

# Check if sam3 directory exists
if [ ! -d "${SAM3_DIR}" ]; then
    echo "ERROR: sam3 directory not found at ${SAM3_DIR}"
    exit 1
fi

# Check if pyproject.toml exists in sam3 directory
if [ ! -f "${SAM3_DIR}/pyproject.toml" ]; then
    echo "ERROR: pyproject.toml not found in ${SAM3_DIR}"
    exit 1
fi

echo "Changing to sam3 directory: ${SAM3_DIR}"
cd "${SAM3_DIR}"

# Check if SAM3 is already installed in the current Python environment
echo "Checking if SAM3 is already installed..."
if uv pip show sam3 &>/dev/null; then
    SAM3_INFO=$(uv pip show sam3 2>/dev/null)
    SAM3_LOCATION=$(echo "${SAM3_INFO}" | grep "^Location:" | cut -d: -f2 | xargs)
    SAM3_EDITABLE=$(echo "${SAM3_INFO}" | grep "^Editable project location:" | cut -d: -f2 | xargs)
    
    if [ -n "${SAM3_EDITABLE}" ]; then
        echo "✓ SAM3 is already installed as editable at: ${SAM3_EDITABLE}"
        # Check if it's from the expected sam3 directory
        if echo "${SAM3_EDITABLE}" | grep -q "${SAM3_DIR}"; then
            echo "✓ SAM3 editable install matches expected location"
            echo "Skipping installation."
            echo ""
            exit 0
        else
            echo "Note: SAM3 editable install found but from different location. Will reinstall."
        fi
    elif [ -n "${SAM3_LOCATION}" ]; then
        echo "✓ SAM3 is already installed at: ${SAM3_LOCATION}"
        echo "Note: SAM3 found but may not be editable. Will reinstall to ensure editable setup."
    fi
fi

# Check if uv is available
if ! command -v uv &> /dev/null; then
    echo "ERROR: uv not found. Please install uv first."
    echo "Installation: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Skip uv sync if SAM3 is already properly installed
# This prevents unnecessary reinstallation
if uv pip show sam3 &>/dev/null; then
    SAM3_EDITABLE=$(uv pip show sam3 2>/dev/null | grep "^Editable project location:" | cut -d: -f2 | xargs)
    if [ -n "${SAM3_EDITABLE}" ] && echo "${SAM3_EDITABLE}" | grep -q "${SAM3_DIR}"; then
        echo "SAM3 already installed, skipping root pyproject.toml sync to avoid reinstallation..."
    else
        # Ensure dependencies from pyproject.toml are installed via uv sync
        if [ -f "${PROJECT_ROOT}/pyproject.toml" ]; then
            echo "Ensuring dependencies from pyproject.toml are installed..."
            cd "${PROJECT_ROOT}"
            uv sync --quiet || {
                echo "WARNING: uv sync failed, but continuing with SAM3 installation..."
            }
            cd "${SAM3_DIR}"
        else
            echo "Note: pyproject.toml not found at project root, skipping uv sync"
        fi
    fi
else
    # Ensure dependencies from pyproject.toml are installed via uv sync
    if [ -f "${PROJECT_ROOT}/pyproject.toml" ]; then
        echo "Ensuring dependencies from pyproject.toml are installed..."
        cd "${PROJECT_ROOT}"
        uv sync --quiet || {
            echo "WARNING: uv sync failed, but continuing with SAM3 installation..."
        }
        cd "${SAM3_DIR}"
    else
        echo "Note: pyproject.toml not found at project root, skipping uv sync"
    fi
fi

# Check Python version
PYTHON_VERSION=$(uv run python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "Python version: ${PYTHON_VERSION}"

# Verify Python version is supported (3.9-3.12)
PYTHON_MAJOR=$(python -c "import sys; print(sys.version_info.major)")
PYTHON_MINOR=$(python -c "import sys; print(sys.version_info.minor)")
if [ "${PYTHON_MAJOR}" -ne 3 ] || [ "${PYTHON_MINOR}" -lt 9 ] || [ "${PYTHON_MINOR}" -gt 12 ]; then
    echo "WARNING: Python ${PYTHON_VERSION} is not officially supported by SAM3 (requires 3.9-3.12)"
    echo "You may encounter compatibility issues."
    echo ""
fi

echo "Installing SAM3 package in editable mode with training dependencies..."
echo "Running: uv pip install -e \".[train]\""
echo ""

# Install SAM3 with training dependencies using uv pip
if uv pip install -e ".[train]"; then
    echo ""
    echo "✓ SAM3 installation completed successfully"
    echo ""
else
    echo ""
    echo "ERROR: SAM3 installation failed"
    echo ""
    echo "Troubleshooting tips:"
    echo "  - Ensure Python version is 3.9-3.12 (SAM3 requirement)"
    echo "  - Run 'uv sync' at project root to install dependencies from pyproject.toml"
    echo "  - Check that all system dependencies are installed"
    echo "  - Verify internet connection for downloading packages"
    echo "  - Try using: uv python install 3.12 && uv venv --python 3.12"
    exit 1
fi

# Install additional dependencies required for training but only in [notebooks] extras
# These are needed for training but not included in [train] extras
echo "Ensuring additional training dependencies are installed..."
MISSING_DEPS=()

# Check and install einops (required for sam3.sam.rope)
if ! uv pip show einops &>/dev/null; then
    MISSING_DEPS+=("einops")
fi

# Check and install decord (required for sam3.train.data.sam3_image_dataset)
if ! uv pip show decord &>/dev/null; then
    MISSING_DEPS+=("decord")
fi

# Check and install pycocotools (required for sam3.train.data.coco_json_loaders)
if ! uv pip show pycocotools &>/dev/null; then
    MISSING_DEPS+=("pycocotools")
fi

# Check and install psutil (required for sam3.model.sam3_video_predictor)
if ! uv pip show psutil &>/dev/null; then
    MISSING_DEPS+=("psutil")
fi

# Check and install opencv-python (required for sam3.train.transforms.point_sampling)
if ! uv pip show opencv-python &>/dev/null; then
    MISSING_DEPS+=("opencv-python")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "Installing missing dependencies: ${MISSING_DEPS[*]}..."
    if uv pip install "${MISSING_DEPS[@]}"; then
        echo "✓ Additional dependencies installed successfully"
    else
        echo "WARNING: Failed to install some dependencies, but continuing..."
        echo "Note: The following are required for training: ${MISSING_DEPS[*]}"
        echo "You may need to install them manually:"
        echo "  uv pip install ${MISSING_DEPS[*]}"
    fi
else
    echo "✓ All additional dependencies are already installed"
fi
echo ""

echo "SAM3 dependencies installation completed."
echo ""

