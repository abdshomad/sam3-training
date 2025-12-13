#!/bin/bash
# Description: Run all task scripts in the scripts folder in order
# Created: 2025-12-12

# Don't use set -e here because we want to handle errors manually

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
SCRIPTS_DIR="$REPO_ROOT/scripts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONTINUE_ON_ERROR=true
VERBOSE=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --continue-on-error|-c)
            CONTINUE_ON_ERROR=true
            shift
            ;;
        --stop-on-error|-s)
            CONTINUE_ON_ERROR=false
            shift
            ;;
        --quiet|-q)
            VERBOSE=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Run all task scripts in the scripts folder in order."
            echo ""
            echo "Options:"
            echo "  -c, --continue-on-error    Continue running scripts even if one fails (default)"
            echo "  -s, --stop-on-error         Stop on first error"
            echo "  -q, --quiet                 Reduce output verbosity"
            echo "  -h, --help                  Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Load environment variables from .env file if it exists
if [ -f "${REPO_ROOT}/.env" ]; then
    echo "Loading environment variables from .env file..."
    set -a  # Automatically export all variables
    source "${REPO_ROOT}/.env"
    set +a  # Turn off automatic export
    echo "✓ Loaded .env file"
    echo ""
fi

echo "=========================================="
echo "Running All Task Scripts"
echo "=========================================="
echo ""
echo "Scripts directory: $SCRIPTS_DIR"
echo "Continue on error: $CONTINUE_ON_ERROR"
echo ""

# Find all .sh scripts in the scripts directory
# Scripts are dynamically discovered - see plan/plan.md for expected tasks
SCRIPTS=($(find "$SCRIPTS_DIR" -maxdepth 1 -name "task_*.sh" -type f | sort))

if [ ${#SCRIPTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No task scripts found in $SCRIPTS_DIR${NC}"
    echo ""
    echo "Please refer to plan/plan.md for the list of expected tasks."
    echo "Scripts should be named following the pattern: task_[ID]_[description].sh"
    echo ""
    echo "Example expected tasks from plan:"
    echo "  - Hardware checks: 1.1.1 (GPU), 1.1.2 (CUDA), 1.1.3 (VRAM), 1.1.4 (Disk)"
    echo "  - Environment: 1.2.1 (Clone), 1.2.2 (Venv), 1.2.3 (PyTorch), 1.2.4 (SAM3), 1.2.5 (Weights)"
    echo "  - Monitoring: 1.3.1 (WandB), 1.3.2 (DVC), 1.3.3 (Remote Storage)"
    echo "  - Data: 2.1-2.5 (Data validation and downloads)"
    echo "  - Arguments: 3.0-3.3 (Argument parsing)"
    echo "  - Execution: 4.0-4.3 (Command construction)"
    echo "  - Post-execution: 5.0-5.2 (Monitoring and feedback)"
    exit 0
fi

echo "Found ${#SCRIPTS[@]} shell script(s) to run:"
for script in "${SCRIPTS[@]}"; do
    echo "  - $(basename "$script")"
done
echo ""

# Track results
SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_SCRIPTS=()

# Run each script
for script in "${SCRIPTS[@]}"; do
    script_name=$(basename "$script")
    
    echo "=========================================="
    echo -e "${BLUE}Running: $script_name${NC}"
    echo "=========================================="
    echo ""
    
    # Make script executable if it isn't already
    if [ ! -x "$script" ]; then
        chmod +x "$script"
    fi
    
    # Run the script and capture exit code
    bash "$script"
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ $script_name: SUCCESS${NC}"
        ((SUCCESS_COUNT++))
    else
        echo ""
        echo -e "${RED}✗ $script_name: FAILED (exit code: $exit_code)${NC}"
        ((FAILED_COUNT++))
        FAILED_SCRIPTS+=("$script_name")
        
        if [ "$CONTINUE_ON_ERROR" = false ]; then
            echo ""
            echo -e "${RED}Stopping execution due to error.${NC}"
            echo "Use --continue-on-error to continue running remaining scripts."
            exit $exit_code
        fi
    fi
    
    echo ""
done

# Print summary
echo "=========================================="
echo "Execution Summary"
echo "=========================================="
echo ""
echo "Total scripts: ${#SCRIPTS[@]}"
echo -e "${GREEN}Successful: $SUCCESS_COUNT${NC}"
echo -e "${RED}Failed: $FAILED_COUNT${NC}"
echo ""

if [ $FAILED_COUNT -gt 0 ]; then
    echo "Failed scripts:"
    for failed_script in "${FAILED_SCRIPTS[@]}"; do
        echo -e "  ${RED}✗ $failed_script${NC}"
    done
    echo ""
    exit 1
else
    echo -e "${GREEN}All scripts completed successfully!${NC}"
    echo ""
    exit 0
fi
