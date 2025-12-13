#!/bin/bash
# Monitor script for SAM3 Training Web App
# Shows status, logs, and process information

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

echo "=========================================="
echo "SAM3 Training Web App - Monitor"
echo "=========================================="
echo ""

# Check if running
if [ ! -f "${PID_FILE}" ]; then
    echo "Status: ❌ NOT RUNNING"
    echo "PID file not found"
    echo ""
    echo "Start the app with: ./start.sh"
    exit 0
fi

PID=$(cat "${PID_FILE}")

if ! ps -p "${PID}" > /dev/null 2>&1; then
    echo "Status: ❌ NOT RUNNING"
    echo "Process ${PID} not found (stale PID file)"
    echo ""
    echo "Start the app with: ./start.sh"
    rm -f "${PID_FILE}"
    exit 0
fi

# Get process info
PROCESS_INFO=$(ps -p "${PID}" -o pid,ppid,cmd,etime,pcpu,pmem --no-headers 2>/dev/null || echo "")

if [ -z "${PROCESS_INFO}" ]; then
    echo "Status: ❌ NOT RUNNING"
    exit 0
fi

echo "Status: ✅ RUNNING"
echo ""
echo "Process Information:"
echo "  PID: ${PID}"
echo "  Details: ${PROCESS_INFO}"
echo ""

# Check if port is listening
PORT="${WEBAPP_PORT:-8001}"
if command -v netstat &> /dev/null; then
    if netstat -tlnp 2>/dev/null | grep -q ":${PORT}"; then
        echo "Port ${PORT}: ✅ LISTENING"
    else
        echo "Port ${PORT}: ❌ NOT LISTENING"
    fi
elif command -v ss &> /dev/null; then
    if ss -tlnp 2>/dev/null | grep -q ":${PORT}"; then
        echo "Port ${PORT}: ✅ LISTENING"
    else
        echo "Port ${PORT}: ❌ NOT LISTENING"
    fi
fi
echo ""

# Health check
echo "Health Check:"
if curl -s "http://localhost:${PORT}/api/health" > /dev/null 2>&1; then
    HEALTH_RESPONSE=$(curl -s "http://localhost:${PORT}/api/health" 2>/dev/null || echo "{}")
    echo "  API: ✅ RESPONDING"
    echo "  Response: ${HEALTH_RESPONSE}"
else
    echo "  API: ❌ NOT RESPONDING"
fi
echo ""

# Log file info
if [ -f "${LOG_FILE}" ]; then
    LOG_SIZE=$(du -h "${LOG_FILE}" | cut -f1)
    LOG_LINES=$(wc -l < "${LOG_FILE}" 2>/dev/null || echo "0")
    echo "Log File:"
    echo "  Path: ${LOG_FILE}"
    echo "  Size: ${LOG_SIZE}"
    echo "  Lines: ${LOG_LINES}"
    echo ""
    echo "Last 10 lines of log:"
    echo "----------------------------------------"
    tail -n 10 "${LOG_FILE}" 2>/dev/null || echo "(log file empty or unreadable)"
    echo "----------------------------------------"
else
    echo "Log file not found: ${LOG_FILE}"
fi
echo ""

# Job statistics (if API is responding)
if curl -s "http://localhost:${PORT}/api/jobs" > /dev/null 2>&1; then
    echo "Job Statistics:"
    JOBS_JSON=$(curl -s "http://localhost:${PORT}/api/jobs" 2>/dev/null || echo '{"total":0,"jobs":[]}')
    TOTAL=$(echo "${JOBS_JSON}" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('total', 0))" 2>/dev/null || echo "0")
    echo "  Total jobs: ${TOTAL}"
    
    if [ "${TOTAL}" -gt 0 ]; then
        RF100VL=$(echo "${JOBS_JSON}" | python3 -c "import sys, json; data=json.load(sys.stdin); print(sum(1 for j in data.get('jobs', []) if j.get('dataset_type')=='rf100vl'))" 2>/dev/null || echo "0")
        ODINW=$(echo "${JOBS_JSON}" | python3 -c "import sys, json; data=json.load(sys.stdin); print(sum(1 for j in data.get('jobs', []) if j.get('dataset_type')=='odinw'))" 2>/dev/null || echo "0")
        echo "  RF100VL jobs: ${RF100VL}"
        echo "  ODinW jobs: ${ODINW}"
    fi
    echo ""
fi

echo "Commands:"
echo "  ./stop.sh     - Stop the web app"
echo "  ./restart.sh  - Restart the web app"
echo "  tail -f ${LOG_FILE}  - Follow logs in real-time"
echo ""

