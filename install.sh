#!/bin/bash
# Install script for SAM3 Training Web App
# Sets up virtual environment and installs dependencies using uv

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

cd "${PROJECT_ROOT}"

echo "=========================================="
echo "SAM3 Training Web App - Installation"
echo "=========================================="
echo ""
echo "Project root: ${PROJECT_ROOT}"
echo ""

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "ERROR: uv is not installed. Please install uv first."
    echo "Visit: https://github.com/astral-sh/uv"
    exit 1
fi

echo "Step 1: Creating virtual environment..."
if [ ! -d "${PROJECT_ROOT}/.venv" ]; then
    uv venv
    echo "✓ Virtual environment created"
else
    echo "✓ Virtual environment already exists"
fi
echo ""

echo "Step 2: Installing dependencies..."
uv sync
echo "✓ Dependencies installed"
echo ""

echo "Step 3: Verifying installation..."
if uv run python -c "from webapp.main import app; print('✓ Web app imports successfully')" 2>/dev/null; then
    echo "✓ Installation verified"
else
    echo "WARNING: Installation verification failed, but dependencies are installed"
fi
echo ""

echo "=========================================="
echo "Installation complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  ./start.sh    - Start the web app"
echo "  ./run.sh      - Run the web app (foreground)"
echo ""

