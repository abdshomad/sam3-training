#!/bin/bash
# Start script for SAM3 Training Web App (background)
# Starts the app in the background and saves PID

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
PID_FILE="${PROJECT_ROOT}/webapp/webapp.pid"
LOG_FILE="${PROJECT_ROOT}/webapp/webapp.log"

cd "${PROJECT_ROOT}"

# Load environment variables from .env file if it exists
if [ -f "${PROJECT_ROOT}/.env" ]; then
    set -a  # Automatically export all variables
    source "${PROJECT_ROOT}/.env"
    set +a  # Turn off automatic export
fi

# Check if already running
if [ -f "${PID_FILE}" ]; then
    PID=$(cat "${PID_FILE}")
    if ps -p "${PID}" > /dev/null 2>&1; then
        echo "Web app is already running (PID: ${PID})"
        echo "Use ./stop.sh to stop it first"
        exit 1
    else
        echo "Removing stale PID file"
        rm -f "${PID_FILE}"
    fi
fi

# Check if virtual environment exists
if [ ! -d "${PROJECT_ROOT}/.venv" ]; then
    echo "ERROR: Virtual environment not found. Run ./install.sh first"
    exit 1
fi

# Default port
PORT="${WEBAPP_PORT:-8001}"

echo "=========================================="
echo "Starting SAM3 Training Web App"
echo "=========================================="
echo ""
echo "Port: ${PORT}"
echo "PID file: ${PID_FILE}"
echo "Log file: ${LOG_FILE}"
echo ""

# Start the app in background
nohup uv run uvicorn webapp.main:app --host 0.0.0.0 --port "${PORT}" > "${LOG_FILE}" 2>&1 &
PID=$!

# Save PID
echo "${PID}" > "${PID_FILE}"

# Wait a moment to check if it started successfully
sleep 2

if ps -p "${PID}" > /dev/null 2>&1; then
    echo "✓ Web app started successfully"
    echo "  PID: ${PID}"
    echo "  URL: http://localhost:${PORT}"
    echo ""
    echo "To stop: ./stop.sh"
    echo "To monitor: ./monitor.sh"
    echo "To view logs: tail -f ${LOG_FILE}"
else
    echo "ERROR: Failed to start web app"
    echo "Check logs: ${LOG_FILE}"
    rm -f "${PID_FILE}"
    exit 1
fi

