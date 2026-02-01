#!/bin/bash
# SmartPi First Boot Configuration Script
# This script reads /boot/smartpi-config.txt and applies the configuration
# Only runs if APPLY_CONFIG=1 in the config file

CONFIG_FILE="/boot/smartpi-config.txt"
LOG_FILE="/var/log/smartpi-firstboot.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    log "No config file found at $CONFIG_FILE, skipping"
    exit 0
fi

# Check if already processed
if [[ -f "${CONFIG_FILE}.done" ]]; then
    log "First boot configuration already completed"
    exit 0
fi

# Source the config file
source "$CONFIG_FILE"

# Check if user wants to apply configuration
if [[ "$APPLY_CONFIG" != "1" ]]; then
    log "APPLY_CONFIG is not set to 1, skipping configuration"
    log "Edit $CONFIG_FILE and set APPLY_CONFIG=1 to apply settings"
    exit 0
fi

log "Starting SmartPi first boot configuration..."

# ============ HOSTNAME ============
if [[ -n "$HOSTNAME" ]]; then
    log "Setting hostname to: $HOSTNAME"
    hostnamectl set-hostname "$HOSTNAME" 2>/dev/null
    echo "$HOSTNAME" > /etc/hostname
    sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts
    if ! grep -q "127.0.1.1" /etc/hosts; then
        echo "127.0.1.1	$HOSTNAME" >> /etc/hosts
    fi
fi

# ============ SSH ============
if [[ "$SSH_ENABLED" == "1" ]]; then
    log "Enabling SSH server"
    systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null
    systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null
elif [[ "$SSH_ENABLED" == "0" ]]; then
    log "Disabling SSH server"
    systemctl disable ssh 2>/dev/null || systemctl disable sshd 2>/dev/null
    systemctl stop ssh 2>/dev/null || systemctl stop sshd 2>/dev/null
fi

# ============ TIMEZONE ============
if [[ -n "$TIMEZONE" ]]; then
    log "Setting timezone to: $TIMEZONE"
    timedatectl set-timezone "$TIMEZONE" 2>/dev/null || \
        ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
fi

# ============ LOCALE ============
if [[ -n "$LOCALE" ]]; then
    log "Setting locale to: $LOCALE"
    sed -i "s/^# *${LOCALE}/${LOCALE}/" /etc/locale.gen 2>/dev/null
    locale-gen 2>/dev/null
    update-locale LANG="$LOCALE" 2>/dev/null
fi

# ============ WIFI ============
if [[ -n "$WIFI_SSID" ]] && [[ -n "$WIFI_PASSWORD" ]]; then
    log "Configuring WiFi: $WIFI_SSID"

    # Create wpa_supplicant configuration
    WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
    mkdir -p "$(dirname "$WPA_CONF")"
    cat > "$WPA_CONF" << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=${WIFI_COUNTRY:-FR}

network={
    ssid="$WIFI_SSID"
    psk="$WIFI_PASSWORD"
    key_mgmt=WPA-PSK
}
EOF
    chmod 600 "$WPA_CONF"

    # For NetworkManager based systems
    if command -v nmcli &> /dev/null; then
        log "Using NetworkManager for WiFi"
        nmcli dev wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD" 2>/dev/null || true
    fi

    # Enable wlan0 interface
    rfkill unblock wifi 2>/dev/null || true
fi

# ============ STATIC IP ============
if [[ -n "$STATIC_IP" ]] && [[ -n "$GATEWAY" ]]; then
    log "Configuring static IP: $STATIC_IP"

    # Detect primary network interface
    IFACE=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -n1)
    [[ -z "$IFACE" ]] && IFACE="eth0"

    # For NetworkManager based systems
    if command -v nmcli &> /dev/null; then
        log "Using NetworkManager for static IP"
        CON_NAME=$(nmcli -t -f NAME,DEVICE con show 2>/dev/null | grep "$IFACE" | cut -d: -f1 | head -n1)
        if [[ -n "$CON_NAME" ]]; then
            nmcli con mod "$CON_NAME" ipv4.addresses "$STATIC_IP/${NETMASK:-24}"
            nmcli con mod "$CON_NAME" ipv4.gateway "$GATEWAY"
            [[ -n "$DNS" ]] && nmcli con mod "$CON_NAME" ipv4.dns "$DNS"
            nmcli con mod "$CON_NAME" ipv4.method manual
            nmcli con up "$CON_NAME" 2>/dev/null || true
        fi
    else
        # For /etc/network/interfaces based systems
        log "Using /etc/network/interfaces for static IP"
        mkdir -p /etc/network/interfaces.d
        cat > /etc/network/interfaces.d/static-ip << EOF
auto $IFACE
iface $IFACE inet static
    address $STATIC_IP
    netmask ${NETMASK:-255.255.255.0}
    gateway $GATEWAY
EOF
        [[ -n "$DNS" ]] && echo "    dns-nameservers $DNS" >> /etc/network/interfaces.d/static-ip
    fi
fi

# ============ ROOT PASSWORD ============
if [[ -n "$ROOT_PASSWORD" ]]; then
    log "Setting root password"
    echo "root:$ROOT_PASSWORD" | chpasswd
fi

# Mark configuration as done
log "First boot configuration completed!"
mv "$CONFIG_FILE" "${CONFIG_FILE}.done"

# Disable the service after first run
systemctl disable smartpi-firstboot.service 2>/dev/null

log "SmartPi first boot configuration finished successfully"
exit 0
