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



