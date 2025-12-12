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

# Check if SAM3 is already installed
echo "Checking if SAM3 is already installed..."
if python -c "import sam3" 2>/dev/null; then
    echo "✓ SAM3 is already installed"
    echo "Skipping installation."
    echo ""
    exit 0
fi

# Check if pip is available
if ! command -v pip &> /dev/null; then
    echo "ERROR: pip not found. Please ensure pip is installed."
    exit 1
fi

echo "SAM3 not found. Installing SAM3 with training dependencies..."
echo "Running: pip install -e \".[train]\""
echo ""

# Install SAM3 with training dependencies
pip install -e ".[train]"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ SAM3 installation completed successfully"
    echo ""
else
    echo ""
    echo "ERROR: SAM3 installation failed"
    exit 1
fi

echo "SAM3 dependencies installation completed."
echo ""

