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
    # Install dwarves (provides pahole) on Bullseye where pahole is not a standalone package
    if [[ "${RELEASE}" == "bullseye" ]]; then
        echo "Installing dwarves (pahole) for Bullseye ..."
        apt-get update && apt-get install -y dwarves
        echo "Installing dwarves (pahole) for Bullseye ... [DONE]"
    fi

    case "${BOARD}" in
        smartpi1)
            installSmartpadDetection
            installUsbGadgetNet
            installCloudInitDefaults
            disableSimpledrm
            forceUniversalVideoMode
            useClassicNetNames
            installOverclockControl
            autoRepairFilesystems
            hardenAgainstPowerCuts
            installBootTelemetry
            if [[ "${BUILD_DESKTOP}" = "yes" ]]; then
                enableDesktopLogin
                installHdmiHotplug
                installRotationScript
                setUpTouchScreen
                copyOnboardConf
                patchOnboardAutostart
                installScreensaverSetup
                # Chromium white-window bug: trixie generation only (noble
                # renders fine, leave it alone)
                case "${RELEASE}" in
                    trixie|forky|sid) installChromiumFlags ;;
                esac
            fi
            ;;
    esac
}

installSmartpadDetection() {
    # The SmartPad is a SmartPi One fitted with a 4.3" 800x480 HDMI touchscreen
    # mounted upside-down. Rotation is decided at runtime by detecting that
    # screen (resolution + touchscreen), so a single image works on both a
    # bare SmartPi One (normal monitor) and a SmartPad.
    echo "Install SmartPad screen detection + console rotation ..."

    cp -v /tmp/overlay/smartpad-detect.sh /usr/local/bin/smartpad-detect.sh
    chmod 755 /usr/local/bin/smartpad-detect.sh

    cp -v /tmp/overlay/smartpad-console-rotate.sh /usr/local/bin/smartpad-console-rotate.sh
    chmod 755 /usr/local/bin/smartpad-console-rotate.sh

    cp -v /tmp/overlay/smartpad-console-rotate.service /etc/systemd/system/smartpad-console-rotate.service
    chmod 644 /etc/systemd/system/smartpad-console-rotate.service
    systemctl enable smartpad-console-rotate.service

    echo "Install SmartPad screen detection + console rotation ... [DONE]"
}

disableSimpledrm() {
    # U-Boot hands the kernel a simple-framebuffer node, and simpledrm binds to
    # it alongside the native sun4i-drm driver. Both framebuffers then exist and
    # the console can end up drawn into the one that is no longer scanned out,
    # leaving a black screen after boot (verified on hardware). sun4i-drm always
    # drives this board, so the fallback driver is not needed.
    # Blocked on the kernel command line rather than through modprobe.d alone:
    # updating the initramfs fails on this FAT boot partition (no symlinks), so
    # a modprobe.d rule may never reach early boot.
    echo "Disable simpledrm (conflicts with sun4i-drm) ..."
    echo "blacklist simpledrm" > /etc/modprobe.d/smartpi-no-simpledrm.conf
    addKernelArg module_blacklist=simpledrm
    echo "Disable simpledrm ... [DONE]"
}

forceUniversalVideoMode() {
    # The H3 tops out at 4K@30 (HDMI 1.4): letting the kernel negotiate with a
    # 4K UHD screen ends badly (unsupported 4K@60 preferred mode, or a 4K@30
    # framebuffer the Mali-400 cannot drive). Forcing 1280x720@60 guarantees a
    # picture on every screen — 4K UHD included, they all accept and upscale
    # 720p — and is the mode RetroMi already ships with for the same reason.
    # The forced mode lands FIRST in the DRM mode list, which is why
    # smartpad-detect.sh scans the whole list instead of the first entry.
    echo "Force universal 720p video mode (4K screen compatibility) ..."
    addKernelArg video=HDMI-A-1:1280x720@60
    echo "Force universal 720p video mode ... [DONE]"
}

addKernelArg() {
    # Append one argument to the extraargs= line of armbianEnv.txt (created if
    # missing); U-Boot passes it on the kernel command line.
    local bootcfg="/boot/armbianEnv.txt"
    if grep -q "^extraargs=" "${bootcfg}" 2>/dev/null; then
        sed -i "s|^extraargs=\(.*\)|extraargs=\1 $1|" "${bootcfg}"
    else
        echo "extraargs=$1" >> "${bootcfg}"
    fi
    grep "^extraargs=" "${bootcfg}"
}

