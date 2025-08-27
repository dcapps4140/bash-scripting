#!/bin/bash
# Template for new scripts

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/tak_functions.sh"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --config FILE    Use configuration file"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Load config if specified
if [[ -n "$CONFIG_FILE" ]]; then
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        error "Config file not found: $CONFIG_FILE"
        exit 1
    fi
fi

# Main script logic
success "Script executed successfully"
