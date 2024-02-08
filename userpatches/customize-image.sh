#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot
# The sd card's root path is accessible via $SDCARD variable.

# shellcheck enable=requires-variable-braces
# shellcheck disable=SC2034

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

Main() {
    case "${BOARD}" in
        smartpad)
            rotateConsole
            rotateScreen
            rotateTouch
            ;;
    esac
}

rotateConsole() {
    local bootcfg
    bootcfg="/boot/armbianEnv.txt"
    echo "Rotate tty console by default ..."
    echo "extraargs=fbcon=rotate:2" >> "${bootcfg}"
    echo "Current configuration (${bootcfg}):"
    cat "${bootcfg}"
    echo "Rotate tty console by default ... done!"
}

rotateScreen() {
    file="/etc/X11/xorg.conf.d/02-smartpad-rotated.conf"
    echo "Rotate Monitor by default ..."
    echo "Create ${file} ..."
    cat << EOF > "${file}"
Section "Monitor"
    Identifier "HDMI-1"
    Option "Rotate" "inverted"
EndSection
EOF
    echo "File contents:"
    cat "${file}"
}

rotateTouch() {
    file="/etc/X11/xorg.conf.d/99-Touch-rotated.conf"
    echo "Rotate Touch by default ..."
    echo "Create ${file} ..."
    cat << EOF > "${file}"
Section "InputClass"
    Identifier "evdev touchscreen catchall"
    MatchIsTouchscreen "on"
    MatchDevicePath "/dev/input/event*"
    Driver "evdev"
    Option "CalibrationMatrix" "-1 0 1 0 -1 1 0 0 1"
EndSection
EOF
    echo "File contents:"
    cat "${file}"
}

Main "S{@}"
