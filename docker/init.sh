#!/bin/bash
# Custom initialization script for Contrast agent

set -e

echo "Starting Contrast agent initialization..."
echo "Contrast agent version: $(java -jar /contrast/contrast-agent.jar --version 2>/dev/null || echo 'unknown')"

# Default paths
SOURCE_PATH="${CONTRAST_SOURCE_PATH:-/contrast/contrast-agent.jar}"
DEST_PATH="${CONTRAST_DEST_PATH:-/mnt/contrast/contrast.jar}"

# Ensure destination directory exists
DEST_DIR=$(dirname "$DEST_PATH")
if [ ! -d "$DEST_DIR" ]; then
    echo "Error: Destination directory $DEST_DIR does not exist"
    exit 1
fi

# Copy the agent JAR
echo "Copying Contrast agent from $SOURCE_PATH to $DEST_PATH"
cp -v "$SOURCE_PATH" "$DEST_PATH"

# Verify the copy was successful
if [ -f "$DEST_PATH" ]; then
    echo "Contrast agent copied successfully"
    ls -la "$DEST_PATH"
else
    echo "Error: Failed to copy Contrast agent"
    exit 1
fi

# Optional: Copy any additional configuration files
if [ -n "$CONTRAST_CONFIG_PATH" ] && [ -f "$CONTRAST_CONFIG_PATH" ]; then
    echo "Copying additional configuration from $CONTRAST_CONFIG_PATH"
    cp -v "$CONTRAST_CONFIG_PATH" "$DEST_DIR/"
fi

echo "Contrast agent initialization completed successfully"