useClassicNetNames() {
    # Raspberry Pi Imager's cloud-init network-config hardcodes eth0 and wlan0
    # (the names Raspberry Pi OS uses). With systemd's predictable names the SoC
    # Ethernet is end0 and a USB WiFi dongle wlx<mac>, so a WiFi network set at
    # flash time would never match its interface and never come up.
    echo "Use classic network interface names (eth0/wlan0) ..."
    addKernelArg net.ifnames=0
    echo "Use classic network interface names ... [DONE]"
}

installOverclockControl() {
    # The 1368 MHz OPP is no longer force-enabled in the kernel patches:
    # with Armbian's current voltage tables the frequency hopping during
    # boot hangs boards right after "Reached target Paths." (verified on
    # hardware; the same image boots with cpufreq disabled). Default is
    # now the stock table — max 1296 MHz, adaptive governor — and
    # "smartpi-oc on" opts in to 1368 MHz at the Yumi-validated 1.40 V
    # with the performance governor (no frequency hopping).
    echo "Install overclock control (smartpi-oc) ..."
    apt-get install -y --no-install-recommends device-tree-compiler
    mkdir -p /boot/overlay-user
    dtc -@ -I dts -O dtb -o /boot/overlay-user/opp1368.dtbo /tmp/overlay/opp1368.dts
    cp -v /tmp/overlay/smartpi-oc /usr/local/bin/smartpi-oc
    chmod 755 /usr/local/bin/smartpi-oc
    echo "Install overclock control ... [DONE]"
}

autoRepairFilesystems() {
    # Pulling the plug is how users switch the board off, so file systems
    # routinely come back dirty. Without this flag the initramfs runs fsck in
    # preen mode (-a) and stops on "requires a manual fsck" for anything it
    # will not fix on its own: headless, that is a dead card to reflash.
    # fsck.repair=yes answers yes to every repair, the default Raspberry Pi OS
    # ships in cmdline.txt; systemd-fsck applies it to the FAT /boot as well.
    echo "Repair file systems automatically at boot ..."
    addKernelArg fsck.repair=yes
    echo "Repair file systems automatically at boot ... [DONE]"
}

hardenAgainstPowerCuts() {
    # Boards live inside printers and get hard power cuts; three more in-place
    # settings, no layout change. The ext4 data mode is fixed in the superblock
    # of the final image (boards/smartpi1.wip), out of reach of this script.
    # - panic=10: a kernel panic, or the initramfs stopping on a root it cannot
    #   mount, reboots after 10 s instead of waiting forever on a console nobody
    #   watches.
    # - journal in RAM: Debian creates /var/log/journal, so journald is
    #   persistent, and armbian-ramlog moves that journal to /var/log.hdd on the
    #   card, written continuously. The current boot's log stays in /run.
    # - hardware watchdog: sunxi_wdt is built in (16 s maximum); PID 1 pings it
    #   every 8 s, so a hung system resets itself. It is armed as the first
    #   services start (basic.target, the earliest point where busctl reaches
    #   PID 1 over D-Bus), not by system.conf: PID 1 does not ping while it
    #   runs generators and loads units, 13 s measured from a USB stick behind
    #   a USB 1.1 hub, and beyond 16 s the watchdog reset every boot in a loop.
    #   After that phase the longest PID 1 silence measured on that drive was
    #   9 s, so a boot that hangs later is still reset.
    #   RebootWatchdogSec stays off: the driver cannot go beyond 16 s and the
    #   sync in systemd-shutdown may take longer than that without a ping.
    #   ponytail: a daemon-reexec (systemd upgrade) rereads system.conf and
    #   disarms the watchdog until the next boot.
    echo "Harden against hard power cuts ..."
    addKernelArg panic=10
    mkdir -p /etc/systemd/journald.conf.d /etc/systemd/system.conf.d
    printf '[Journal]\nStorage=volatile\nRuntimeMaxUse=32M\n' > /etc/systemd/journald.conf.d/10-smartpi-journal.conf
    printf '[Manager]\nRebootWatchdogSec=off\n' > /etc/systemd/system.conf.d/10-smartpi-watchdog.conf
    printf '%s\n' '[Unit]' 'Description=Arm the hardware watchdog once systemd has loaded its units' \
        '' '[Service]' 'Type=oneshot' \
        'ExecStart=/usr/bin/busctl set-property org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager RuntimeWatchdogUSec t 16000000' \
        '' '[Install]' 'WantedBy=multi-user.target' > /etc/systemd/system/smartpi-watchdog.service
    systemctl enable smartpi-watchdog.service
    echo "Harden against hard power cuts ... [DONE]"
}

