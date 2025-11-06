#!/usr/bin/env bash
set -e

echo "Building Docker image: kea-custom"

# Build Docker image and save output to log file
if ! docker build -t kea-custom . > build.log 2>&1; then
  echo
  echo "Build failed. Check build.log for details."
  exit 1
fi

echo
echo "Build completed successfully."
echo "Log saved to build.log"
