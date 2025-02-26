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


sudo apt update && sudo apt install -y armbian-config wireless-tools wpasupplicant iw rfkill network-manager


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

    # 📂 Créer les répertoires pour stocker les fichiers kernel et armbian-config
    mkdir -p /opt/kernel_deb
    mkdir -p /opt/armbian_config

    # 📥 Télécharger les fichiers kernel et armbian-config AVANT le build
    GITHUB_REPO="https://raw.githubusercontent.com/Yumi-Lab/SmartPi-armbian/develop/userpatches/header"

    echo "📥 Téléchargement des fichiers kernel..."
    curl -L -o /opt/kernel_deb/linux-image-current-sunxi.deb "$GITHUB_REPO/linux-image-current-sunxi_24.2.1_armhf.deb"
    curl -L -o /opt/kernel_deb/linux-headers-current-sunxi.deb "$GITHUB_REPO/linux-headers-current-sunxi_24.2.1_armhf.deb"

    echo "📥 Téléchargement de `armbian-config` 24.5.5..."
    wget -O /opt/armbian_config/armbian-config_24.5.5_all.deb "http://imola.armbian.com/apt/pool/main/a/armbian-config/armbian-config_24.5.5_all__1-SA5703-B9a9b-R448a.deb"

    # Vérifier si les fichiers sont bien téléchargés
    if [[ ! -f /opt/kernel_deb/linux-image-current-sunxi.deb || ! -f /opt/kernel_deb/linux-headers-current-sunxi.deb ]]; then
        echo "❌ Erreur : Impossible de télécharger les fichiers kernel."
        exit 1
    fi

    if [[ ! -f /opt/armbian_config/armbian-config_24.5.5_all.deb ]]; then
        echo "❌ Erreur : Impossible de télécharger `armbian-config`."
        exit 1
    fi

    echo "✅ Tous les fichiers nécessaires sont prêts pour le premier démarrage."

    # 🛠 **Modifier `armbian-check-first-login.sh` pour inclure le kernel et le Wi-Fi avant `firstlogin`**
    echo "✍️ Modification de `armbian-check-first-login.sh`..."

    cat << 'EOF' > /usr/lib/armbian/armbian-check-first-login.sh
#!/bin/bash
echo "🚀 Vérification du premier login et installation du kernel..."

# Vérifier si le kernel est déjà installé
if [[ ! -f /opt/kernel_installed ]]; then
    echo "🔧 Installation du kernel custom et `armbian-config` avant `firstlogin`..."

    # ❌ Supprimer temporairement `.not_logged_in_yet` pour éviter `firstboot` prématuré
    if [[ -f /root/.not_logged_in_yet ]]; then
        echo "🗑 Suppression temporaire de /root/.not_logged_in_yet..."
        sudo rm -f /root/.not_logged_in_yet
    fi

    # 📌 Installation du kernel
    echo "⚙️ Installation du kernel..."
    sudo dpkg -i /opt/kernel_deb/*.deb
    if [[ $? -eq 0 ]]; then
        echo "✅ Kernel installé avec succès !"
    else
        echo "❌ Erreur d'installation du kernel."
        exit 1
    fi

    # 🔧 Installation de `armbian-config`
    echo "⚙️ Installation d'`armbian-config` 24.5.5..."
    sudo dpkg -i /opt/armbian_config/armbian-config_24.5.5_all.deb
    if [[ $? -eq 0 ]]; then
        echo "✅ `armbian-config` installé et verrouillé."
        sudo apt-mark hold armbian-config
    else
        echo "❌ Erreur d'installation d'`armbian-config`."
        exit 1
    fi

    # ✅ Vérifier et activer le Wi-Fi avant `firstboot`
    if lsusb | grep -iq "wireless"; then
        echo "✅ Clé Wi-Fi détectée, activation immédiate..."
        sudo systemctl restart NetworkManager.service
    else
        echo "⚠️ Aucune clé Wi-Fi détectée, configuration manuelle requise."
    fi

    # ✅ Marquer l’installation comme terminée pour éviter les exécutions répétées
    touch /opt/kernel_installed

    # 🔄 **Forcer un redémarrage immédiat AVANT `firstboot`**
    echo "🔄 Redémarrage immédiat pour charger le bon kernel..."
    sync && sudo reboot -f
    exit 0  # Empêche `armbian-firstlogin` de s'exécuter immédiatement après le premier boot
fi

# ✅ Si le kernel est déjà installé, on lance `armbian-firstlogin`
if [ -w /root/ -a -f /root/.not_logged_in_yet ]; then
    bash /usr/lib/armbian/armbian-firstlogin
fi
EOF

    # Donner les permissions d'exécution
    chmod +x /usr/lib/armbian/armbian-check-first-login.sh

    echo "✅ `armbian-check-first-login.sh` modifié avec succès !"

    echo "Fix sunxi ... [DONE]"
}





Main "S{@}"