installBootTelemetry() {
    # One line per boot in /var/lib/yumi/boot.log, copied to /boot/yumi-boot.log
    # (FAT, readable from any PC) only after a power cut or a repair. Says which
    # failure class kills a card before investing in a read-only root or in
    # industrial cards.
    echo "Install boot telemetry (yumi-bootlog) ..."
    cp -v /tmp/overlay/yumi-bootlog /usr/local/bin/yumi-bootlog
    chmod 755 /usr/local/bin/yumi-bootlog
    cp -v /tmp/overlay/yumi-bootlog.service /etc/systemd/system/yumi-bootlog.service
    chmod 644 /etc/systemd/system/yumi-bootlog.service
    systemctl enable yumi-bootlog.service
    echo "Install boot telemetry (yumi-bootlog) ... [DONE]"
}

installUsbGadgetNet() {
    # USB0 (OTG) runs as a network gadget (g_ether, enabled in the device
    # tree): plugging the OTG port into a computer gives SSH access at
    # 172.22.1.1 without Ethernet.
    echo "Install USB gadget network ..."
    cp -v /tmp/overlay/usb-gadget-net.sh /usr/local/bin/usb-gadget-net.sh
    chmod 755 /usr/local/bin/usb-gadget-net.sh
    cp -v /tmp/overlay/usb-gadget-net.service /etc/systemd/system/usb-gadget-net.service
    chmod 644 /etc/systemd/system/usb-gadget-net.service
    systemctl enable usb-gadget-net.service
    echo "Install USB gadget network ... [DONE]"
}

installRotationScript() {
    # Install xrandr-based rotation script (gated on SmartPad screen detection)
    echo "Installing SmartPad rotation script ..."

    # Install the rotation script
    local scriptSrc="/tmp/overlay/smartpad-rotate.sh"
    local scriptDest="/usr/local/bin/smartpad-rotate.sh"
    if [[ -f "${scriptSrc}" ]]; then
        cp -v "${scriptSrc}" "${scriptDest}"
        chmod 755 "${scriptDest}"
        echo "Rotation script installed to ${scriptDest}"
    fi

    # Install autostart desktop file
    local desktopSrc="/tmp/overlay/smartpad-rotate.desktop"
    local desktopDest="/etc/xdg/autostart/smartpad-rotate.desktop"
    if [[ -f "${desktopSrc}" ]]; then
        mkdir -p /etc/xdg/autostart
        cp -v "${desktopSrc}" "${desktopDest}"
        chmod 644 "${desktopDest}"
        echo "Rotation autostart installed"
    fi

    # Also add to LightDM session setup for login screen rotation
    local lightdmScript="/etc/lightdm/lightdm.conf.d/50-smartpad-rotate.conf"
    mkdir -p /etc/lightdm/lightdm.conf.d
    cat > "${lightdmScript}" << 'EOF'
[Seat:*]
display-setup-script=/usr/local/bin/smartpad-rotate.sh
EOF
    chmod 644 "${lightdmScript}"
    echo "LightDM rotation configured"

    echo "SmartPad rotation script ... [DONE]"
}

