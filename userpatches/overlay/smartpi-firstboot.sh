#!/bin/bash
# SmartPi First Boot Configuration Script
# Compatible with both SmartPi config format AND Raspberry Pi Imager files
#
# Supported configuration methods:
# 1. SmartPi native: /boot/smartpi-config.txt (with APPLY_CONFIG=1)
# 2. Raspberry Pi Imager compatible files:
#    - /boot/ssh or /boot/ssh.txt (enable SSH)
#    - /boot/wpa_supplicant.conf (WiFi configuration)
#    - /boot/userconf.txt (user:encrypted_password)
#    - /boot/firstrun.sh (custom script from Pi Imager)

BOOT_DIR="/boot"
LOG_FILE="/var/log/smartpi-firstboot.log"
CONFIG_FILE="${BOOT_DIR}/smartpi-config.txt"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ============================================================
# RASPBERRY PI IMAGER COMPATIBLE FILES
# These are processed FIRST, before SmartPi config
# ============================================================

process_rpi_ssh() {
    # Raspberry Pi Imager creates an empty 'ssh' or 'ssh.txt' file to enable SSH
    if [[ -f "${BOOT_DIR}/ssh" ]] || [[ -f "${BOOT_DIR}/ssh.txt" ]]; then
        log "[RPI-COMPAT] Found ssh file, enabling SSH server"
        systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null
        systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null
        rm -f "${BOOT_DIR}/ssh" "${BOOT_DIR}/ssh.txt"
        log "[RPI-COMPAT] SSH enabled and trigger file removed"
        return 0
    fi
    return 1
}

process_rpi_wifi() {
    # Raspberry Pi Imager can create wpa_supplicant.conf on the boot partition
    local wpa_src="${BOOT_DIR}/wpa_supplicant.conf"
    local wpa_dest="/etc/wpa_supplicant/wpa_supplicant.conf"

    if [[ -f "$wpa_src" ]]; then
        log "[RPI-COMPAT] Found wpa_supplicant.conf, configuring WiFi"
        mkdir -p "$(dirname "$wpa_dest")"
        mv "$wpa_src" "$wpa_dest"
        chmod 600 "$wpa_dest"

        # Extract SSID for NetworkManager if available
        if command -v nmcli &> /dev/null; then
            local ssid=$(grep -oP 'ssid="\K[^"]+' "$wpa_dest" | head -n1)
            local psk=$(grep -oP 'psk="\K[^"]+' "$wpa_dest" | head -n1)
            if [[ -n "$ssid" ]] && [[ -n "$psk" ]]; then
                log "[RPI-COMPAT] Connecting to WiFi via NetworkManager: $ssid"
                nmcli dev wifi connect "$ssid" password "$psk" 2>/dev/null || true
            fi
        fi

        rfkill unblock wifi 2>/dev/null || true
        log "[RPI-COMPAT] WiFi configured"
        return 0
    fi
    return 1
}

process_rpi_userconf() {
    # Raspberry Pi Imager creates userconf.txt with format: username:encrypted_password
    local userconf="${BOOT_DIR}/userconf.txt"
    [[ ! -f "$userconf" ]] && userconf="${BOOT_DIR}/userconf"

    if [[ -f "$userconf" ]]; then
        log "[RPI-COMPAT] Found userconf, configuring user"
        local line=$(head -n1 "$userconf")
        local username=$(echo "$line" | cut -d: -f1)
        local password_hash=$(echo "$line" | cut -d: -f2-)

        if [[ -n "$username" ]] && [[ -n "$password_hash" ]]; then
            # Create user if not exists
            if ! id "$username" &>/dev/null; then
                log "[RPI-COMPAT] Creating user: $username"
                useradd -m -G sudo,users -s /bin/bash "$username" 2>/dev/null
            fi
            # Set password (already hashed)
            echo "${username}:${password_hash}" | chpasswd -e
            log "[RPI-COMPAT] User $username configured"
        fi
        rm -f "$userconf" "${BOOT_DIR}/userconf"
        return 0
    fi
    return 1
}

process_rpi_firstrun() {
    # Raspberry Pi Imager can create a firstrun.sh script
    local firstrun="${BOOT_DIR}/firstrun.sh"

    if [[ -f "$firstrun" ]]; then
        log "[RPI-COMPAT] Found firstrun.sh, executing"
        chmod +x "$firstrun"
        bash "$firstrun" >> "$LOG_FILE" 2>&1 || log "[RPI-COMPAT] firstrun.sh returned error"
        rm -f "$firstrun"
        log "[RPI-COMPAT] firstrun.sh executed and removed"
        return 0
    fi
    return 1
}

process_rpi_hostname() {
    # Some tools create a hostname file
    local hostname_file="${BOOT_DIR}/hostname"

    if [[ -f "$hostname_file" ]]; then
        local new_hostname=$(cat "$hostname_file" | tr -d '[:space:]')
        if [[ -n "$new_hostname" ]]; then
            log "[RPI-COMPAT] Found hostname file, setting hostname to: $new_hostname"
            hostnamectl set-hostname "$new_hostname" 2>/dev/null
            echo "$new_hostname" > /etc/hostname
            sed -i "s/127.0.1.1.*/127.0.1.1\t$new_hostname/" /etc/hosts
            if ! grep -q "127.0.1.1" /etc/hosts; then
                echo "127.0.1.1	$new_hostname" >> /etc/hosts
            fi
        fi
        rm -f "$hostname_file"
        return 0
    fi
    return 1
}

