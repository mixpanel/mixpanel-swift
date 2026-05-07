#!/bin/sh
set -e

echo "🧹 Running Apple swift-format"

#how to use
#Format specific files - sh ./scripts/format-swift.sh Sources/MyFile.swift
#Format all files - ./scripts/format-swift.sh

# Ensure swift-format exists
if ! command -v swift-format >/dev/null 2>&1; then
  echo "❌ swift-format not found."
  echo "Install with: brew install swift-format"
  exit 1
fi

# Ensure config exists
if [ ! -f ".swift-format" ]; then
  echo "❌ .swift-format config file not found at repo root."
  exit 1
fi

# If no arguments are passed, format the entire repo
if [ "$#" -eq 0 ]; then
  echo "→ Formatting entire repo"
  swift-format format --recursive --configuration .swift-format --in-place .
  echo "✅ Formatting complete"
  exit 0
fi

# Format only provided files/directories
echo "→ Formatting specified paths: $*"

swift-format format \
  --recursive \
  --configuration .swift-format \
  --in-place \
  "$@"

echo "✅ Formatting complete"