enableDesktopLogin() {
    # Armbian enables the display manager from its first-login wizard, once the
    # user exists; its cloud-init extension removes that wizard, so the desktop
    # images booted to a text console with lightdm never started. lightdm is
    # the display manager from the start, and smartpi-desktop-session decides
    # before each start until a desktop account is set: a card flashed as-is
    # (still pi / yumi) opens the SmartPi first-boot wizard (root password,
    # user, its password and real name in the order of Armbian's first login,
    # then language, keyboard, time zone, WiFi), a card set up with Raspberry
    # Pi Imager opens the desktop of its account. Either way the desktop then
    # opens without a login prompt, as on Raspberry Pi OS.
    echo "Enable the desktop login and the first-boot wizard ..."
    if [[ ! -x /usr/sbin/lightdm ]]; then
        echo "WARNING: lightdm is not installed, the desktop stays off"
        return 0
    fi
    # what the wizard runs on: GTK 3 from Python, the on-screen keyboard, xrandr/xset/xwininfo;
    # gir1.2-atspi-2.0, only recommended by onboard, is what lets it open on a touched text field
    apt-get install -y --no-install-recommends python3-gi gir1.2-gtk-3.0 onboard gir1.2-atspi-2.0 \
        x11-xserver-utils x11-utils
    ln -sfv /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service
    local src=/tmp/overlay/firstboot-wizard
    install -D -m 755 "${src}/firstboot-wizard" /usr/local/lib/smartpi/firstboot-wizard
    install -d /usr/share/smartpi/firstboot && cp -v "${src}"/assets/*.svg /usr/share/smartpi/firstboot/
    install -m 755 "${src}/smartpi-firstboot-apply" "${src}/smartpi-desktop-session" /usr/local/sbin/
    install -m 644 "${src}/smartpi-desktop-session.service" /etc/systemd/system/
    install -m 644 "${src}/smartpi-setup.desktop" /usr/share/xsessions/
    # the wizard's session runs as this system user; root only for applying the result
    local groups
    groups=$(for g in video audio netdev; do getent group "${g}" > /dev/null && printf '%s,' "${g}"; done)
    useradd --system --create-home --home-dir /var/lib/smartpi-setup --shell /bin/bash \
        ${groups:+--groups "${groups%,}"} smartpi-setup
    echo "smartpi-setup ALL=(root) NOPASSWD: /usr/local/sbin/smartpi-firstboot-apply" > /etc/sudoers.d/smartpi-setup
    chmod 440 /etc/sudoers.d/smartpi-setup
    visudo -c -f /etc/sudoers.d/smartpi-setup
    systemctl enable smartpi-desktop-session.service
    echo "Enable the desktop login and the first-boot wizard ... [DONE]"
}

installHdmiHotplug() {
    # X switches the screen off when it finds no monitor at start and never
    # turns it back on: a screen switched off and on, or the half second the H3
    # HDMI drops its hotplug line each time X starts (end of the first-boot
    # wizard, log out, switch user: 3 starts out of 6 on a SmartPi), and the
    # picture never comes back. The handler turns it back on at each hotplug.
    echo "Install the HDMI hotplug handler ..."
    install -m 755 /tmp/overlay/smartpi-hdmi-hotplug /usr/local/sbin/
    install -m 644 /tmp/overlay/90-smartpi-hdmi-hotplug.rules /etc/udev/rules.d/
    echo "Install the HDMI hotplug handler ... [DONE]"
}

setUpTouchScreen() {
    # A finger on the desktop: the on-screen keyboard on the login and lock
    # screen and, in the desktop, opening by itself on a touched text field;
    # a tap opens the panel menus like a click; a double tap opens a folder.
    echo "Set up the desktop for a touchscreen ..."
    install -m 644 /tmp/overlay/90_smartpi-touch.gschema.override /usr/share/glib-2.0/schemas/
    glib-compile-schemas /usr/share/glib-2.0/schemas
    install -m 644 /tmp/overlay/60smartpi-touch /etc/X11/Xsession.d/
    # Enter validates the login screen's password and the wizard's fields with Shift locked
    local user home owner
    for user in lightdm smartpi-setup; do
        home=$(getent passwd "${user}" | cut -d: -f6) || continue
        owner=(-o "${user}" -g "$(id -gn "${user}")")
        install -d "${owner[@]}" "${home}/.config" "${home}/.config/gtk-3.0"
        install -m 644 "${owner[@]}" /tmp/overlay/gtk-enter.css "${home}/.config/gtk-3.0/gtk.css"
    done
    # the web pages tell the on-screen keyboard about a touched field too
    if [[ -d /etc/chromium.d ]]; then
        install -m 644 /tmp/overlay/smartpi-onscreen-keyboard.chromium /etc/chromium.d/smartpi-onscreen-keyboard
    fi
    # two taps of a finger land further apart than two clicks (5 px)
    local xsettings=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
    if [[ -f "${xsettings}" ]]; then
        sed -i -E 's|(name="DoubleClickTime" type="int" value=)"[0-9]+"|\1"500"|
                   s|(name="DoubleClickDistance" type="int" value=)"[0-9]+"|\1"24"|' "${xsettings}"
        grep DoubleClick "${xsettings}"
    fi
    # lock and switch user in the user menu of the panel, which Armbian hides
    local panel=/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
    if [[ -f "${panel}" ]]; then
        sed -i -E 's/value="-(lock-screen|switch-user)"/value="+\1"/
                   0,/value="-separator"/ s/value="-separator"/value="+separator"/' "${panel}"
        grep -E 'lock-screen|switch-user' "${panel}"
    fi
    echo "Set up the desktop for a touchscreen ... [DONE]"
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
    if [[ -f "${conf}" ]]; then
        sed -i '/OnlyShowIn/s/^/# /' "${conf}"
        # on every screen, hidden until a text field is touched or its floating icon is
        install -m 755 /tmp/overlay/smartpi-onboard /usr/local/bin/
        sed -i 's|^Exec=.*|Exec=/usr/local/bin/smartpi-onboard|' "${conf}"
    else
        echo "WARNING: ${conf} not found (is the onboard package installed?)"
    fi
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


installChromiumFlags() {
    # Chromium's GPU process cannot create a usable GL context on the
    # Mali400 (lima is GLES2-only): the viz process dies and windows
    # render white. LIBGL_ALWAYS_SOFTWARE=1 hands it a Mesa software
    # context instead (validated on hardware). Also drop Armbian's
    # AcceleratedVideoDecoder flags meant for SBCs with an exposed VPU
    # (the H3 has none here). Noble is not affected: its xtradeb
    # chromium renders fine and keeps its stock configuration.
    echo "Install Chromium software-GL environment ..."
    mkdir -p /etc/chromium.d
    cp -v /tmp/overlay/yumi-mali-softgl /etc/chromium.d/yumi-mali-softgl
    rm -f /etc/chromium.d/armbian-flags
    echo "Install Chromium software-GL environment ... [DONE]"
}

installCloudInitDefaults() {
    # Armbian's cloud-init extension (ENABLE_EXTENSIONS in config-default.conf)
    # ships a /boot/user-data that only sets a hostname, and disables the
    # interactive first-login wizard: flashed as-is, the image would boot
    # with no user account. Ship one that creates pi / yumi and sets root /
    # yumi, in plain text so anyone can change them from a computer before
    # the first boot (it blanks them once applied), and a network-config with
    # a ready WiFi block, in the exact format Raspberry Pi OS ships and
    # Raspberry Pi Imager writes. Imager replaces both when the flash is
    # customized; the default user gives its account the board's groups.
    # Armbian's user-data.template creates an "armbian" user with an SSH key
    # and resizes an LVM volume: copied by mistake it locks people out.
    echo "Install cloud-init first-boot files ..."
    cp -v /tmp/overlay/cloud-init-user-data /boot/user-data
    cp -v /tmp/overlay/cloud-init-network-config /boot/network-config
    if [[ "${RELEASE}" == "bullseye" ]]; then
        # Debian 11's cloud-init 20.4 cannot apply network-config here: it
        # rejected the Raspberry Pi OS format ("failed stage init-local"), and
        # once reformatted it rendered eth0 for ifupdown, which fails at boot
        # without a cable, never picks one up later and cannot do WiFi (no
        # NetworkManager renderer before cloud-init 22.3). NetworkManager keeps
        # the network, as on the other images; no network-config on this
        # release.
        printf 'network:\n  config: disabled\n' > /etc/cloud/cloud.cfg.d/99-smartpi-network.cfg
        rm -fv /boot/network-config
    fi
    cp -v /tmp/overlay/cloud-init-default-user.cfg /etc/cloud/cloud.cfg.d/90-smartpi-default-user.cfg
    chmod 644 /boot/user-data /boot/network-config
    rm -fv /boot/user-data.template
    echo "Install cloud-init first-boot files ... [DONE]"
}

Main "$@"
