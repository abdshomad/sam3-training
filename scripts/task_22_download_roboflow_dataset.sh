#!/bin/bash
# Task ID: 2.2
# Description: Download Roboflow Dataset
# Created: 2025-12-12

set -e

echo "=========================================="
echo "Task 2.2: Download Roboflow Dataset"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

# Activate virtual environment if .venv exists and not already active
if [ -z "${VIRTUAL_ENV}" ] && [ -f ".venv/bin/activate" ]; then
    echo "Activating virtual environment..."
    source .venv/bin/activate
    echo "✓ Virtual environment activated"
elif [ -n "${VIRTUAL_ENV}" ]; then
    echo "✓ Virtual environment already active: ${VIRTUAL_ENV}"
elif [ ! -f ".venv/bin/activate" ]; then
    echo "WARNING: .venv not found. Consider running task_10_environment_preparation.sh first"
    echo "Continuing with system Python..."
fi

# Load environment variables from .env file if it exists
if [ -f "${PROJECT_ROOT}/.env" ]; then
    echo "Loading environment variables from .env file..."
    # Source .env file, but don't fail if it doesn't export ROBOFLOW_API_KEY
    set +e  # Temporarily disable exit on error for sourcing
    source "${PROJECT_ROOT}/.env"
    set -e  # Re-enable exit on error
    echo "✓ Loaded .env file"
else
    echo "Note: .env file not found, using environment variables only"
fi

# Load RF100-VL specific environment variables from .env.rf100vl if it exists
if [ -f "${PROJECT_ROOT}/.env.rf100vl" ]; then
    echo "Loading RF100-VL environment variables from .env.rf100vl file..."
    set +e  # Temporarily disable exit on error for sourcing
    source "${PROJECT_ROOT}/.env.rf100vl"
    set -e  # Re-enable exit on error
    echo "✓ Loaded .env.rf100vl file"
fi

# Check if submodule is initialized
if [ ! -d "rf100-vl/rf100vl" ]; then
    echo "ERROR: rf100-vl submodule not found or not initialized"
    echo "Run: git submodule update --init --recursive"
    exit 1
fi

# Check for API key (from .env or environment)
if [ -z "${ROBOFLOW_API_KEY}" ]; then
    echo "WARNING: ROBOFLOW_API_KEY not found in environment or .env file"
    echo ""
    echo "To get your API key:"
    echo "1. Sign up for a free account at https://universe.roboflow.com/"
    echo "2. Go to your account settings to find your API key"
    echo "3. Add it to .env file: ROBOFLOW_API_KEY=your_key_here"
    echo "   Or export it: export ROBOFLOW_API_KEY=your_key_here"
    echo ""
    echo "Skipping dataset download. You can run this script later with the API key set."
    exit 0
fi

# Default download path
DOWNLOAD_PATH="${1:-./data/roboflow_vl_100}"

echo ""
echo "Download configuration:"
echo "  Download path: ${DOWNLOAD_PATH}"
echo ""

# Check if dataset already exists and has content
if [ -d "${DOWNLOAD_PATH}" ] && [ -n "$(ls -A "${DOWNLOAD_PATH}" 2>/dev/null)" ]; then
    echo "✓ Dataset directory already exists and contains data: ${DOWNLOAD_PATH}"
    echo "  Skipping package installation and download."
    echo ""
    echo "Dataset location: ${DOWNLOAD_PATH}"
    echo ""
    echo "If you want to re-download, remove the directory first:"
    echo "  rm -rf ${DOWNLOAD_PATH}"
    echo ""
    exit 0
fi

echo "  API Key: ${ROBOFLOW_API_KEY:0:10}... (hidden)"
echo ""

# Create download directory
mkdir -p "${DOWNLOAD_PATH}"

# Ensure dependencies from pyproject.toml are installed via uv sync first
if [ -f "${PROJECT_ROOT}/pyproject.toml" ]; then
    echo "Ensuring dependencies from pyproject.toml are installed..."
    uv sync --quiet || {
        echo "WARNING: uv sync failed, but continuing..."
    }
fi

# Install rf100vl package if not already installed
# Check if package is installed using the active Python (venv or system)
if ! uv run python -c "import rf100vl" 2>/dev/null; then
    echo "Installing rf100vl package in editable mode..."
    cd rf100-vl
    # Use uv pip install for local editable package installation
    # Explicitly use venv's Python if venv exists, otherwise use system Python
    if [ -f "${PROJECT_ROOT}/.venv/bin/python" ]; then
        # Use uv pip with explicit Python path to ensure installation into venv
        uv pip install -p "${PROJECT_ROOT}/.venv/bin/python" -e .
    else
        # Fallback to system Python if no venv
        echo "WARNING: No .venv found, installing to system Python"
        uv pip install -e .
    fi
    cd "${PROJECT_ROOT}"
    echo "✓ rf100vl package installed"
else
    echo "✓ rf100vl package already installed"
fi

# Download the dataset
echo "Starting download..."
echo "This may take a while depending on your internet connection..."
echo ""

# Use the active Python (from venv if activated, otherwise system)
uv run python << EOF
import os
from rf100vl import download_rf100vl

# Set API key
os.environ['ROBOFLOW_API_KEY'] = '${ROBOFLOW_API_KEY}'

# Download dataset
download_rf100vl(path='${DOWNLOAD_PATH}')
print("\n✓ Download completed successfully!")
print(f"Dataset saved to: ${DOWNLOAD_PATH}")
EOF

echo ""
echo "=========================================="
echo "Download completed!"
echo "=========================================="
echo ""
echo "Dataset location: ${DOWNLOAD_PATH}"
echo ""
echo "Next steps:"
echo "1. Verify the dataset structure matches the expected format"
echo "2. Update your config file if needed"
echo "3. Run training with:"
echo "   uv run python -m sam3.train.train -c configs/roboflow_v100/roboflow_v100_full_ft_100_images-copy.yaml --use-cluster 0 --num-gpus 2"
echo ""

exit 0

