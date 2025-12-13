# Web App Management Scripts

These scripts are located in the repository root directory and manage the SAM3 Training Web App.

## Scripts Overview

### `install.sh`
Installs dependencies and sets up the virtual environment using `uv`.

**Usage:**
```bash
./install.sh
```

**What it does:**
- Creates virtual environment (`.venv`) if it doesn't exist
- Installs all dependencies using `uv sync`
- Verifies the installation

### `run.sh`
Runs the web app in the **foreground** (for debugging).

**Usage:**
```bash
./run.sh
```

**Features:**
- Runs with auto-reload enabled
- Press Ctrl+C to stop
- Output visible in terminal

### `start.sh`
Starts the web app in the **background**.

**Usage:**
```bash
./start.sh
```

**Features:**
- Runs in background using `nohup`
- Saves PID to `webapp/webapp.pid`
- Logs output to `webapp/webapp.log`
- Default port: 8001 (set `WEBAPP_PORT` env var to change)

### `stop.sh`
Stops the background web app process.

**Usage:**
```bash
./stop.sh
```

**Features:**
- Graceful shutdown (SIGTERM)
- Force kill if needed (SIGKILL)
- Cleans up PID file

### `restart.sh`
Restarts the web app (stops and starts).

**Usage:**
```bash
./restart.sh
```

**Features:**
- Stops existing instance if running
- Starts a new instance
- Useful for applying changes

### `monitor.sh`
Monitors the web app status and shows information.

**Usage:**
```bash
./monitor.sh
```

**Shows:**
- Process status (running/stopped)
- Process information (PID, CPU, memory, uptime)
- Port status
- API health check
- Log file information (last 10 lines)
- Job statistics

## Quick Start

1. **Install:**
   ```bash
   ./install.sh
   ```

2. **Start:**
   ```bash
   ./start.sh
   ```

3. **Monitor:**
   ```bash
   ./monitor.sh
   ```

4. **Stop:**
   ```bash
   ./stop.sh
   ```

## Environment Variables

- `WEBAPP_PORT`: Port to run the web app on (default: 8001)

**Configuration:**
The port can be set in two ways:

1. **In `.env` file (recommended):**
   ```bash
   WEBAPP_PORT=8018
   ```
   All scripts automatically load variables from `.env` if it exists.

2. **As environment variable:**
   ```bash
   export WEBAPP_PORT=9000
   ./start.sh
   ```

**Note:** If `WEBAPP_PORT` is set in `.env`, it will be used by all scripts automatically.

## File Locations

- **PID file:** `webapp/webapp.pid`
- **Log file:** `webapp/webapp.log`
- **Virtual environment:** `.venv/` (project root)

## Troubleshooting

### App won't start
- Check if port is already in use: `netstat -tlnp | grep 8001`
- Check logs: `tail -f webapp/webapp.log`
- Verify installation: `./install.sh`

### App won't stop
- Check PID: `cat webapp/webapp.pid`
- Manually kill: `kill $(cat webapp/webapp.pid)`
- Force kill: `kill -9 $(cat webapp/webapp.pid)`

### View logs in real-time
```bash
tail -f webapp/webapp.log
```

### Check if app is running
```bash
./monitor.sh
```

