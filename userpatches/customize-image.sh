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
    
    # Répertoire pour stocker les fichiers kernel
    mkdir -p /opt/kernel_deb

    # URLs GitHub avec les fichiers en raw
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

    # Script oneshot pour le premier démarrage
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

# Nettoyage
echo "🧹 Suppression des fichiers kernel installés..."
rm -rf /opt/kernel_deb/

# Désactivation du service après installation
echo "🛑 Désactivation du service kernel-setup.service..."
sudo systemctl disable kernel-setup.service
sudo rm -f /etc/systemd/system/kernel-setup.service

# Création d'un fichier de contrôle pour indiquer que l'installation est faite
touch /opt/kernel_installed

# Redémarrage du système
echo "🔄 Redémarrage du système..."
sudo reboot
EOF

    chmod +x /opt/kernel_deb/install_kernel.sh

    # Service systemd pour installer le kernel au premier boot
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

    # Script de configuration après le reboot
    echo "Ajouter la configuration système après le reboot"
    cat << 'EOF' > /opt/first_boot_setup.sh
#!/bin/bash
# Vérifier si la configuration a déjà été effectuée
if [[ -f /opt/firstboot_done ]]; then
    echo "✅ Configuration déjà effectuée. Sortie."
    exit 0
fi

echo "🛠 Configuration initiale du système..."

# Mise à jour et upgrade
echo "📦 Mise à jour des paquets..."
sudo apt update && sudo apt upgrade -y

# Désactivation et suppression du service kernel-setup
echo "🛑 Suppression du service kernel-setup..."
sudo systemctl disable kernel-setup.service
sudo rm -f /etc/systemd/system/kernel-setup.service

# Création d'un fichier de contrôle pour éviter la boucle infinie
touch /opt/firstboot_done

# Redémarrage final après configuration
echo "🔄 Redémarrage final..."
sudo reboot
EOF

    chmod +x /opt/first_boot_setup.sh

    # Service systemd pour exécuter le script de configuration après le reboot
    echo "Créer un service systemd pour exécuter le script après le reboot"
    cat << 'EOF' > /etc/systemd/system/first-boot.service
[Unit]
Description=Configuration initiale du système après le premier boot
Wants=network.target
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/first_boot_setup.sh
ExecStop=/bin/true
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable first-boot.service

    echo "Fix sunxi ... [DONE]"
    
}


Main "S{@}"
