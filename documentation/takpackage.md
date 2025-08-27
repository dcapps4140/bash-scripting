# TAK Package Script

## Purpose
Creates data packages for different TAK client applications with proper certificate handling.

## Usage
```bash
./takpackage.sh [server_ip] [port] [callsign] [team] [role] [cert_name] [cert_password] [app_type]

Parameters

    server_ip: IP address of the TAK server (default: 103.63.28.21)
    port: Port number for the TAK server (default: 8089)
    callsign: User callsign (default: app-specific user)
    team: Team color (default: Cyan)
    role: User role (default: Team Member)
    cert_name: Certificate name (default: takserver)
    cert_password: Certificate password (default: atakatak)
    app_type: Application type: atak, wintak, itak, takaware, taktracker (default: takaware)

Special Features

    iOS compatibility for iTAK
    TAK Tracker compatibility with UUID as CN
    Extended validity periods for TAK Tracker
    Proper certificate attributes for each client type

Notes

    Must be run as the tak user
    Certificate files must be in /opt/tak/certs/files/
    EOF

Create a wrapper script in the repository

cat > ~/scripts/tak/run_takpackage.sh << 'EOF'
#!/bin/bash
Wrapper to run takpackage.sh as the tak user
Source common functions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/tak_functions.sh"
Check if user is root

if [ "$(id -u)" -ne 0 ]; then
error "This script must be run with sudo"
exit 1
fi
Check if config file is specified

if [[ "$1" == "--config" && -n "$2" ]]; then
CONFIG_FILE="$2"
if [[ "$CONFIG_FILE" != /* ]]; then
CONFIG_FILE="$SCRIPT_DIR/../configs/$CONFIG_FILE"
if [[ ! "$CONFIG_FILE" == *.conf ]]; then
CONFIG_FILE="${CONFIG_FILE}.conf"
fi
fi

code

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
