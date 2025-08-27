#!/bin/bash
# script_manager.sh - Manage TAK scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/tak_functions.sh"

case "$1" in
    "list")
        echo "Available scripts:"
        find "$SCRIPT_DIR/tak" -name "*.sh" | sort
        ;;
    "run")
        if [ -f "$SCRIPT_DIR/tak/$2" ]; then
            shift
            "$SCRIPT_DIR/tak/$@"
        elif [ -f "$SCRIPT_DIR/tak/$2.sh" ]; then
            shift
            "$SCRIPT_DIR/tak/$1.sh" "${@:2}"
        else
            echo "Script not found: $2"
            echo "Available scripts:"
            find "$SCRIPT_DIR/tak" -name "*.sh" | sort
        fi
        ;;
    "doc")
        if [ -f "$SCRIPT_DIR/documentation/$2.md" ]; then
            cat "$SCRIPT_DIR/documentation/$2.md"
        elif [ -f "$SCRIPT_DIR/documentation/$2" ]; then
            cat "$SCRIPT_DIR/documentation/$2"
        else
            echo "Documentation not found: $2"
            echo "Available documentation:"
            find "$SCRIPT_DIR/documentation" -name "*.md" | sort
        fi
        ;;
    "config")
        if [ "$2" = "list" ]; then
            echo "Available configurations:"
            find "$SCRIPT_DIR/configs" -name "*.conf" | sort
        elif [ -f "$SCRIPT_DIR/configs/$2.conf" ]; then
            cat "$SCRIPT_DIR/configs/$2.conf"
        else
            echo "Configuration not found: $2"
            echo "Available configurations:"
            find "$SCRIPT_DIR/configs" -name "*.conf" | sort
        fi
        ;;
    "install")
        if [ -n "$2" ] && [ -f "$SCRIPT_DIR/tak/$2" ]; then
            sudo ln -sf "$SCRIPT_DIR/tak/$2" "/usr/local/bin/$(basename "$2" .sh)"
            success "Installed $2 to /usr/local/bin/$(basename "$2" .sh)"
        elif [ -n "$2" ] && [ -f "$SCRIPT_DIR/tak/$2.sh" ]; then
            sudo ln -sf "$SCRIPT_DIR/tak/$2.sh" "/usr/local/bin/$2"
            success "Installed $2.sh to /usr/local/bin/$2"
        else
            error "Script not found: $2"
            echo "Available scripts:"
            find "$SCRIPT_DIR/tak" -name "*.sh" | sort
        fi
        ;;
    "uninstall")
        if [ -n "$2" ] && [ -L "/usr/local/bin/$2" ]; then
            sudo rm "/usr/local/bin/$2"
            success "Uninstalled $2 from /usr/local/bin"
        else
            error "Symlink not found: /usr/local/bin/$2"
        fi
        ;;
    "installed")
        echo "Installed scripts:"
        find /usr/local/bin -type l -exec ls -la {} \; | grep "$SCRIPT_DIR"
        ;;
    *)
        echo "TAK Script Manager"
        echo "Usage: $0 [command] [arguments]"
        echo ""
        echo "Commands:"
        echo "  list              List all available scripts"
        echo "  run [script] [args]  Run a script with arguments"
        echo "  doc [name]        Show documentation for a script"
        echo "  config list       List all available configurations"
        echo "  config [name]     Show a specific configuration"
        echo "  install [script]  Create symlink in /usr/local/bin"
        echo "  uninstall [name]  Remove symlink from /usr/local/bin"
        echo "  installed         List all installed scripts"
        ;;
esac

    "new")
        if [ -n "$2" ]; then
            cp "$SCRIPT_DIR/template.sh" "$SCRIPT_DIR/tak/$2.sh"
            chmod +x "$SCRIPT_DIR/tak/$2.sh"
            echo "# $2 Script" > "$SCRIPT_DIR/documentation/$2.md"
            echo "" >> "$SCRIPT_DIR/documentation/$2.md"
            echo "## Purpose" >> "$SCRIPT_DIR/documentation/$2.md"
            echo "Description of what the script does" >> "$SCRIPT_DIR/documentation/$2.md"
            success "Created new script: $SCRIPT_DIR/tak/$2.sh"
            success "Created documentation: $SCRIPT_DIR/documentation/$2.md"
        else
            error "Usage: $0 new <script_name>"
        fi
        ;;
