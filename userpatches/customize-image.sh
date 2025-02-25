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

    # 📂 Créer le répertoire pour stocker les fichiers kernel et armbian-config
    mkdir -p /opt/kernel_deb
    mkdir -p /opt/armbian_config

    # 📥 Télécharger les fichiers kernel depuis GitHub
    GITHUB_REPO="https://raw.githubusercontent.com/Yumi-Lab/SmartPi-armbian/develop/userpatches/header"
    echo "📥 Téléchargement des fichiers kernel..."
    
    curl -L -o /opt/kernel_deb/linux-image-current-sunxi.deb "$GITHUB_REPO/linux-image-current-sunxi_24.2.1_armhf.deb"
    curl -L -o /opt/kernel_deb/linux-headers-current-sunxi.deb "$GITHUB_REPO/linux-headers-current-sunxi_24.2.1_armhf.deb"

    # 📥 Télécharger armbian-config 24.5.5
    echo "📥 Téléchargement de `armbian-config_24.5.5`..."
    wget -O /opt/armbian_config/armbian-config_24.5.5_all.deb "http://imola.armbian.com/apt/pool/main/a/armbian-config/armbian-config_24.5.5_all__1-SA5703-B9a9b-R448a.deb"

    # Vérifier si les fichiers ont bien été téléchargés
    if [[ ! -f /opt/kernel_deb/linux-image-current-sunxi.deb || ! -f /opt/kernel_deb/linux-headers-current-sunxi.deb ]]; then
        echo "❌ Erreur : Impossible de télécharger les fichiers kernel."
        exit 1
    fi

    if [[ ! -f /opt/armbian_config/armbian-config_24.5.5_all.deb ]]; then
        echo "❌ Erreur : Impossible de télécharger `armbian-config`."
        exit 1
    fi

    echo "✅ Tous les fichiers nécessaires ont été téléchargés avec succès !"

    # 📜 Script pour installer le kernel et `armbian-config`, puis **forcer un reboot immédiat après installation**
    echo "Créer le script pour installer le kernel, `armbian-config` et forcer un reboot"
    cat << 'EOF' > /opt/kernel_deb/install_kernel.sh
#!/bin/bash
echo "🔧 Installation du kernel custom et `armbian-config`..."

# ❌ Supprimer le fichier `.not_logged_in_yet` pour éviter le lancement prématuré de `firstboot`
if [[ -f /root/.not_logged_in_yet ]]; then
    echo "🗑 Suppression de /root/.not_logged_in_yet avant installation..."
    sudo rm -f /root/.not_logged_in_yet
fi

# Vérifier si les fichiers sont présents
if [[ ! -f /opt/kernel_deb/linux-image-current-sunxi.deb || ! -f /opt/kernel_deb/linux-headers-current-sunxi.deb ]]; then
    echo "❌ Fichiers kernel introuvables. Annulation."
    exit 1
fi

if [[ ! -f /opt/armbian_config/armbian-config_24.5.5_all.deb ]]; then
    echo "❌ Fichier `armbian-config` introuvable. Annulation."
    exit 1
fi

# 🏗 Installer le kernel
echo "⚙️ Installation du kernel..."
sudo dpkg -i /opt/kernel_deb/*.deb

# Vérifier l'installation du kernel
if [[ $? -ne 0 ]]; then
    echo "❌ Erreur lors de l'installation du kernel."
    exit 1
fi

# 🔧 Installer `armbian-config`
echo "⚙️ Installation d'`armbian-config` 24.5.5..."
sudo dpkg -i /opt/armbian_config/armbian-config_24.5.5_all.deb

# Vérifier l'installation de `armbian-config`
if [[ $? -ne 0 ]]; then
    echo "❌ Erreur lors de l'installation d'`armbian-config`."
    exit 1
fi

# 📌 Bloquer la mise à jour d'`armbian-config`
sudo apt-mark hold armbian-config

# ✅ Vérifier et activer le Wi-Fi AVANT `firstboot`
if lsusb | grep -iq "wireless"; then
    echo "✅ Clé Wi-Fi détectée, activation immédiate..."
    sudo systemctl restart NetworkManager.service
else
    echo "⚠️ Aucune clé Wi-Fi détectée. Vous devrez configurer le Wi-Fi manuellement."
fi

# 🛠 **Recréer** `/root/.not_logged_in_yet` pour forcer `armbian-firstboot`
echo "🛠 Activation de armbian-firstboot après reboot..."
sudo touch /root/.not_logged_in_yet
sudo systemctl enable armbian-firstboot.service

# 🛑 Supprimer le service après exécution pour éviter les boucles infinies
echo "🛑 Suppression du service kernel-setup.service..."
sudo systemctl disable kernel-setup.service
sudo rm -f /etc/systemd/system/kernel-setup.service

# 🔄 **Forcer un redémarrage immédiat avant `firstboot`**
echo "🔄 Redémarrage immédiat pour charger le nouveau kernel et `armbian-config`..."
sync && sudo reboot -f
EOF

    chmod +x /opt/kernel_deb/install_kernel.sh

    # 🖥️ Service systemd pour installer le kernel et `armbian-config` AVANT `firstboot`
    echo "Créer le service systemd pour installer le kernel et `armbian-config` avant `firstboot`"
    cat << 'EOF' > /etc/systemd/system/kernel-setup.service
[Unit]
Description=Installation du kernel custom et `armbian-config` avant premier démarrage
Wants=network.target
Before=armbian-firstboot.service
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/opt/kernel_deb/install_kernel.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable kernel-setup.service

    echo "Fix sunxi ... [DONE]"
}











Main "S{@}"
