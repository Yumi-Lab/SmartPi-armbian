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

    # TODO: First-boot config system disabled for now (not working)
    # Re-enable when fixed
    # installFirstBootConfig

    case "${BOARD}" in
        smartpi1)
            installSmartpadDetection
            installUsbGadgetNet
            disableSimpledrm
            forceUniversalVideoMode
            installOverclockControl
            if [[ "${BUILD_DESKTOP}" = "yes" ]]; then
                installRotationScript
                patchLightdm
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
    local bootcfg="/boot/armbianEnv.txt"
    if grep -q "^extraargs=" "${bootcfg}" 2>/dev/null; then
        sed -i "s|^extraargs=\(.*\)|extraargs=\1 module_blacklist=simpledrm|" "${bootcfg}"
    else
        echo "extraargs=module_blacklist=simpledrm" >> "${bootcfg}"
    fi
    grep "^extraargs=" "${bootcfg}"
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
    local bootcfg="/boot/armbianEnv.txt"
    if grep -q "^extraargs=" "${bootcfg}" 2>/dev/null; then
        sed -i "s|^extraargs=\(.*\)|extraargs=\1 video=HDMI-A-1:1280x720@60|" "${bootcfg}"
    else
        echo "extraargs=video=HDMI-A-1:1280x720@60" >> "${bootcfg}"
    fi
    grep "^extraargs=" "${bootcfg}"
    echo "Force universal 720p video mode ... [DONE]"
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
    if [[ -f "${conf}" ]]; then
        sed -i '/OnlyShowIn/s/^/# /' "${conf}"
        # Start the on-screen keyboard only when the SmartPad touchscreen is present
        sed -i 's|^Exec=.*|Exec=sh -c "/usr/local/bin/smartpad-detect.sh \&\& exec onboard"|' "${conf}"
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

installFirstBootConfig() {
    echo "Installing SmartPi first-boot configuration system ..."

    # Install the config template to /boot
    local configSrc="/tmp/overlay/smartpi-config.txt"
    local configDest="/boot/smartpi-config.txt"
    if [[ -f "${configSrc}" ]]; then
        cp -v "${configSrc}" "${configDest}"
        # Set default hostname in config based on board name
        sed -i "s/^HOSTNAME=.*/HOSTNAME=${BOARD}/" "${configDest}"
        chmod 644 "${configDest}"
        echo "Config template installed to ${configDest} with HOSTNAME=${BOARD}"
    fi

    # Install the first-boot script
    local scriptSrc="/tmp/overlay/smartpi-firstboot.sh"
    local scriptDest="/usr/local/bin/smartpi-firstboot.sh"
    if [[ -f "${scriptSrc}" ]]; then
        cp -v "${scriptSrc}" "${scriptDest}"
        chmod 755 "${scriptDest}"
        echo "First-boot script installed to ${scriptDest}"
    fi

    # Install the systemd service
    local serviceSrc="/tmp/overlay/smartpi-firstboot.service"
    local serviceDest="/etc/systemd/system/smartpi-firstboot.service"
    if [[ -f "${serviceSrc}" ]]; then
        cp -v "${serviceSrc}" "${serviceDest}"
        chmod 644 "${serviceDest}"
        # Enable the service
        systemctl enable smartpi-firstboot.service
        echo "First-boot service installed and enabled"
    fi

    echo "SmartPi first-boot configuration system ... [DONE]"
}

Main "$@"
