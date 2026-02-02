#!/bin/bash
# SmartPad Display Rotation Script
# Rotates display and touch input 180 degrees
# Compatible with Debian 11, 12, and 13

# Wait for display to be available
sleep 2

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
# Find touch device
TOUCH_DEVICE=$(xinput list --name-only 2>/dev/null | grep -i "touch" | head -n1)

if [ -n "$TOUCH_DEVICE" ]; then
    echo "Rotating touch input: $TOUCH_DEVICE"
    # Transformation matrix for 180 degree rotation: [-1 0 1 0 -1 1 0 0 1]
    xinput set-prop "$TOUCH_DEVICE" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1 2>/dev/null || true
fi

# Try common touch device names
for DEVICE in "goodix-ts" "Goodix Capacitive TouchScreen" "ft5x06" "silead_ts"; do
    xinput set-prop "$DEVICE" "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1 2>/dev/null || true
done

echo "SmartPad rotation applied"
