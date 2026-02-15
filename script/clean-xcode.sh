#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

./script/check-uncommitted-files.sh

rm -rf ~/Library/Developer/Xcode/DerivedData/ddwm-*
rm -rf ./.xcode-build

rm -rf ddwm.xcodeproj
./script/dev.sh generate
