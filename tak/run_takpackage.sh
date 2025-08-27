#!/bin/bash
# Wrapper to run takpackage.sh as the tak user

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/tak_functions.sh"

# Check if user is root
if [ "$(id -u)" -ne 0 ]; then
  error "This script must be run with sudo"
  exit 1
fi

# Check if config file is specified
if [[ "$1" == "--config" && -n "$2" ]]; then
    CONFIG_FILE="$2"
    if [[ "$CONFIG_FILE" != /* ]]; then
        CONFIG_FILE="$SCRIPT_DIR/../configs/$CONFIG_FILE"
        if [[ ! "$CONFIG_FILE" == *.conf ]]; then
            CONFIG_FILE="${CONFIG_FILE}.conf"
        fi
    fi
    
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        shift 2
        CALLSIGN="$1"
        shift
        
        # Run the script with config values
        sudo -u tak "$SCRIPT_DIR/takpackage.sh" "$SERVER_IP" "$PORT" "$CALLSIGN" "$TEAM" "$ROLE" "$CERT_NAME" "$CERT_PASSWORD" "$APP_TYPE"
    else
        error "Config file not found: $CONFIG_FILE"
        echo "Available configs:"
        find "$SCRIPT_DIR/../configs" -name "*.conf" | sort
        exit 1
    fi
else
    # Run with command line arguments
    sudo -u tak "$SCRIPT_DIR/takpackage.sh" "$@"
fi