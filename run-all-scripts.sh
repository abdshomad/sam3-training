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

echo "=========================================="
echo "Running All Task Scripts"
echo "=========================================="
echo ""
echo "Scripts directory: $SCRIPTS_DIR"
echo "Continue on error: $CONTINUE_ON_ERROR"
echo ""

# Find all .sh scripts in the scripts directory
# This will find: task_111, task_112, task_113, task_114, task_121, task_122, task_123, task_124, task_125, etc.
SCRIPTS=($(find "$SCRIPTS_DIR" -maxdepth 1 -name "task_*.sh" -type f | sort))

if [ ${#SCRIPTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No task scripts found in $SCRIPTS_DIR${NC}"
    echo ""
    echo "Expected scripts:"
    echo "  - task_111_gpu_availability_check.sh"
    echo "  - task_112_cuda_toolkit_verification.sh"
    echo "  - task_113_vram_health_check.sh"
    echo "  - task_114_disk_space_allocation.sh"
    echo "  - task_121_clone_sam3_repository.sh"
    echo "  - task_122_create_virtual_environment.sh"
    echo "  - task_123_install_pytorch.sh"
    echo "  - task_124_install_sam3_dependencies.sh"
    echo "  - task_125_download_pretrained_weights.sh"
    echo "  - task_131_wandb_initialization.sh"
    echo "  - task_132_dvc_initialization.sh"
    echo "  - task_133_configure_remote_storage.sh"
    exit 0
fi

echo "Found ${#SCRIPTS[@]} shell script(s) to run:"
for script in "${SCRIPTS[@]}"; do
    echo "  - $(basename "$script")"
done
echo ""

# Verify we found the expected scripts
EXPECTED_SCRIPTS=(
    "task_111_gpu_availability_check.sh"
    "task_112_cuda_toolkit_verification.sh"
    "task_113_vram_health_check.sh"
    "task_114_disk_space_allocation.sh"
    "task_121_clone_sam3_repository.sh"
    "task_122_create_virtual_environment.sh"
    "task_123_install_pytorch.sh"
    "task_124_install_sam3_dependencies.sh"
    "task_125_download_pretrained_weights.sh"
    "task_131_wandb_initialization.sh"
    "task_132_dvc_initialization.sh"
    "task_133_configure_remote_storage.sh"
)

FOUND_SCRIPT_NAMES=()
for script in "${SCRIPTS[@]}"; do
    FOUND_SCRIPT_NAMES+=("$(basename "$script")")
done

MISSING_SCRIPTS=()
for expected in "${EXPECTED_SCRIPTS[@]}"; do
    found=false
    for found_script in "${FOUND_SCRIPT_NAMES[@]}"; do
        if [ "$found_script" = "$expected" ]; then
            found=true
            break
        fi
    done
    if [ "$found" = false ]; then
        MISSING_SCRIPTS+=("$expected")
    fi
done

if [ ${#MISSING_SCRIPTS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Warning: The following expected scripts were not found:${NC}"
    for missing in "${MISSING_SCRIPTS[@]}"; do
        echo -e "  ${YELLOW}⚠ $missing${NC}"
    done
    echo ""
fi

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
