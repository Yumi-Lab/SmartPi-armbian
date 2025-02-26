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
            disableDPMS
            if [[ "${BUILD_DESKTOP}" = "yes" ]]; then
                patchLightdm
                copyOnboardConf
                patchOnboardAutostart
                installScreensaverSetup
            fi
            if [[ "${RELEASE}" = "bookworm" ]]; then
                #fixsunxi
                echo "release bookworm"
            fi
            ;;
    esac
}

rotateConsole() {
    local bootcfg="/boot/armbianEnv.txt"
    echo "Rotate tty console by default ..."
    echo "extraargs=fbcon=rotate:2" >> "${bootcfg}"
    echo "Current configuration (${bootcfg}):"
    cat "${bootcfg}"
    echo "Rotate tty console by default ... done!"
}

rotateScreen() {
    local src="/tmp/overlay/02-smartpad-rotate-screen.conf"
    local dest="/etc/X11/xorg.conf.d/"
    echo "Install rotated screen configuration ..."
    cp -v "${src}" "${dest}"
    echo "DEBUG:"
    ls -l "${dest}"
    echo "Install rotated screen configuration ... [DONE]"
}

rotateTouch() {
    local src="/tmp/overlay/03-smartpad-rotate-touch.conf"
    local dest="/etc/X11/xorg.conf.d/"
    echo "Install rotated touch configuration ..."
    cp -v "${src}" "${dest}"
    echo "DEBUG:"
    ls -l "${dest}"
    echo "Install rotated touch configuration ... [DONE]"
}

disableDPMS() {
    local src="/tmp/overlay/04-smartpad-disable-dpms.conf"
    local dest="/etc/X11/xorg.conf.d/"
    echo "Disable DPMS power management ..."
    cp -v "${src}" "${dest}"
    echo "DEBUG:"
    ls -l "${dest}"
    echo "Disable DPMS power management ... [DONE]"
}

patchLightdm() {
    local conf="/etc/lightdm/lightdm.conf.d/12-onboard.conf"
    echo "Enable OnScreen Keyboard in Lightdm ..."
    echo "onscreen-keyboard = true" | tee "${conf}"
    echo "Enable OnScreen Keyboard in Lightdm ... [DONE]"
}

copyOnboardConf() {
    echo "Copy onboard default configuration ..."
    mkdir -p /etc/onboard
    cp -v /tmp/overlay/onboard-defaults.conf /etc/onboard/
    echo "Copy onboard default configuration ... [DONE]"
}

patchOnboardAutostart() {
    local conf="/etc/xdg/autostart/onboard-autostart.desktop"
    echo "Patch Onboard Autostart file ..."
    sed -i '/OnlyShowIn/s/^/# /' "${conf}"
    echo "Patch Onboard Autostart file ... [DONE]"
}

installScreensaverSetup() {
    local src="/tmp/overlay/skel-xscreensaver"
    local dest="/etc/skel/.xscreensaver"
    echo "Install screensaver configuration ..."
    \cp -fv "${src}" "${dest}"
    echo "DEBUG:"
    ls -al "$(dirname "${dest}")"
    echo "Install screensaver configuration ... [DONE]"
}

fixsunxi() {
    echo "Fix sunxi ..."

    mkdir -p /opt/kernel_deb
    mkdir -p /opt/armbian_config

    GITHUB_REPO="https://raw.githubusercontent.com/Yumi-Lab/SmartPi-armbian/develop/userpatches/header"

    echo "📥 Téléchargement des fichiers kernel..."
    curl -L -o /opt/kernel_deb/linux-image-current-sunxi.deb "$GITHUB_REPO/linux-image-current-sunxi_24.2.1_armhf.deb"
    curl -L -o /opt/kernel_deb/linux-headers-current-sunxi.deb "$GITHUB_REPO/linux-headers-current-sunxi_24.2.1_armhf.deb"

    echo "📥 Téléchargement de `armbian-config` 24.5.5..."
    wget -O /opt/armbian_config/armbian-config_24.5.5_all.deb "http://imola.armbian.com/apt/pool/main/a/armbian-config/armbian-config_24.5.5_all__1-SA5703-B9a9b-R448a.deb"

    if [[ ! -f /opt/kernel_deb/linux-image-current-sunxi.deb || ! -f /opt/kernel_deb/linux-headers-current-sunxi.deb ]]; then
        echo "❌ Erreur : Impossible de télécharger les fichiers kernel."
        exit 1
    fi

    if [[ ! -f /opt/armbian_config/armbian-config_24.5.5_all.deb ]]; then
        echo "❌ Erreur : Impossible de télécharger `armbian-config`."
        exit 1
    fi

    echo "✅ Tous les fichiers nécessaires sont prêts pour le premier démarrage."

    echo "Fix sunxi ... [DONE]"
}

Main "$@"
