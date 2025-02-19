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
                fixsunxi
            fi
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
    src="/tmp/overlay/02-smartpad-rotate-screen.conf"
    dest="/etc/X11/xorg.conf.d/"
    echo "Install rotated screen configuration ..."
    cp -v "${src}" "${dest}"
    echo "DEBUG:"
    ls -l "${dest}"
    echo "Install rotated screen configuration ... [DONE]"
}

rotateTouch() {
    src="/tmp/overlay/03-smartpad-rotate-touch.conf"
    dest="/etc/X11/xorg.conf.d/"
    echo "Install rotated touch configuration ..."
    cp -v "${src}" "${dest}"
    echo "DEBUG:"
    ls -l "${dest}"
    echo "Install rotated touch configuration ... [DONE]"
}

disableDPMS() {
    src="/tmp/overlay/04-smartpad-disable-dpms.conf"
    dest="/etc/X11/xorg.conf.d/"
    echo "Install rotated touch configuration ..."
    cp -v "${src}" "${dest}"
    echo "DEBUG:"
    ls -l "${dest}"
    echo "Install rotated touch configuration ... [DONE]"
}

patchLightdm() {
    local conf
    conf="/etc/lightdm/lightdm.conf.d/12-onboard.conf"
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
    local conf
    conf="/etc/xdg/autostart/onboard-autostart.desktop"
    echo "Patch Onboard Autostart file ..."
    sed -i '/OnlyShowIn/s/^/# /' "${conf}"
    echo "Patch Onboard Autostart file ... [DONE]"
}

installScreensaverSetup() {
    src="/tmp/overlay/skel-xscreensaver"
    dest="/etc/skel/.xscreensaver"
    echo "Install rotated touch configuration ..."
    \cp -fv "${src}" "${dest}"
    echo "DEBUG:"
    ls -al "$(dirname ${dest})"
    echo "Install rotated touch configuration ... [DONE]"
}

fixsunxi() {
    echo "Fix sunxi ..."
        # Définir la version souhaitée du kernel
        TARGET_KERNEL="6.6.16-current-sunxi"

        # Récupérer la version actuelle du kernel
        CURRENT_KERNEL=$(uname -r)

        echo "Vérification de la version actuelle du kernel..."
        echo "Kernel actuel : $CURRENT_KERNEL"
        echo "Kernel souhaité : $TARGET_KERNEL"

        if [ "$CURRENT_KERNEL" != "$TARGET_KERNEL" ]; then
            echo "Le kernel actuel ne correspond pas. Correction en cours..."
            
            # Supprimer les headers et le kernel actuels s'ils sont incorrects
            sudo apt remove --purge -y linux-image-current-sunxi linux-headers-current-sunxi linux-libc-dev
            
            # Réinstaller la bonne version
            sudo apt install -y linux-image-current-sunxi=24.2.1 linux-headers-current-sunxi=24.2.1
            
            # Mettre à jour GRUB
            echo "Mise à jour de GRUB..."
            sudo update-grub
            
            echo "Redémarrage du système..."
            sudo reboot
        else
            echo "Le kernel est déjà correct. Blocage des mises à jour..."
            
            # Bloquer la mise à jour du kernel et des headers
            sudo apt-mark hold linux-image-current-sunxi linux-headers-current-sunxi linux-libc-dev
            
            # Empêcher les mises à jour avec un fichier de préférences
            echo "Création du fichier de préférences APT..."
            sudo bash -c 'cat <<EOF > /etc/apt/preferences.d/no-kernel-upgrade
        Package: linux-image-*
        Pin: release *
        Pin-Priority: -1

        Package: linux-headers-*
        Pin: release *
        Pin-Priority: -1

        Package: linux-libc-dev
        Pin: release *
        Pin-Priority: -1
        EOF'

            echo "Le kernel est maintenant verrouillé et ne sera plus mis à jour."
        fi

    echo "Fix sunxi ... [DONE]"
}

Main "S{@}"
