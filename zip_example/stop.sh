#!/bin/sh

# 1. Kill the main loop script
echo "Stopping TRMNL.sh..."
pkill -f "TRMNL.sh"

# Clearing the screen for a fresh start
eips -c
eips -f

echo "TRMNL stopped..."