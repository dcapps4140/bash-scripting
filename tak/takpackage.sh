#!/bin/bash

# Enhanced TAK Server Data Package Script with Certificate Fixes
# This version is designed to run as the tak user
# Now with special handling for iOS and TAK Tracker certificates

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  echo "Enhanced TAK Server Data Package Script with Certificate Fixes"
  echo "Usage: $0 [server_ip] [port] [callsign] [team] [role] [cert_name] [cert_password] [app_type]"
  echo ""
  echo "Parameters:"
  echo "  server_ip     - IP address of the TAK server (default: 103.63.28.21)"
  echo "  port          - Port number for the TAK server (default: 8089)"
  echo "  callsign      - User callsign (default: app-specific user)"
  echo "  team          - Team color (default: Cyan)"
  echo "  role          - User role (default: Team Member)"
  echo "  cert_name     - Certificate name (default: takserver)"
  echo "  cert_password - Certificate password (default: atakatak)"
  echo "  app_type      - Application type: atak, wintak, itak, takaware, taktracker (default: takaware)"
  echo ""
  exit 0
fi

# Check if running as tak user
if [ "$(id -un)" != "tak" ]; then
  echo "This script must be run as the tak user. Please use: sudo -u tak $0"
  exit 1
fi

# Default values
SERVER_IP=${1:-"103.63.28.21"}
PORT=${2:-"8089"}
CALLSIGN=${3:-"wintak-user"}
TEAM=${4:-"Cyan"}
ROLE=${5:-"Team Member"}
CERT_NAME=${6:-"takserver"}
CERT_PASSWORD=${7:-"atakatak"}
APP_TYPE=${8:-"takaware"} # Default to takaware, can be "atak", "wintak", "itak", or "takaware"

# Set app-specific callsign if not provided
if [ "$CALLSIGN" == "wintak-user" ]; then
    case "$APP_TYPE" in
        "takaware")
            CALLSIGN="takaware-user"
            ;;
        "itak")
            CALLSIGN="itak-user"
            ;;
        "taktracker")
            CALLSIGN="taktracker-user"
            ;;
        *)
            CALLSIGN="tak-user"
            ;;
    esac
fi

# Create a unique working directory in /tmp
WORK_DIR="/tmp/tak_package_$(date +%s)"
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print error messages
error() {
    echo -e "${RED}ERROR: $1${NC}"
}

# Function to print success messages
success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

# Function to print warning messages
warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# Define client certificate filename based on callsign
CLIENT_CERT_FILENAME="${CALLSIGN}.p12"
CLIENT_KEY_FILENAME="${CALLSIGN}_key.pem"
CLIENT_CSR_FILENAME="${CALLSIGN}.csr"
CLIENT_CERT_PEM_FILENAME="${CALLSIGN}_cert.pem"

# Generate a random UUID
UUID=$(cat /proc/sys/kernel/random/uuid)

echo "Creating data package for ${APP_TYPE} with callsign ${CALLSIGN}..."
echo "Working directory: ${WORK_DIR}"

# Create necessary directories
if [[ "$APP_TYPE" == "takaware" || "$APP_TYPE" == "itak" || "$APP_TYPE" == "taktracker" ]]; then
    # For mobile apps, simpler structure
    :
else
    # For ATAK/WinTAK, create proper directory structure
    mkdir -p "${WORK_DIR}/MANIFEST"
    mkdir -p "${WORK_DIR}/certs"
fi

# Copy the server certificate
echo "Copying server certificate..."
if [[ "$APP_TYPE" == "takaware" || "$APP_TYPE" == "itak" || "$APP_TYPE" == "taktracker" ]]; then
    # For TakAware, iTAK, and TakTracker, we need both server.p12 and client certificate
    # First, try to find a server certificate
    SERVER_CERT_FILE=""
    if [[ "$CERT_NAME" == *".p12" ]]; then
    # Use the provided certificate name directly
    if [ -f "/opt/tak/certs/files/${CERT_NAME}" ]; then
        SERVER_CERT_FILE="${CERT_NAME}"
        cp "/opt/tak/certs/files/${CERT_NAME}" "${WORK_DIR}/server.p12"
        success "Using provided certificate: ${CERT_NAME} as server.p12"
    else
        error "Certificate file not found: /opt/tak/certs/files/${CERT_NAME}"
        exit 1
    fi
