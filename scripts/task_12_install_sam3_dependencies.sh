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
if python -m pip show sam3 &>/dev/null; then
    SAM3_INFO=$(python -m pip show sam3 2>/dev/null)
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

# Check if pip is available (use python -m pip to ensure we use venv's pip)
if ! python -m pip --version &> /dev/null; then
    echo "ERROR: pip not found. Installing pip..."
    python -m ensurepip --upgrade || {
        echo "ERROR: Failed to install pip. Please ensure pip is available."
        exit 1
    }
fi

# Use python -m pip to ensure we're using the venv's pip
PIP_CMD="python -m pip"
echo "Using pip: $(${PIP_CMD} --version)"

# Check Python version
PYTHON_VERSION=$(python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PYTHON_MAJOR_MINOR=$(python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "Python version: ${PYTHON_VERSION}"

# Verify Python version is supported (3.8-3.12)
PYTHON_MAJOR=$(python -c "import sys; print(sys.version_info.major)")
PYTHON_MINOR=$(python -c "import sys; print(sys.version_info.minor)")
if [ "${PYTHON_MAJOR}" -ne 3 ] || [ "${PYTHON_MINOR}" -lt 8 ] || [ "${PYTHON_MINOR}" -gt 12 ]; then
    echo "WARNING: Python ${PYTHON_VERSION} is not officially supported by SAM3 (requires 3.8-3.12)"
    echo "You may encounter compatibility issues."
    echo ""
fi

echo "SAM3 not found. Installing SAM3 with training dependencies..."
echo "Running: ${PIP_CMD} install -e \".[train]\""
echo ""

# Install SAM3 with training dependencies
if ${PIP_CMD} install -e ".[train]"; then
    echo ""
    echo "✓ SAM3 installation completed successfully"
    echo ""
else
    echo ""
    echo "ERROR: SAM3 installation failed"
    echo ""
    echo "Troubleshooting tips:"
    echo "  - Ensure Python version is 3.8-3.12 (SAM3 requirement)"
    echo "  - Check that all system dependencies are installed"
    echo "  - Verify internet connection for downloading packages"
    echo "  - Try using: uv python install 3.12 && uv venv --python 3.12"
    exit 1
fi

echo "SAM3 dependencies installation completed."
echo ""

