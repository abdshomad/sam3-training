#!/bin/bash
# Task ID: 4.3
# Description: Job Array Configuration
# Created: 2025-12-12

set -e

echo "=========================================="
echo "Task 4.3: Job Array Configuration"
echo "=========================================="

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Change to project root
cd "${PROJECT_ROOT}"

# Initialize variables
CONFIG_ARG=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_ARG="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Detects and validates job array configuration in YAML config files."
            echo ""
            echo "Options:"
            echo "  -c, --config PATH         Config file path (required)"
            echo ""
            echo "Environment Variables:"
            echo "  SAM3_CONFIG_ARG           Config file path"
            echo ""
            echo "  -h, --help                Show this help message"
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Use environment variables if command-line args not provided
if [ -z "${CONFIG_ARG}" ] && [ -n "${SAM3_CONFIG_ARG}" ]; then
    CONFIG_ARG="${SAM3_CONFIG_ARG}"
fi
if [ -z "${CONFIG_ARG}" ] && [ -n "${SAM3_CONFIG_SUGGESTION}" ]; then
    CONFIG_ARG="${SAM3_CONFIG_SUGGESTION}"
    echo "Using suggested config: ${CONFIG_ARG}"
fi

# Validate required config argument
if [ -z "${CONFIG_ARG}" ]; then
    echo "ERROR: Config file path is required"
    echo ""
    echo "Provide config via:"
    echo "  - Command line: -c/--config PATH"
    echo "  - Environment: SAM3_CONFIG_ARG"
    echo ""
    echo "Example:"
    echo "  $0 -c configs/roboflow_v100/roboflow_v100_full_ft_100_images.yaml"
    exit 1
fi

# Normalize config path: ensure it starts with "configs/" for Hydra
if [[ ! "${CONFIG_ARG}" =~ ^configs/ ]]; then
    CONFIG_ARG="configs/${CONFIG_ARG}"
    echo "Normalized config path to: ${CONFIG_ARG}"
fi

# Validate config file exists
CONFIG_PATH="${PROJECT_ROOT}/sam3/sam3/train/${CONFIG_ARG}"

if [ ! -f "${CONFIG_PATH}" ]; then
    echo "ERROR: Config file not found at: ${CONFIG_PATH}"
    echo "Please verify the config path is correct."
    exit 1
fi

echo "✓ Config file validated: ${CONFIG_PATH}"
echo ""

# Use Python to parse YAML and detect job array configuration
# This script uses Python with yaml module to parse the config
python3 << EOF
import sys
import yaml
from pathlib import Path

config_path = Path("${CONFIG_PATH}")

try:
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
    
    # Check for submitit section
    submitit_conf = config.get("submitit", {})
    
    # Check for job_array section
    job_array = submitit_conf.get("job_array", {})
    
    num_tasks = job_array.get("num_tasks", 0)
    task_index = job_array.get("task_index", 0)
    
    print("Job Array Configuration Analysis:")
    print("=" * 50)
    
    if num_tasks > 0:
        print(f"✓ Job array ENABLED")
        print(f"  Number of tasks: {num_tasks}")
        print(f"  Current task_index: {task_index}")
        print("")
        
        # Check for dataset-specific configurations
        config_str = str(config_path)
        
        # Check for Roboflow supercategories
        if "all_roboflow_supercategories" in config:
            supercategories = config.get("all_roboflow_supercategories", [])
            if isinstance(supercategories, (list, dict)):
                count = len(supercategories)
                print(f"✓ Found Roboflow supercategories: {count} datasets")
                if count != num_tasks:
                    print(f"  WARNING: Number of supercategories ({count}) doesn't match num_tasks ({num_tasks})")
                else:
                    print(f"  ✓ Number of supercategories matches num_tasks")
            else:
                print(f"  WARNING: all_roboflow_supercategories is not a list or dict")
        
        # Check for ODinW supercategories
        if "all_odinw_supercategories" in config:
            supercategories = config.get("all_odinw_supercategories", [])
            if isinstance(supercategories, list):
                count = len(supercategories)
                print(f"✓ Found ODinW supercategories: {count} datasets")
                if count != num_tasks:
                    print(f"  WARNING: Number of supercategories ({count}) doesn't match num_tasks ({num_tasks})")
                else:
                    print(f"  ✓ Number of supercategories matches num_tasks")
            else:
                print(f"  WARNING: all_odinw_supercategories is not a list")
        
        # Check if config uses job_array.task_index in dataset selection
        config_content = config_path.read_text()
        if "job_array.task_index" in config_content or "\${submitit.job_array.task_index}" in config_content:
            print("✓ Config uses job_array.task_index for dataset selection")
        else:
            print("  NOTE: Config may not use job_array.task_index (check dataset selection logic)")
        
        print("")
        print("Job Array Behavior:")
        print(f"  - Training will create {num_tasks} separate jobs")
        print(f"  - Each job will process one dataset from the supercategory list")
        print(f"  - Job configs will be saved to: <experiment_log_dir>/job_array_configs/")
        print(f"  - Each job will have a unique config with task_index set (0 to {num_tasks-1})")
        
        # Detect config type
        if "roboflow" in config_str.lower():
            print("")
            print("Config Type: Roboflow 100-VL")
            print("  This will train on 100 different Roboflow datasets")
        elif "odinw" in config_str.lower():
            print("")
            print("Config Type: ODinW13")
            print("  This will train on 13 different ODinW datasets")
        
    else:
        print("Job array DISABLED or not configured")
        print(f"  num_tasks: {num_tasks if num_tasks else 'not set or 0'}")
        print("")
        print("To enable job arrays, add to config:")
        print("  submitit:")
        print("    job_array:")
        print("      num_tasks: <number>")
        print("      task_index: 0  # Will be set automatically per job")
    
    print("")
    print("=" * 50)
    
except FileNotFoundError:
    print(f"ERROR: Config file not found: {config_path}", file=sys.stderr)
    sys.exit(1)
except yaml.YAMLError as e:
    print(f"ERROR: Failed to parse YAML: {e}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"ERROR: Unexpected error: {e}", file=sys.stderr)
    sys.exit(1)
EOF

EXIT_CODE=$?

if [ ${EXIT_CODE} -ne 0 ]; then
    echo ""
    echo "ERROR: Failed to analyze job array configuration"
    echo "Make sure Python3 and PyYAML are installed"
    exit ${EXIT_CODE}
fi

echo ""
echo "Job array configuration analysis completed successfully!"
echo ""

exit 0