# ============================================================
# SMARTPI NATIVE CONFIGURATION
# ============================================================

process_smartpi_config() {
    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "[SMARTPI] No config file found at $CONFIG_FILE"
        return 1
    fi

    # Check if already processed
    if [[ -f "${CONFIG_FILE}.done" ]]; then
        log "[SMARTPI] First boot configuration already completed"
        return 0
    fi

    # Source the config file
    source "$CONFIG_FILE"

    # Check if user wants to apply configuration
    if [[ "$APPLY_CONFIG" != "1" ]]; then
        log "[SMARTPI] APPLY_CONFIG is not set to 1, skipping SmartPi configuration"
        log "[SMARTPI] Edit $CONFIG_FILE and set APPLY_CONFIG=1 to apply settings"
        return 1
    fi

    log "[SMARTPI] Starting SmartPi configuration..."

    # ============ HOSTNAME ============
    if [[ -n "$HOSTNAME" ]]; then
        log "[SMARTPI] Setting hostname to: $HOSTNAME"
        hostnamectl set-hostname "$HOSTNAME" 2>/dev/null
        echo "$HOSTNAME" > /etc/hostname
        sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts
        if ! grep -q "127.0.1.1" /etc/hosts; then
            echo "127.0.1.1	$HOSTNAME" >> /etc/hosts
        fi
    fi

    # ============ SSH ============
    if [[ "$SSH_ENABLED" == "1" ]]; then
        log "[SMARTPI] Enabling SSH server"
        systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null
        systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null
    elif [[ "$SSH_ENABLED" == "0" ]]; then
        log "[SMARTPI] Disabling SSH server"
        systemctl disable ssh 2>/dev/null || systemctl disable sshd 2>/dev/null
        systemctl stop ssh 2>/dev/null || systemctl stop sshd 2>/dev/null
    fi

    # ============ TIMEZONE ============
    if [[ -n "$TIMEZONE" ]]; then
        log "[SMARTPI] Setting timezone to: $TIMEZONE"
        timedatectl set-timezone "$TIMEZONE" 2>/dev/null || \
            ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    fi

    # ============ LOCALE ============
    if [[ -n "$LOCALE" ]]; then
        log "[SMARTPI] Setting locale to: $LOCALE"
        sed -i "s/^# *${LOCALE}/${LOCALE}/" /etc/locale.gen 2>/dev/null
        locale-gen 2>/dev/null
        update-locale LANG="$LOCALE" 2>/dev/null
    fi

    # ============ WIFI ============
    if [[ -n "$WIFI_SSID" ]] && [[ -n "$WIFI_PASSWORD" ]]; then
        log "[SMARTPI] Configuring WiFi: $WIFI_SSID"

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
            log "[SMARTPI] Using NetworkManager for WiFi"
            nmcli dev wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD" 2>/dev/null || true
        fi

        # Enable wlan0 interface
        rfkill unblock wifi 2>/dev/null || true
    fi

    # ============ STATIC IP ============
    if [[ -n "$STATIC_IP" ]] && [[ -n "$GATEWAY" ]]; then
        log "[SMARTPI] Configuring static IP: $STATIC_IP"

        # Detect primary network interface
        IFACE=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -n1)
        [[ -z "$IFACE" ]] && IFACE="eth0"

        # For NetworkManager based systems
        if command -v nmcli &> /dev/null; then
            log "[SMARTPI] Using NetworkManager for static IP"
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
            log "[SMARTPI] Using /etc/network/interfaces for static IP"
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
        log "[SMARTPI] Setting root password"
        echo "root:$ROOT_PASSWORD" | chpasswd
    fi

    # ============ FIRST USER ============
    if [[ -n "$USERNAME" ]] && [[ -n "$USER_PASSWORD" ]]; then
        log "[SMARTPI] Creating user: $USERNAME"
        if ! id "$USERNAME" &>/dev/null; then
            useradd -m -G sudo,users -s /bin/bash "$USERNAME" 2>/dev/null
        fi
        echo "$USERNAME:$USER_PASSWORD" | chpasswd
        log "[SMARTPI] User $USERNAME created"
    fi

    # Mark configuration as done
    log "[SMARTPI] Configuration completed!"
    mv "$CONFIG_FILE" "${CONFIG_FILE}.done"

    return 0
}

# ============================================================
# MAIN
# ============================================================

main() {
    log "========================================"
    log "SmartPi First Boot Configuration"
    log "========================================"
    log "Checking for configuration files..."

    local config_applied=false

    # Process Raspberry Pi Imager compatible files first
    process_rpi_ssh && config_applied=true
    process_rpi_wifi && config_applied=true
    process_rpi_userconf && config_applied=true
    process_rpi_hostname && config_applied=true
    process_rpi_firstrun && config_applied=true

    # Then process SmartPi native config
    process_smartpi_config && config_applied=true

    if [[ "$config_applied" == "true" ]]; then
        log "First boot configuration completed successfully!"
    else
        log "No configuration applied (no valid config files found)"
    fi

    # Disable the service after first run
    systemctl disable smartpi-firstboot.service 2>/dev/null

    log "========================================"
    log "SmartPi First Boot Finished"
    log "========================================"
}

main "$@"
exit 0
