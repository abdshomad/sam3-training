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

# Get the parent project's Python interpreter to ensure we use the correct venv
PARENT_PYTHON="${PROJECT_ROOT}/.venv/bin/python"
if [ ! -f "${PARENT_PYTHON}" ]; then
    echo "ERROR: Parent project venv not found at ${PARENT_PYTHON}"
    echo "Please run task_10_environment_preparation.sh first"
    exit 1
fi

# Ensure we're using the parent project's venv
export VIRTUAL_ENV="${PROJECT_ROOT}/.venv"
export PATH="${PROJECT_ROOT}/.venv/bin:${PATH}"

# Check if SAM3 is already installed in the parent project's venv
echo "Checking if SAM3 is already installed..."
if "${PARENT_PYTHON}" -m pip show sam3 &>/dev/null 2>&1; then
    SAM3_INFO=$("${PARENT_PYTHON}" -m pip show sam3 2>/dev/null)
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
if "${PARENT_PYTHON}" -m pip show sam3 &>/dev/null 2>&1; then
    SAM3_EDITABLE=$("${PARENT_PYTHON}" -m pip show sam3 2>/dev/null | grep "^Editable project location:" | cut -d: -f2 | xargs)
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

# Check Python version using parent venv
PYTHON_VERSION=$("${PARENT_PYTHON}" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "Python version: ${PYTHON_VERSION}"

# Verify Python version is supported (3.9-3.12)
PYTHON_MAJOR=$("${PARENT_PYTHON}" -c "import sys; print(sys.version_info.major)")
PYTHON_MINOR=$("${PARENT_PYTHON}" -c "import sys; print(sys.version_info.minor)")
if [ "${PYTHON_MAJOR}" -ne 3 ] || [ "${PYTHON_MINOR}" -lt 9 ] || [ "${PYTHON_MINOR}" -gt 12 ]; then
    echo "WARNING: Python ${PYTHON_VERSION} is not officially supported by SAM3 (requires 3.9-3.12)"
    echo "You may encounter compatibility issues."
    echo ""
fi

echo "Installing SAM3 package in editable mode with training dependencies..."
echo "Running: uv pip install --python ${PARENT_PYTHON} -e \".[train]\""
echo ""

# Install SAM3 with training dependencies using uv pip with explicit Python
# Use --python to ensure we use the parent project's venv, not create a new one
if uv pip install --python "${PARENT_PYTHON}" -e ".[train]"; then
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

# Additional training dependencies (decord, einops, opencv-python, psutil, pycocotools)
# are now managed in pyproject.toml and will be installed via uv sync
echo "✓ Additional training dependencies are managed in pyproject.toml"
echo ""

echo "SAM3 dependencies installation completed."
echo ""

