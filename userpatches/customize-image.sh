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

    # 📜 Script oneshot pour installer le kernel et forcer un redémarrage complet
    echo "Créer le script pour l'installation du kernel et redémarrage forcé"
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

# 🔄 Redémarrage forcé pour s'assurer que le kernel correct est chargé
echo "🔄 Redémarrage du système..."
sync && sudo reboot -f
EOF

    chmod +x /opt/kernel_deb/install_kernel.sh

    # 🖥️ Service systemd pour installer le kernel et forcer le reboot
    echo "Créer le service systemd pour installer le kernel et forcer le reboot"
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

    # 📜 Script pour vérifier la présence de la clé Wi-Fi avant `armbian-firstboot`
    echo "Créer le script pour détecter la clé Wi-Fi et activer la connexion"
    cat << 'EOF' > /opt/check_wifi_usb.sh
#!/bin/bash

echo "📶 Vérification de la présence d'une clé Wi-Fi USB..."

# Attendre quelques secondes pour que la clé Wi-Fi USB soit détectée après le boot
sleep 5

# Vérifier si une interface Wi-Fi USB est présente
WIFI_INTERFACE=\$(lsusb | grep -i "wireless")

if [[ -z "\$WIFI_INTERFACE" ]]; then
    echo "❌ Aucune clé Wi-Fi USB détectée. La connexion Wi-Fi ne sera pas configurée."
    exit 1
else
    echo "✅ Clé Wi-Fi USB détectée ! Configuration du Wi-Fi..."
fi

# Modifier les paramètres ici
SSID="Nom_du_WiFi"
PASSWORD="Mot_de_passe_WiFi"

# Vérification de la présence de NetworkManager
if ! command -v nmcli &> /dev/null; then
    echo "❌ NetworkManager non trouvé !"
    exit 1
fi

# Vérification si le Wi-Fi est déjà configuré
if nmcli connection show | grep -q "\$SSID"; then
    echo "✅ Wi-Fi déjà configuré !"
    exit 0
fi

# Ajouter et connecter le Wi-Fi
nmcli dev wifi connect "\$SSID" password "\$PASSWORD"

# Attendre que le Wi-Fi soit connecté
for i in {1..10}; do
    if nmcli d | grep -q "wifi" | grep -q "connected"; then
        echo "✅ Wi-Fi connecté !"
        break
    fi
    echo "⏳ Tentative de connexion ($i/10)..."
    sleep 3
done

echo "✅ Wi-Fi prêt pour `armbian-firstboot`."
EOF

    chmod +x /opt/check_wifi_usb.sh

    # Service systemd pour vérifier la clé Wi-Fi avant `armbian-firstboot`
    echo "Créer un service systemd pour vérifier la clé Wi-Fi USB avant armbian-firstboot"
    cat << 'EOF' > /etc/systemd/system/check-wifi-usb.service
[Unit]
Description=Vérifie la clé Wi-Fi USB avant la configuration d'Armbian
Wants=network.target
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/check_wifi_usb.sh
ExecStop=/bin/true
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable check-wifi-usb.service

    # 📜 Script pour vérifier le kernel et activer `armbian-firstboot`
    echo "Créer le script pour vérifier le kernel et activer `armbian-firstboot`"
    cat << 'EOF' > /opt/check_kernel_and_wifi.sh
#!/bin/bash
TARGET_KERNEL="6.6.16-current-sunxi"
CURRENT_KERNEL=\$(uname -r)

echo "🔍 Vérification du kernel après reboot..."
if [[ "\$CURRENT_KERNEL" != "\$TARGET_KERNEL" ]]; then
    echo "❌ Le kernel correct (\$TARGET_KERNEL) n'est pas chargé ! Redémarrage forcé..."
    sync && sudo reboot -f
fi

echo "✅ Kernel correct chargé : \$CURRENT_KERNEL"

# Activer `armbian-firstboot`
echo "🛠 Activation de armbian-firstboot..."
sudo touch /root/.not_logged_in_yet
sudo systemctl enable armbian-firstboot.service

# Suppression du script après exécution
sudo rm -f /opt/check_kernel_and_wifi.sh
EOF

    chmod +x /opt/check_kernel_and_wifi.sh

    # Service systemd pour vérifier le kernel et le Wi-Fi avant `armbian-firstboot`
    echo "Créer un service systemd pour vérifier le kernel et la clé Wi-Fi avant armbian-firstboot"
    cat << 'EOF' > /etc/systemd/system/check-kernel-and-wifi.service
[Unit]
Description=Vérification du kernel et activation du Wi-Fi avant la configuration Armbian
Wants=network.target
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/check_kernel_and_wifi.sh
ExecStop=/bin/true
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable check-kernel-and-wifi.service

    echo "Fix sunxi ... [DONE]"
}





Main "S{@}"
