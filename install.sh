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

echo "Step 1: Installing Python 3.12..."
if ! uv python list | grep -q "3.12"; then
    uv python install 3.12
    echo "✓ Python 3.12 installed"
else
    echo "✓ Python 3.12 already installed"
fi
echo ""

echo "Step 2: Creating virtual environment with Python 3.12..."
if [ ! -d "${PROJECT_ROOT}/.venv" ]; then
    uv venv --python 3.12
    echo "✓ Virtual environment created with Python 3.12"
else
    echo "✓ Virtual environment already exists"
    # Ensure it's using Python 3.12
    VENV_PYTHON_VERSION=$("${PROJECT_ROOT}/.venv/bin/python" --version 2>&1 | grep -oP '3\.\d+' || echo "")
    if [ "${VENV_PYTHON_VERSION}" != "3.12" ]; then
        echo "Note: Existing venv uses Python ${VENV_PYTHON_VERSION}, recreating with Python 3.12..."
        rm -rf "${PROJECT_ROOT}/.venv"
        uv venv --python 3.12
        echo "✓ Virtual environment recreated with Python 3.12"
    fi
fi
echo ""

echo "Step 3: Installing dependencies..."
uv sync
echo "✓ Dependencies installed"
echo ""

echo "Step 4: Verifying installation..."
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