else
    # Try default certificate names
    for cert_file in takserver.p12 server.p12; do
        if [ -f "/opt/tak/certs/files/${cert_file}" ]; then
            SERVER_CERT_FILE="${cert_file}"
            cp "/opt/tak/certs/files/${cert_file}" "${WORK_DIR}/server.p12"
            success "Found ${cert_file}, using as server.p12"
            break
        fi
    done
    fi
    
    if [ -z "$SERVER_CERT_FILE" ]; then
        error "No server certificate found! Looked for takserver.p12 and server.p12"
        exit 1
    fi
    
    # Extract CA certificate if available
    if [ -f "/opt/tak/certs/files/ca.pem" ]; then
        cp "/opt/tak/certs/files/ca.pem" "${WORK_DIR}/"
        success "Found CA certificate"
        
        # Check if we have CA key
        if [ -f "/opt/tak/certs/files/ca-do-not-share.key" ]; then
            cp "/opt/tak/certs/files/ca-do-not-share.key" "${WORK_DIR}/"
            success "Found CA private key"
            HAS_CA_KEY=true
        else
            warning "CA private key not found at /opt/tak/certs/files/ca-do-not-share.key"
            HAS_CA_KEY=false
        fi
    else
        warning "CA certificate not found at /opt/tak/certs/files/ca.pem"
        warning "Will attempt to extract CA from the P12 file"
        # Extract CA from P12 if possible
        openssl pkcs12 -in "${WORK_DIR}/server.p12" -cacerts -nokeys -chain -out "${WORK_DIR}/ca.pem" -passin pass:${CERT_PASSWORD} -legacy 2>/dev/null
        HAS_CA_KEY=false
    fi
    
    # Look for a client certificate to use as client certificate
    CLIENT_CERT_FILE=""
    for cert_file in client.p12 user.p12 "${CERT_NAME}.p12" "${CALLSIGN}.p12"; do
        if [[ "$cert_file" != "takserver.p12" && "$cert_file" != "server.p12" && -f "/opt/tak/certs/files/${cert_file}" ]]; then
            CLIENT_CERT_FILE="${cert_file}"
            cp "/opt/tak/certs/files/${cert_file}" "${WORK_DIR}/${CLIENT_CERT_FILENAME}"
            CLIENT_CERT="${CLIENT_CERT_FILENAME}"
            success "Using ${cert_file} as ${CLIENT_CERT_FILENAME}"
            break
        fi
    done
    
    if [ -z "$CLIENT_CERT_FILE" ]; then
        warning "No client certificate found. Will generate a new client certificate."
        
        # Generate a new client certificate if we have the CA
        if [ "$HAS_CA_KEY" = true ]; then
            cd "${WORK_DIR}"
            
            # Create a new private key
            openssl genrsa -out "${CLIENT_KEY_FILENAME}" 2048
            
            # For TAK Tracker, use UUID as CN
            if [[ "$APP_TYPE" == "taktracker" ]]; then
                # Generate a UUID for the certificate CN
                CERT_UUID=$(cat /proc/sys/kernel/random/uuid)
                
                # Use UUID as the CN instead of callsign
                SUBJECT="/C=US/ST=Illinois/L=Deer-Creek/O=SMD/OU=Central/CN=${CERT_UUID}"
                echo "Using UUID as CN for TAK Tracker: $SUBJECT"
                
                # Store the UUID for reference
                echo "Certificate CN (UUID): ${CERT_UUID}" > taktracker_uuid.txt
                echo "This UUID will appear in the TAK Server dashboard"
            else
                # Use the callsign as the CN to make it show up correctly in the dashboard
                SUBJECT="/C=US/ST=Illinois/L=Deer-Creek/O=SMD/OU=Central/CN=${CALLSIGN}"
                echo "Using app-specific subject with callsign: $SUBJECT"
            fi
            
            # Create certificate request
            openssl req -new -key "${CLIENT_KEY_FILENAME}" -out "${CLIENT_CSR_FILENAME}" -subj "$SUBJECT"
            
            # Create extension file based on app type
            if [[ "$APP_TYPE" == "taktracker" ]]; then
                # For TAK Tracker, use only clientAuth (no serverAuth)
                cat > ext.conf << 'EOF2'
[v3_req]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = critical,clientAuth
EOF2
            else
                # For other apps, include both clientAuth and serverAuth
                cat > ext.conf << 'EOF2'
