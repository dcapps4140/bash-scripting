#!/bin/bash
# Script to backup the entire scripts repository

BACKUP_DIR=~/backups
BACKUP_FILE="scripts_backup_$(date +%Y%m%d).tar.gz"

mkdir -p $BACKUP_DIR
tar -czf "$BACKUP_DIR/$BACKUP_FILE" -C ~ scripts

echo "Backup created: $BACKUP_DIR/$BACKUP_FILE"
