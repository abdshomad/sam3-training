#!/bin/bash
# Run script for SAM3 Training Web App (foreground)
# Runs the app in the foreground for debugging

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

cd "${PROJECT_ROOT}"

# Load environment variables from .env file if it exists
if [ -f "${PROJECT_ROOT}/.env" ]; then
    set -a  # Automatically export all variables
    source "${PROJECT_ROOT}/.env"
    set +a  # Turn off automatic export
fi

# Check if virtual environment exists
if [ ! -d "${PROJECT_ROOT}/.venv" ]; then
    echo "ERROR: Virtual environment not found. Run ./install.sh first"
    exit 1
fi

# Default port
PORT="${WEBAPP_PORT:-8001}"

echo "=========================================="
echo "SAM3 Training Web App"
echo "=========================================="
echo ""
echo "Starting web app on port ${PORT}..."
echo "Press Ctrl+C to stop"
echo ""
echo "Access the app at: http://localhost:${PORT}"
echo ""

# Run the app
uv run uvicorn webapp.main:app --host 0.0.0.0 --port "${PORT}" --reload

