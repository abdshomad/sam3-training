#!/bin/bash
# Stop script for SAM3 Training Web App
# Stops the background process

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
PID_FILE="${PROJECT_ROOT}/webapp/webapp.pid"

cd "${PROJECT_ROOT}"

# Load environment variables from .env file if it exists
if [ -f "${PROJECT_ROOT}/.env" ]; then
    set -a  # Automatically export all variables
    source "${PROJECT_ROOT}/.env"
    set +a  # Turn off automatic export
fi

echo "=========================================="
echo "Stopping SAM3 Training Web App"
echo "=========================================="
echo ""

if [ ! -f "${PID_FILE}" ]; then
    echo "No PID file found. Web app may not be running."
    exit 0
fi

PID=$(cat "${PID_FILE}")

if ! ps -p "${PID}" > /dev/null 2>&1; then
    echo "Process ${PID} is not running. Removing stale PID file."
    rm -f "${PID_FILE}"
    exit 0
fi

echo "Stopping process ${PID}..."

# Try graceful shutdown first
kill "${PID}" 2>/dev/null || true

# Wait for process to stop
for i in {1..10}; do
    if ! ps -p "${PID}" > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Force kill if still running
if ps -p "${PID}" > /dev/null 2>&1; then
    echo "Process did not stop gracefully, forcing termination..."
    kill -9 "${PID}" 2>/dev/null || true
    sleep 1
fi

# Clean up PID file
if ! ps -p "${PID}" > /dev/null 2>&1; then
    rm -f "${PID_FILE}"
    echo "✓ Web app stopped successfully"
else
    echo "WARNING: Could not stop process ${PID}"
    exit 1
fi

