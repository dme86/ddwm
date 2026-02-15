#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

./script/check-uncommitted-files.sh

./build-debug.sh -Xswiftc -warnings-as-errors
./run-swift-test.sh

./.debug/ddwm -h > /dev/null
./.debug/ddwm --help > /dev/null
./.debug/ddwm -v | grep -q "0.0.0-SNAPSHOT SNAPSHOT"
./.debug/ddwm --version | grep -q "0.0.0-SNAPSHOT SNAPSHOT"

./format.sh --check-uncommitted-files

generate_args=()
has_java_runtime=0
if command -v java > /dev/null 2>&1; then
    if [[ -x /usr/libexec/java_home ]]; then
        /usr/libexec/java_home > /dev/null 2>&1 && has_java_runtime=1
    else
        java -version > /dev/null 2>&1 && has_java_runtime=1
    fi
fi
if test $has_java_runtime -eq 0; then
    echo "warning: Skipping shell parser generation (Java runtime unavailable)" > /dev/stderr
    generate_args+=(--ignore-shell-parser)
fi
if [[ "$(/usr/bin/xcode-select -p 2>/dev/null || true)" == *"CommandLineTools"* ]]; then
    echo "warning: Skipping xcodeproj generation (full Xcode unavailable)" > /dev/stderr
    generate_args+=(--ignore-xcodeproj)
fi
./generate.sh "${generate_args[@]}"
./script/check-uncommitted-files.sh

echo
echo "✅ All tests have passed successfully"