[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
EOF2
            fi
            
            # Sign the certificate with appropriate validity period
            if [[ "$APP_TYPE" == "taktracker" ]]; then
                # Use 100-year validity for TAK Tracker
                openssl x509 -req -in "${CLIENT_CSR_FILENAME}" -CA ca.pem -CAkey ca-do-not-share.key -CAcreateserial -out "${CLIENT_CERT_PEM_FILENAME}" -days 36500 -extensions v3_req -extfile ext.conf
            else
                # Standard 1-year validity for other apps
                openssl x509 -req -in "${CLIENT_CSR_FILENAME}" -CA ca.pem -CAkey ca-do-not-share.key -CAcreateserial -out "${CLIENT_CERT_PEM_FILENAME}" -days 365 -extensions v3_req -extfile ext.conf
            fi
            
            # Create P12 file with appropriate settings for each app type
            if [[ "$APP_TYPE" == "taktracker" ]]; then
                # For TAK Tracker, don't use -name parameter to avoid setting friendlyName
                openssl pkcs12 -export -out "${CLIENT_CERT_FILENAME}" -inkey "${CLIENT_KEY_FILENAME}" -in "${CLIENT_CERT_PEM_FILENAME}" -legacy -passout pass:itak
            elif [[ "$APP_TYPE" == "itak" ]]; then
                # For iTAK, use legacy encryption and proper friendlyName
                openssl pkcs12 -export -out "${CLIENT_CERT_FILENAME}" -inkey "${CLIENT_KEY_FILENAME}" -in "${CLIENT_CERT_PEM_FILENAME}" -name "${CALLSIGN}" -legacy -passout pass:itak
            else
                # For other apps
                openssl pkcs12 -export -out "${CLIENT_CERT_FILENAME}" -inkey "${CLIENT_KEY_FILENAME}" -in "${CLIENT_CERT_PEM_FILENAME}" -certfile ca.pem -name "${CALLSIGN}" -passout pass:itak
            fi
            
            CLIENT_CERT="${CLIENT_CERT_FILENAME}"
            CLIENT_PASSWORD="itak"
            success "Generated new client certificate as ${CLIENT_CERT_FILENAME} with password 'itak'"
            if [[ "$APP_TYPE" == "taktracker" ]]; then
                success "Certificate CN is UUID: ${CERT_UUID}"
            else
                success "Certificate CN is: ${CALLSIGN}"
            fi
        else
            error "Cannot generate client certificate without CA key. Please provide a client certificate."
            exit 1
        fi
    else
        CLIENT_PASSWORD="itak"
        
        # If we have an existing certificate but want to customize the CN, we need to extract, modify, and repackage it
        if [ "$HAS_CA_KEY" = true ]; then
            cd "${WORK_DIR}"
            
            # Extract the private key and certificate
            openssl pkcs12 -in "${CLIENT_CERT}" -nocerts -nodes -passin pass:${CLIENT_PASSWORD} -legacy > key.pem 2>/dev/null
            if [ $? -ne 0 ]; then
                warning "Failed to extract private key. Trying alternative passwords..."
                for alt_password in itak atakatak takaware password; do
                    echo "Trying password: $alt_password"
                    if openssl pkcs12 -in "${CLIENT_CERT}" -nocerts -nodes -passin pass:$alt_password -legacy > key.pem 2>/dev/null; then
                        success "Password is $alt_password"
                        CLIENT_PASSWORD=$alt_password
                        break
                    fi
                done
            fi
            
            # Extract certificate
            openssl pkcs12 -in "${CLIENT_CERT}" -clcerts -nokeys -passin pass:${CLIENT_PASSWORD} -legacy > cert.pem 2>/dev/null
            
            # For TAK Tracker, use UUID as CN
            if [[ "$APP_TYPE" == "taktracker" ]]; then
                # Generate a UUID for the certificate CN
                CERT_UUID=$(cat /proc/sys/kernel/random/uuid)
                
                # Use UUID as the CN instead of callsign
                SUBJECT="/C=US/ST=Illinois/L=Deer-Creek/O=SMD/OU=Central/CN=${CERT_UUID}"
                echo "Creating new certificate with UUID: $SUBJECT"
                
                # Store the UUID for reference
                echo "Certificate CN (UUID): ${CERT_UUID}" > taktracker_uuid.txt
                echo "This UUID will appear in the TAK Server dashboard"
            else
                # Create a new certificate request with app-specific subject
                SUBJECT="/C=US/ST=Illinois/L=Deer-Creek/O=SMD/OU=Central/CN=${CALLSIGN}"
                echo "Creating new certificate with callsign: $SUBJECT"
            fi
            
            # Create certificate request
            openssl req -new -key key.pem -out new.csr -subj "$SUBJECT"
            
            # Create extension file based on app type
            if [[ "$APP_TYPE" == "taktracker" ]]; then
                # For TAK Tracker, use only clientAuth (no serverAuth)
                cat > ext.conf << 'EOF2'
[v3_req]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = critical,clientAuth
EOF2
            else
                # For other apps, include both clientAuth and serverAuth
                cat > ext.conf << 'EOF2'
[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
EOF2
            fi
            
            # Sign the certificate with appropriate validity period
            if [[ "$APP_TYPE" == "taktracker" ]]; then
                # Use 100-year validity for TAK Tracker
                openssl x509 -req -in new.csr -CA ca.pem -CAkey ca-do-not-share.key -CAcreateserial -out fixed.pem -days 36500 -extensions v3_req -extfile ext.conf
            else
                # Standard 1-year validity for other apps
                openssl x509 -req -in new.csr -CA ca.pem -CAkey ca-do-not-share.key -CAcreateserial -out fixed.pem -days 365 -extensions v3_req -extfile ext.conf
            fi
            
            # Create new P12 file with appropriate settings for each app type
            if [[ "$APP_TYPE" == "taktracker" ]]; then
                # For TAK Tracker, don't use -name parameter to avoid setting friendlyName
                openssl pkcs12 -export -out "${CLIENT_CERT}" -inkey key.pem -in fixed.pem -legacy -passout pass:${CLIENT_PASSWORD}
            elif [[ "$APP_TYPE" == "itak" ]]; then
                # For iTAK, use legacy encryption and proper friendlyName
                openssl pkcs12 -export -out "${CLIENT_CERT}" -inkey key.pem -in fixed.pem -name "${CALLSIGN}" -legacy -passout pass:${CLIENT_PASSWORD}
            else
                # For other apps
                openssl pkcs12 -export -out "${CLIENT_CERT}" -inkey key.pem -in fixed.pem -certfile ca.pem -name "${CALLSIGN}" -passout pass:${CLIENT_PASSWORD}
            fi
            
            if [[ "$APP_TYPE" == "taktracker" ]]; then
                success "Modified client certificate with CN=${CERT_UUID}"
            else
                success "Modified client certificate with CN=${CALLSIGN}"
            fi
        fi
    fi
    
    # For iTAK, we need to handle the CA certificate specially
    if [[ "$APP_TYPE" == "itak" ]]; then
        echo "Preparing special iOS-compatible certificates..."
        
        # Extract the root CA (self-signed certificate)
        openssl pkcs12 -in "${WORK_DIR}/server.p12" -cacerts -nokeys -legacy -passin pass:${CERT_PASSWORD} -out all_ca_certs.pem
        
        # Find the root CA (where subject = issuer)
        ROOT_CA_NAME=$(grep "subject=" all_ca_certs.pem | grep -o "CN = [^ ,]*" | cut -d' ' -f3 | tail -1)
        echo "Root CA identified as: $ROOT_CA_NAME"
        
        # Extract just the root CA certificate
        openssl pkcs12 -in "${WORK_DIR}/server.p12" -cacerts -nokeys -legacy -passin pass:${CERT_PASSWORD} | \
        awk -v ca="$ROOT_CA_NAME" '
        /subject=.*CN = '"$ROOT_CA_NAME"'/ { 
            getline; 
            if (/issuer=.*CN = '"$ROOT_CA_NAME"'/) { 
                found=1; 
                print prev; 
                print $0; 
                next 
            } 
        } 
        found && /BEGIN CERTIFICATE/,/END CERTIFICATE/ { print } 
        found && /END CERTIFICATE/ { exit } 
        { prev=$0 }
        ' > root_ca_only.crt
        
        # Create CA certificate with proper friendlyName using -caname
        openssl pkcs12 -export -in root_ca_only.crt -nokeys -out tak_root_ca_final.p12 -legacy -caname "$ROOT_CA_NAME" -passout pass:${CERT_PASSWORD}
        
        # Verify the CA certificate has the friendlyName
        echo "=== Verifying Root CA Certificate ==="
        openssl pkcs12 -in tak_root_ca_final.p12 -legacy -passin pass:${CERT_PASSWORD} | grep -A 2 "Bag Attributes"
        
        # Replace server.p12 with our iOS-compatible version
        mv tak_root_ca_final.p12 server.p12
        success "Created iOS-compatible CA certificate"
    fi
else
    # For other TAK apps, create proper directory structure
    # Copy the server certificate
    if [ -f "/opt/tak/certs/files/${CERT_NAME}.p12" ]; then
        cp "/opt/tak/certs/files/${CERT_NAME}.p12" "${WORK_DIR}/certs/"
    else
        error "Certificate file /opt/tak/certs/files/${CERT_NAME}.p12 not found!"
        exit 1
    fi
    
    # Copy the truststore if available
    TRUSTSTORE_FOUND=false
    for truststore_file in truststore-TAK-ID-CA-01.p12 truststore-root.p12 truststore.p12; do
        if [ -f "/opt/tak/certs/files/${truststore_file}" ]; then
            cp "/opt/tak/certs/files/${truststore_file}" "${WORK_DIR}/certs/truststore.p12"
            success "Found truststore: ${truststore_file}, copied as truststore.p12"
            TRUSTSTORE_FOUND=true
            break
        fi
    done

    if [ "$TRUSTSTORE_FOUND" = false ]; then
        warning "No truststore found. ATAK may not connect properly without a truststore."
    fi
    
    # Extract CA certificate if available
    if [ -f "/opt/tak/certs/files/ca.pem" ]; then
        cp "/opt/tak/certs/files/ca.pem" "${WORK_DIR}/"
        success "Found CA certificate"
    else
        warning "CA certificate not found at /opt/tak/certs/files/ca.pem"
        warning "Will attempt to extract CA from the P12 file"
        # Extract CA from P12 if possible
        openssl pkcs12 -in "${WORK_DIR}/certs/${CERT_NAME}.p12" -cacerts -nokeys -chain -out "${WORK_DIR}/ca.pem" -passin pass:${CERT_PASSWORD} -legacy 2>/dev/null
    fi
fi

# Fix the certificate with proper Extended Key Usage
echo "Fixing certificate with proper Extended Key Usage..."
cd "${WORK_DIR}"

# Extract the certificate components
echo "Extracting certificate components..."
if [[ "$APP_TYPE" == "takaware" || "$APP_TYPE" == "itak" || "$APP_TYPE" == "taktracker" ]]; then
    # Fix the client certificate
    openssl pkcs12 -in "${CLIENT_CERT}" -nocerts -nodes -passin pass:${CLIENT_PASSWORD} -legacy > key.pem 2>/dev/null
    if [ $? -ne 0 ]; then
        warning "Failed to extract private key. Trying alternative passwords..."
        for alt_password in itak atakatak takaware password; do
            echo "Trying password: $alt_password"
            if openssl pkcs12 -in "${CLIENT_CERT}" -nocerts -nodes -passin pass:$alt_password -legacy > key.pem 2>/dev/null; then
                success "Password is $alt_password"
                CLIENT_PASSWORD=$alt_password
                break
            fi
        done
    fi
    # Extract certificate
    openssl pkcs12 -in "${CLIENT_CERT}" -clcerts -nokeys -passin pass:${CLIENT_PASSWORD} -legacy > cert.pem 2>/dev/null
else
    openssl pkcs12 -in "certs/${CERT_NAME}.p12" -nocerts -nodes -passin pass:${CERT_PASSWORD} -legacy > key.pem 2>/dev/null
    if [ $? -ne 0 ]; then
        warning "Failed to extract private key. Trying alternative passwords..."
        for alt_password in atakatak takaware password itak; do
            echo "Trying password: $alt_password"
            if openssl pkcs12 -in "certs/${CERT_NAME}.p12" -nocerts -nodes -passin pass:$alt_password -legacy > key.pem 2>/dev/null; then
                success "Password is $alt_password"
                CERT_PASSWORD=$alt_password
                break
            fi
        done
    fi
    # Extract certificate
    openssl pkcs12 -in "certs/${CERT_NAME}.p12" -clcerts -nokeys -passin pass:${CERT_PASSWORD} -legacy > cert.pem 2>/dev/null
fi

# For mobile apps, use a specific subject format with the callsign
if [[ "$APP_TYPE" == "takaware" || "$APP_TYPE" == "itak" || "$APP_TYPE" == "taktracker" ]]; then
    if [[ "$APP_TYPE" == "taktracker" ]]; then
        # Generate a UUID for the certificate CN if not already done
        if [ -z "$CERT_UUID" ]; then
            CERT_UUID=$(cat /proc/sys/kernel/random/uuid)
        fi
        
        # Use UUID as the CN instead of callsign
        SUBJECT="/C=US/ST=Illinois/L=Deer-Creek/O=SMD/OU=Central/CN=${CERT_UUID}"
        echo "Using UUID as CN for TAK Tracker: $SUBJECT"
        
        # Store the UUID for reference
        echo "Certificate CN (UUID): ${CERT_UUID}" > taktracker_uuid.txt
        echo "This UUID will appear in the TAK Server dashboard"
    else
        SUBJECT="/C=US/ST=Illinois/L=Deer-Creek/O=SMD/OU=Central/CN=${CALLSIGN}"
        echo "Using app-specific subject with callsign: $SUBJECT"
    fi
else
    # Get the subject from the original certificate and format it properly for OpenSSL
    ORIGINAL_SUBJECT=$(openssl x509 -in cert.pem -noout -subject | sed 's/subject= //')
    # Format the subject correctly for OpenSSL req
    SUBJECT="/C=US"
    if [[ "$ORIGINAL_SUBJECT" =~ ST\ =\ ([^,]+) ]]; then
        SUBJECT="$SUBJECT/ST=${BASH_REMATCH[1]}"
    fi
    if [[ "$ORIGINAL_SUBJECT" =~ L\ =\ ([^,]+) ]]; then
        SUBJECT="$SUBJECT/L=${BASH_REMATCH[1]}"
    fi
    if [[ "$ORIGINAL_SUBJECT" =~ O\ =\ ([^,]+) ]]; then
        SUBJECT="$SUBJECT/O=${BASH_REMATCH[1]}"
    fi
    if [[ "$ORIGINAL_SUBJECT" =~ OU\ =\ ([^,]+) ]]; then
        SUBJECT="$SUBJECT/OU=${BASH_REMATCH[1]}"
    fi
    if [[ "$ORIGINAL_SUBJECT" =~ CN\ =\ ([^,]+) ]]; then
        SUBJECT="$SUBJECT/CN=${CALLSIGN}" # Use provided callsign instead of original CN
    else
        SUBJECT="$SUBJECT/CN=${CALLSIGN}" # Add callsign as CN if not present
    fi
    echo "Certificate subject: $SUBJECT"
fi

# Create extension file based on app type
if [[ "$APP_TYPE" == "taktracker" ]]; then
    # For TAK Tracker, use only clientAuth (no serverAuth)
    cat > ext.conf << 'EOF2'
[v3_req]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = critical,clientAuth
EOF2
else
    # For other apps, include both clientAuth and serverAuth
    cat > ext.conf << 'EOF2'
[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth, serverAuth
EOF2
fi

# Create certificate request
openssl req -new -key key.pem -out new.csr -subj "$SUBJECT"

# Sign with Extended Key Usage
if [ -f "ca.pem" ]; then
    # Check if we have CA key
    if [ -f "ca-do-not-share.key" ]; then
        if [[ "$APP_TYPE" == "taktracker" ]]; then
            # Use 100-year validity for TAK Tracker
            openssl x509 -req -in new.csr -CA ca.pem -CAkey ca-do-not-share.key -CAcreateserial -out fixed.pem -days 36500 -extensions v3_req -extfile ext.conf
        else
            # Standard 1-year validity for other apps
            openssl x509 -req -in new.csr -CA ca.pem -CAkey ca-do-not-share.key -CAcreateserial -out fixed.pem -days 365 -extensions v3_req -extfile ext.conf
        fi
        if [ $? -ne 0 ]; then
            error "Failed to sign certificate. Using original certificate instead."
            cp cert.pem fixed.pem
        fi
    else
        warning "CA private key not found. Cannot sign certificate."
        warning "Using original certificate instead."
        cp cert.pem fixed.pem
    fi
else
    warning "CA certificate not found. Using original certificate."
    cp cert.pem fixed.pem
fi

# Verify the fix
echo "=== Verifying Fixed Certificate ==="
openssl x509 -in fixed.pem -text -noout | grep -A 3 "Extended Key Usage" || warning "No Extended Key Usage found"
echo "=== Verifying Subject ==="
openssl x509 -in fixed.pem -noout -subject || warning "Could not verify subject"

# Create new P12 with fixed certificate
# For mobile apps, use the callsign as the name in the P12
if [[ "$APP_TYPE" == "takaware" || "$APP_TYPE" == "itak" || "$APP_TYPE" == "taktracker" ]]; then
    if [[ "$APP_TYPE" == "taktracker" ]]; then
        # For TAK Tracker, don't use -name parameter to avoid setting friendlyName
        openssl pkcs12 -export -out "${CLIENT_CERT}" -inkey key.pem -in fixed.pem -legacy -passout pass:${CLIENT_PASSWORD}
    elif [[ "$APP_TYPE" == "itak" ]]; then
        # For iTAK, use legacy encryption and proper friendlyName
        openssl pkcs12 -export -out "${CLIENT_CERT}" -inkey key.pem -in fixed.pem -name "${CALLSIGN}" -legacy -passout pass:${CLIENT_PASSWORD}
    else
        # For other mobile apps
        openssl pkcs12 -export -out "${CLIENT_CERT}" -inkey key.pem -in fixed.pem -certfile ca.pem -name "${CALLSIGN}" -passout pass:${CLIENT_PASSWORD}
    fi
else
    openssl pkcs12 -export -out "certs/${CERT_NAME}.p12" -inkey key.pem -in fixed.pem -certfile ca.pem -name "${CALLSIGN}" -passout pass:${CERT_PASSWORD}
fi

if [ $? -ne 0 ]; then
    error "Failed to create P12 file"
    exit 1
fi

# Verify the P12 has Extended Key Usage
echo "=== Verifying P12 Certificate ==="
if [[ "$APP_TYPE" == "takaware" || "$APP_TYPE" == "itak" || "$APP_TYPE" == "taktracker" ]]; then
    openssl pkcs12 -in "${CLIENT_CERT}" -nokeys -passin pass:${CLIENT_PASSWORD} -legacy | openssl x509 -text -noout | grep -A 3 "Extended Key Usage" || warning "No Extended Key Usage found in P12"
else
    openssl pkcs12 -in "certs/${CERT_NAME}.p12" -nokeys -passin pass:${CERT_PASSWORD} -legacy | openssl x509 -text -noout | grep -A 3 "Extended Key Usage" || warning "No Extended Key Usage found in P12"
fi

# Create manifest and config files based on app type
if [[ "$APP_TYPE" == "takaware" || "$APP_TYPE" == "itak" || "$APP_TYPE" == "taktracker" ]]; then
    echo "Creating manifest.xml for ${APP_TYPE}..."
    cat > manifest.xml << EOF2
<?xml version="1.0" encoding="UTF-8"?>
<MissionPackageManifest version="2">
  <Configuration>
    <Parameter name="uid" value="${UUID}"/>
    <Parameter name="name" value="${APP_TYPE}_${SERVER_IP}.zip"/>
    <Parameter name="onReceiveDelete" value="true"/>
  </Configuration>
  <Contents>
    <Content ignore="false" zipEntry="${CLIENT_CERT_FILENAME}"/>
    <Content ignore="false" zipEntry="server.p12"/>
    <Content ignore="false" zipEntry="defaults.pref"/>
  </Contents>
</MissionPackageManifest>
EOF2

    echo "Creating defaults.pref for ${APP_TYPE}..."
    
    if [[ "$APP_TYPE" == "taktracker" ]]; then
        # Special configuration for TAK Tracker
        cat > defaults.pref << EOF2
<?xml version='1.0' encoding='ASCII' standalone='yes'?>
<preferences>
  <preference version="1" name="cot_streams">
    <entry key="count" class="class java.lang.Integer">1</entry>
    <entry key="enabled0" class="class java.lang.Boolean">true</entry>
    <entry key="connectString0" class="class java.lang.String">${SERVER_IP}:${PORT}:ssl</entry>
    <entry key="useAuth0" class="class java.lang.Boolean">false</entry>
    <entry key="description0" class="class java.lang.String">Your TAK Server</entry>
  </preference>
  <preference version="1" name="com.atakmap.app_preferences">
    <entry key="clientPassword" class="class java.lang.String">${CLIENT_PASSWORD}</entry>
    <entry key="caPassword" class="class java.lang.String">${CERT_PASSWORD}</entry>
    <entry key="caLocation" class="class java.lang.String">server.p12</entry>
    <entry key="certificateLocation" class="class java.lang.String">${CLIENT_CERT_FILENAME}</entry>
    <entry key="displayServerConnectionWidget" class="class java.lang.Boolean">true</entry>
    <entry key="locationCallsign" class="class java.lang.String">${CALLSIGN}</entry>
    <entry key="locationTeam" class="class java.lang.String">${TEAM}</entry>
    <entry key="takTracker.enabled" class="class java.lang.Boolean">true</entry>
    <entry key="takTracker.reportingInterval" class="class java.lang.Integer">30</entry>
    <entry key="takTracker.minimumDisplacement" class="class java.lang.Integer">10</entry>
  </preference>
</preferences>
EOF2
    elif [[ "$APP_TYPE" == "itak" ]]; then
        # Special configuration for iTAK with iOS-compatible settings
        cat > defaults.pref << EOF2
<?xml version='1.0' encoding='ASCII' standalone='yes'?>
<preferences>
  <preference version="1" name="cot_streams">
    <entry key="count" class="class java.lang.Integer">1</entry>
    <entry key="enabled0" class="class java.lang.Boolean">true</entry>
    <entry key="connectString0" class="class java.lang.String">${SERVER_IP}:${PORT}:ssl</entry>
    <entry key="useAuth0" class="class java.lang.Boolean">false</entry>
    <entry key="description0" class="class java.lang.String">Your TAK Server</entry>
  </preference>
  <preference version="1" name="com.atakmap.app_preferences">
    <entry key="clientPassword" class="class java.lang.String">${CLIENT_PASSWORD}</entry>
    <entry key="caPassword" class="class java.lang.String">${CERT_PASSWORD}</entry>
    <entry key="caLocation" class="class java.lang.String">server.p12</entry>
    <entry key="certificateLocation" class="class java.lang.String">${CLIENT_CERT_FILENAME}</entry>
    <entry key="displayServerConnectionWidget" class="class java.lang.Boolean">true</entry>
    <entry key="locationCallsign" class="class java.lang.String">${CALLSIGN}</entry>
    <entry key="locationTeam" class="class java.lang.String">${TEAM}</entry>
  </preference>
</preferences>
EOF2
    else
        # Standard configuration for other mobile apps
        cat > defaults.pref << EOF2
<?xml version='1.0' encoding='ASCII' standalone='yes'?>
<preferences>
  <preference version="1" name="cot_streams">
    <entry key="count" class="class java.lang.Integer">1</entry>
    <entry key="enabled0" class="class java.lang.Boolean">true</entry>
    <entry key="connectString0" class="class java.lang.String">${SERVER_IP}:${PORT}:ssl</entry>
    <entry key="useAuth0" class="class java.lang.Boolean">false</entry>
    <entry key="description0" class="class java.lang.String">Your TAK Server</entry>
  </preference>
  <preference version="1" name="com.atakmap.app_preferences">
    <entry key="clientPassword" class="class java.lang.String">${CLIENT_PASSWORD}</entry>
    <entry key="caPassword" class="class java.lang.String">${CERT_PASSWORD}</entry>
    <entry key="caLocation" class="class java.lang.String">server.p12</entry>
    <entry key="certificateLocation" class="class java.lang.String">${CLIENT_CERT_FILENAME}</entry>
    <entry key="displayServerConnectionWidget" class="class java.lang.Boolean">true</entry>
    <entry key="locationCallsign" class="class java.lang.String">${CALLSIGN}</entry>
    <entry key="locationTeam" class="class java.lang.String">${TEAM}</entry>
  </preference>
</preferences>
EOF2
    fi
else
    echo "Creating manifest.xml..."
    cat > MANIFEST/manifest.xml << EOF2
<MissionPackageManifest version="2">
  <Configuration>
    <Parameter name="uid" value="${UUID}"/>
    <Parameter name="name" value="TAK_Server_${SERVER_IP}.zip"/>
    <Parameter name="onReceiveDelete" value="true"/>
  </Configuration>
  <Contents>
    <Content ignore="false" zipEntry="certs/config.pref"/>
    <Content ignore="false" zipEntry="certs/${CERT_NAME}.p12"/>
EOF2

    # Add truststore to manifest if available
    if [ -f "certs/truststore.p12" ]; then
        cat >> MANIFEST/manifest.xml << EOF2
    <Content ignore="false" zipEntry="certs/truststore.p12"/>
EOF2
    fi

    cat >> MANIFEST/manifest.xml << EOF2
  </Contents>
</MissionPackageManifest>
EOF2

    echo "Creating config.pref..."
    cat > certs/config.pref << EOF2
<?xml version='1.0' encoding='ASCII' standalone='yes'?>
<preferences>
  <preference version="1" name="cot_streams">
    <entry key="count" class="class java.lang.Integer">1</entry>
    <entry key="description0" class="class java.lang.String">TAK Server</entry>
    <entry key="enabled0" class="class java.lang.Boolean">true</entry>
    <entry key="connectString0" class="class java.lang.String">${SERVER_IP}:${PORT}:ssl</entry>
    <entry key="caLocation0" class="class java.lang.String">cert/${CERT_NAME}.p12</entry>
    <entry key="caPassword0" class="class java.lang.String">${CERT_PASSWORD}</entry>
EOF2

    # Add truststore to config if available
    if [ -f "certs/truststore.p12" ]; then
        cat >> certs/config.pref << EOF2
    <entry key="trustStoreLocation0" class="class java.lang.String">cert/truststore.p12</entry>
    <entry key="trustStorePassword0" class="class java.lang.String">atakatak</entry>
EOF2
    fi

    cat >> certs/config.pref << EOF2
    <entry key="enrollForCertificateWithTrust0" class="class java.lang.Boolean">true</entry>
    <entry key="useAuth0" class="class java.lang.Boolean">true</entry>
    <entry key="cacheCreds0" class="class java.lang.String">Cache credentials</entry>
  </preference>
  <preference version="1" name="com.atakmap.app_preferences">
    <entry key="displayServerConnectionWidget" class="class java.lang.Boolean">true</entry>
    <entry key="locationCallsign" class="class java.lang.String">${CALLSIGN}</entry>
    <entry key="locationTeam" class="class java.lang.String">${TEAM}</entry>
    <entry key="atakRoleType" class="class java.lang.String">${ROLE}</entry>
  </preference>
</preferences>
EOF2
fi

# Create zip
echo "Creating zip file..."

if [[ "$APP_TYPE" == "takaware" || "$APP_TYPE" == "itak" || "$APP_TYPE" == "taktracker" ]]; then
    OUTPUT_FILE="/tmp/${APP_TYPE}_${SERVER_IP}_${CALLSIGN}.zip"
    
    echo "Creating ${APP_TYPE} package at: ${OUTPUT_FILE}"
    
    # Create zip directly from the working directory
    zip -r "${OUTPUT_FILE}" manifest.xml defaults.pref ${CLIENT_CERT_FILENAME} server.p12
    
    # Check if zip was created
    if [ -f "${OUTPUT_FILE}" ]; then
        echo "Zip file created successfully at: ${OUTPUT_FILE}"
    else
        error "Failed to create zip file at: ${OUTPUT_FILE}"
    fi
else
    OUTPUT_FILE="/tmp/tak_server_${SERVER_IP}_${CALLSIGN}.zip"
    echo "Creating TAK server package at: ${OUTPUT_FILE}"
    
    # Create zip directly from the working directory
    zip -r "${OUTPUT_FILE}" MANIFEST certs
    
    # Check if zip was created
    if [ -f "${OUTPUT_FILE}" ]; then
        echo "Zip file created successfully at: ${OUTPUT_FILE}"
    else
        error "Failed to create zip file at: ${OUTPUT_FILE}"
    fi
fi

# Verify zip contents
if [ -f "${OUTPUT_FILE}" ]; then
    echo "Verifying zip contents:"
    unzip -l "${OUTPUT_FILE}"
    
    # Check for temporary files in the zip
    if unzip -l "${OUTPUT_FILE}" | grep -q -E 'ca\.pem|cert\.pem|key\.pem|new\.csr|ext\.conf|fixed\.pem'; then
        warning "Temporary files detected in the zip. This may indicate an issue with the packaging process."
    else
        success "Zip file verified - contains only the required files."
    fi
fi

# Clean up
cd /
rm -rf "${WORK_DIR}"

# Final check for the zip file
if [ -f "/tmp/${APP_TYPE}_${SERVER_IP}_${CALLSIGN}.zip" ] || [ -f "/tmp/tak_server_${SERVER_IP}_${CALLSIGN}.zip" ]; then
    success "Package created successfully"
    if [[ "$APP_TYPE" == "takaware" || "$APP_TYPE" == "itak" || "$APP_TYPE" == "taktracker" ]]; then
        echo "File: /tmp/${APP_TYPE}_${SERVER_IP}_${CALLSIGN}.zip"
        
        # For TAK Tracker, show the UUID that will appear in the dashboard
        if [[ "$APP_TYPE" == "taktracker" && -n "$CERT_UUID" ]]; then
            echo "TAK Tracker UUID: ${CERT_UUID}"
            echo "This UUID will appear in the TAK Server dashboard instead of the callsign"
        fi
    else
        echo "File: /tmp/tak_server_${SERVER_IP}_${CALLSIGN}.zip"
        # For ATAK/WinTAK, set CLIENT_PASSWORD to be the same as CERT_PASSWORD if not already set
        CLIENT_PASSWORD=${CLIENT_PASSWORD:-${CERT_PASSWORD}}
    fi
    echo "Certificate password: ${CERT_PASSWORD}"
    echo "Client certificate password: ${CLIENT_PASSWORD}"
    echo "Callsign: ${CALLSIGN}"
    echo "To make it available for download, run:"
    echo "python3 -m http.server 8000"
else
    error "Package creation failed. Zip file not found."
fi
