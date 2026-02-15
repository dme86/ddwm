#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

if [[ "$(/usr/bin/xcode-select -p 2>/dev/null || true)" == *"CommandLineTools"* ]]; then
    echo "warning: Skipping swift test (XCTest unavailable without full Xcode)" > /dev/stderr
    exit 0
fi

if swift test; then
    echo "✅ Swift tests have passed successfully"
else
    echo "❌ Swift tests have failed"
    exit 1
fi
