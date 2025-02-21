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

    # 📂 Répertoire pour stocker les fichiers kernel
    mkdir -p /opt/kernel_deb

    # 📥 URLs GitHub avec les fichiers en raw
    GITHUB_REPO="https://raw.githubusercontent.com/Yumi-Lab/SmartPi-armbian/develop/userpatches/header"

    echo "📥 Téléchargement des fichiers kernel depuis GitHub..."

    curl -L -o /opt/kernel_deb/linux-image-current-sunxi.deb "$GITHUB_REPO/linux-image-current-sunxi_24.2.1_armhf.deb"
    curl -L -o /opt/kernel_deb/linux-headers-current-sunxi.deb "$GITHUB_REPO/linux-headers-current-sunxi_24.2.1_armhf.deb"

    # Vérification des fichiers
    if [[ ! -f /opt/kernel_deb/linux-image-current-sunxi.deb || ! -f /opt/kernel_deb/linux-headers-current-sunxi.deb ]]; then
        echo "❌ Erreur : Impossible de télécharger les fichiers kernel depuis GitHub."
        exit 1
    fi

    echo "✅ Fichiers kernel téléchargés avec succès !"

    # 📜 Script oneshot pour le premier démarrage
    echo "Créer le script oneshot pour le premier démarrage"
    cat << 'EOF' > /opt/kernel_deb/install_kernel.sh
#!/bin/bash
echo "🔧 Installation du kernel custom..."

# Vérification des fichiers
if [[ ! -f /opt/kernel_deb/linux-image-current-sunxi.deb || ! -f /opt/kernel_deb/linux-headers-current-sunxi.deb ]]; then
    echo "❌ Fichiers kernel introuvables. Annulation."
    exit 1
fi

# Installation des paquets
echo "⚙️ Installation du kernel..."
sudo dpkg -i /opt/kernel_deb/*.deb

# Vérification de l'installation
if [[ $? -ne 0 ]]; then
    echo "❌ Erreur lors de l'installation des paquets. Abandon."
    exit 1
fi

# 🛑 Désactivation du service après installation
echo "🛑 Désactivation du service kernel-setup.service..."
sudo systemctl disable kernel-setup.service
sudo rm -f /etc/systemd/system/kernel-setup.service

# Création d'un fichier de contrôle
touch /opt/kernel_installed

# 🔄 Redémarrage du système pour finaliser l'installation
echo "🔄 Redémarrage du système..."
sudo reboot
EOF

    chmod +x /opt/kernel_deb/install_kernel.sh

    # 🖥️ Service systemd pour installer le kernel au premier boot
    echo "Ajouter le service systemd pour installer le kernel au premier boot"
    cat << 'EOF' > /etc/systemd/system/kernel-setup.service
[Unit]
Description=Installation du kernel custom au premier démarrage
Wants=network.target
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/kernel_deb/install_kernel.sh
ExecStop=/bin/true
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable kernel-setup.service

    # 📜 Script de réactivation de `armbian-firstboot` après le dernier redémarrage
    echo "Créer le script pour activer `armbian-firstboot` après reboot"
    cat << 'EOF' > /opt/activate_armbian_firstboot.sh
#!/bin/bash

echo "🛠 Réactivation de armbian-firstboot pour la configuration initiale..."
sudo touch /root/.not_logged_in_yet
sudo systemctl enable armbian-firstboot.service

# Suppression du script après exécution
sudo rm -f /opt/activate_armbian_firstboot.sh
EOF

    chmod +x /opt/activate_armbian_firstboot.sh

    # Service systemd pour exécuter la réactivation de `armbian-firstboot` après le dernier reboot
    echo "Créer un service systemd pour activer `armbian-firstboot` après installation du kernel"
    cat << 'EOF' > /etc/systemd/system/enable-armbian-firstboot.service
[Unit]
Description=Réactive la configuration initiale après l'installation du kernel
Wants=network.target
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/opt/activate_armbian_firstboot.sh
ExecStop=/bin/true
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable enable-armbian-firstboot.service

    echo "Fix sunxi ... [DONE]"
}




Main "S{@}"
