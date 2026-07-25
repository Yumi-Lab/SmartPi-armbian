#!/bin/bash
# SmartPad X11 rotation script
# Rotates display and touch input 180 degrees and disables screen blanking,
# ONLY when the SmartPad built-in screen is detected (800x480 + touchscreen).
# On a normal HDMI monitor this exits immediately without touching anything.
# Compatible with Debian 11, 12, and 13

# Fast exit on normal monitors: once X is up the DRM resolution is known
# immediately, so this adds no delay to the greeter on a regular screen.
/usr/local/bin/smartpad-detect.sh --screen-only || exit 0

# 800x480 panel present — wait for the USB touchscreen to enumerate before
# deciding (it can come up a few seconds after X starts).
DETECTED=0
for _ in $(seq 1 10); do
    if /usr/local/bin/smartpad-detect.sh; then
        DETECTED=1
        break
    fi
    sleep 1
done
[ "$DETECTED" = "1" ] || exit 0

# Find the primary output
PRIMARY_OUTPUT=$(xrandr --query 2>/dev/null | grep " connected" | head -n1 | cut -d' ' -f1)

if [ -n "$PRIMARY_OUTPUT" ]; then
    echo "Rotating display: $PRIMARY_OUTPUT"
    xrandr --output "$PRIMARY_OUTPUT" --rotate inverted 2>/dev/null || true
fi

# Also try common output names
for OUTPUT in DSI-1 HDMI-1 HDMI-A-1 DPI-1 default; do
    xrandr --output "$OUTPUT" --rotate inverted 2>/dev/null || true
done

# Rotate touch input using xinput
# Primary method: rotate every udev-tagged touchscreen, using the kernel
# device name (X registers input devices under the same name). This does not
# depend on the device name containing "touch".
for dev in /dev/input/event*; do
    [ -e "$dev" ] || continue
    if udevadm info --query=property --name="$dev" 2>/dev/null | grep -q "^ID_INPUT_TOUCHSCREEN=1"; then
        TS_NAME=$(cat "/sys/class/input/$(basename "$dev")/device/name" 2>/dev/null)
        if [ -n "$TS_NAME" ]; then
            echo "Rotating touch input: $TS_NAME"
            # Transformation matrix for 180 degree rotation: [-1 0 1 0 -1 1 0 0 1]
            xinput set-prop "$TS_NAME" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1 2>/dev/null || true
        fi
    fi
done

# Fallback: name-based heuristic
TOUCH_DEVICE=$(xinput list --name-only 2>/dev/null | grep -i "touch" | head -n1)

if [ -n "$TOUCH_DEVICE" ]; then
    xinput set-prop "$TOUCH_DEVICE" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1 2>/dev/null || true
fi

# Try common touch device names
for DEVICE in "goodix-ts" "Goodix Capacitive TouchScreen" "ft5x06" "silead_ts"; do
    xinput set-prop "$DEVICE" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1 2>/dev/null || true
done

# Kiosk behavior on the pad: no screen blanking, no DPMS
xset s off -dpms 2>/dev/null || true

echo "SmartPad rotation applied"
