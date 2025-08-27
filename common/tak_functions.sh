#!/bin/bash
# Common functions for TAK scripts

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

# Certificate handling functions
extract_certificate() {
    local cert_file=$1
    local password=$2
    local output_file=$3
    
    openssl pkcs12 -in "$cert_file" -clcerts -nokeys -legacy -passin pass:"$password" -out "$output_file"
    return $?
}

extract_private_key() {
    local cert_file=$1
    local password=$2
    local output_file=$3
    
    openssl pkcs12 -in "$cert_file" -nocerts -nodes -legacy -passin pass:"$password" -out "$output_file"
    return $?
}

# Configuration functions
load_config() {
    local config_file=$1
    if [ -f "$config_file" ]; then
        source "$config_file"
        return 0
    else
        error "Config file not found: $config_file"
        return 1
    fi
}

# Validation functions
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        error "Invalid IP address: $ip"
        return 1
    fi
}
