#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

rebuild=1
while test $# -gt 0; do
    case $1 in
        --dont-rebuild) rebuild=0; shift ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

if test $rebuild == 1; then
    ./build-release.sh
fi

install_root="${HOME}/.local/ddwm"
rm -rf "$install_root"
mkdir -p "$install_root/bin"

cp -R ./.release/ddwm.app "$install_root/ddwm.app"
cp ./.release/ddwm "$install_root/bin/ddwm"

echo "Installed artifacts to: $install_root"
echo "Add \$HOME/.local/ddwm/bin to your PATH if you want to run 'ddwm' directly."
