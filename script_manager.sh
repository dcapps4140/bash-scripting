#!/bin/bash
# script_manager.sh - Manage TAK scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    "save")
        if [ -n "$2" ]; then
            cp "$2" "$SCRIPT_DIR/tak/"
            echo "Script saved to $SCRIPT_DIR/tak/$(basename "$2")"
            chmod +x "$SCRIPT_DIR/tak/$(basename "$2")"
        else
            echo "Usage: $0 save /path/to/script.sh"
        fi
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
        echo "  save [path]       Save an external script to the repository"
        ;;
esac
