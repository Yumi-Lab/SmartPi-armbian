#!/bin/bash
# Install H3 overclock overlay on a running SmartPi One
# Run as root on the target device
set -euo pipefail

OVERLAY_SRC="/usr/share/smartpi/sun8i-h3-overclock-experimental.dts"
OVERLAY_DIR="/boot/dtb/overlay"
OVERLAY_NAME="sun8i-h3-overclock-experimental"
ENV_FILE="/boot/armbianEnv.txt"

echo "=== H3 Experimental Overclock Installer ==="
echo ""
echo "WARNING: This overclocks the CPU beyond Allwinner specifications."
echo "  - 1368 MHz @ 1.40V"
echo "  - 1488 MHz @ 1.44V"
echo "  - 1512 MHz @ 1.46V"
echo ""
echo "Requirements:"
echo "  - Heatsink + active fan"
echo "  - AXP209 PMIC capable of 1.46V on VDD-CPUX"
echo ""
read -rp "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 0

# Compile overlay
if ! command -v dtc &>/dev/null; then
    echo "Installing device-tree-compiler..."
    apt-get update && apt-get install -y device-tree-compiler
fi

echo "Compiling overlay..."
dtc -@ -I dts -O dtb -o "${OVERLAY_DIR}/${OVERLAY_NAME}.dtbo" "$OVERLAY_SRC"

# Add to armbianEnv.txt
if grep -q "user_overlays=.*${OVERLAY_NAME}" "$ENV_FILE" 2>/dev/null; then
    echo "Overlay already in ${ENV_FILE}"
else
    if grep -q "^user_overlays=" "$ENV_FILE" 2>/dev/null; then
        # Append to existing user_overlays line
        sed -i "s/^user_overlays=\(.*\)/user_overlays=\1 ${OVERLAY_NAME}/" "$ENV_FILE"
    else
        echo "user_overlays=${OVERLAY_NAME}" >> "$ENV_FILE"
    fi
    echo "Added overlay to ${ENV_FILE}"
fi

echo ""
echo "Done. Reboot to apply."
echo ""
echo "After reboot, verify with:"
echo "  cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"
echo "  cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies"
echo ""
echo "To set max frequency manually:"
echo "  echo 1488000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
