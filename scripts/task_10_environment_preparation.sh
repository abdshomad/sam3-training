#!/bin/bash
# Task ID: 1.0
# Description: Environment Preparation
# Created: 2025-12-12 21:43:32

set -e

echo "=========================================="
echo "Task 1.0: Environment Preparation"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

echo "Project root: ${PROJECT_ROOT}"
echo ""

# Step 1: Setup virtual environment using uv
echo "Step 1: Setting up virtual environment..."
if ! command -v uv &> /dev/null; then
    echo "ERROR: uv not found. Please install uv first."
    echo "Installation: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# SAM3 supports Python 3.8-3.12, prefer 3.12 (latest supported)
TARGET_PYTHON_VERSION="3.12"
echo "Target Python version for SAM3: ${TARGET_PYTHON_VERSION}"

# Check if venv exists and verify its Python version
VENV_NEEDS_RECREATE=false
if [ -d ".venv" ]; then
    echo "Virtual environment already exists, checking Python version..."
    if [ -f ".venv/bin/python" ]; then
        VENV_PYTHON_VERSION=$(.venv/bin/python --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
        echo "Existing venv Python version: ${VENV_PYTHON_VERSION}"
        if [ "${VENV_PYTHON_VERSION}" != "${TARGET_PYTHON_VERSION}" ]; then
            echo "Python version mismatch. Will recreate venv with Python ${TARGET_PYTHON_VERSION}..."
            VENV_NEEDS_RECREATE=true
        else
            echo "✓ Existing venv has correct Python version"
        fi
    else
        echo "Existing venv appears corrupted, will recreate..."
        VENV_NEEDS_RECREATE=true
    fi
else
    echo "No virtual environment found, will create one..."
    VENV_NEEDS_RECREATE=true
fi

# Create or recreate venv if needed
if [ "$VENV_NEEDS_RECREATE" = true ]; then
    # Remove existing venv if recreating
    if [ -d ".venv" ]; then
        echo "Removing existing virtual environment..."
        rm -rf .venv
    fi
    
    echo "Installing Python ${TARGET_PYTHON_VERSION} using uv..."
    uv python install "${TARGET_PYTHON_VERSION}" || {
        echo "WARNING: Failed to install Python ${TARGET_PYTHON_VERSION} via uv"
        echo "Attempting to create venv with available Python version..."
    }
    
    echo "Creating virtual environment with Python ${TARGET_PYTHON_VERSION}..."
    if uv python list 2>/dev/null | grep -q "${TARGET_PYTHON_VERSION}" || uv python install "${TARGET_PYTHON_VERSION}" 2>/dev/null; then
        uv venv --python "${TARGET_PYTHON_VERSION}"
    else
        echo "Python ${TARGET_PYTHON_VERSION} not available, using default Python..."
        uv venv
    fi
    echo "✓ Virtual environment created"
fi

# Activate virtual environment
if [ -f ".venv/bin/activate" ]; then
    echo "Activating virtual environment..."
    source .venv/bin/activate
    echo "✓ Virtual environment activated"
    
    # Install dependencies from pyproject.toml using uv sync
    # Skip uv sync if SAM3 is already installed (to avoid uninstalling it)
    if [ -f "pyproject.toml" ]; then
        # Check if SAM3 is already installed before syncing
        if uv pip show sam3 &>/dev/null; then
            SAM3_EDITABLE=$(uv pip show sam3 2>/dev/null | grep "^Editable project location:" | cut -d: -f2 | xargs)
            if [ -n "${SAM3_EDITABLE}" ] && echo "${SAM3_EDITABLE}" | grep -q "${PROJECT_ROOT}/sam3"; then
                echo "SAM3 already installed, skipping uv sync to avoid reinstallation..."
                echo "✓ Skipped uv sync (SAM3 already installed)"
            else
                echo "Installing dependencies from pyproject.toml..."
                uv sync || {
                    echo "WARNING: uv sync failed, but continuing..."
                }
                echo "✓ Dependencies synced from pyproject.toml"
            fi
        else
            echo "Installing dependencies from pyproject.toml..."
            uv sync || {
                echo "WARNING: uv sync failed, but continuing..."
            }
            echo "✓ Dependencies synced from pyproject.toml"
        fi
    fi
else
    echo "ERROR: Failed to activate virtual environment"
    exit 1
fi

echo ""

# Step 2: Verify Python environment (Task 1.1)
echo "Step 2: Verifying Python environment..."
"${SCRIPT_DIR}/task_11_verify_python_environment.sh"
if [ $? -ne 0 ]; then
    echo "ERROR: Python environment verification failed"
    exit 1
fi

# Step 3: Install SAM3 dependencies (Task 1.2)
echo "Step 3: Installing SAM3 dependencies..."
"${SCRIPT_DIR}/task_12_install_sam3_dependencies.sh"
if [ $? -ne 0 ]; then
    echo "ERROR: SAM3 dependencies installation failed"
    exit 1
fi

echo "=========================================="
echo "Environment preparation completed successfully!"
echo "=========================================="
echo ""

