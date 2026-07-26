#!/bin/sh
# Configure the USB network gadget (g_ether on the OTG port).
# The board gets a fixed address; the computer plugged into the OTG port can
# reach it at 172.22.1.1 (set 172.22.1.2/24 on the host side), or via IPv6
# link-local without any configuration.

TRIES=30

i=0
while [ "${i}" -lt "${TRIES}" ]; do
    if [ -d /sys/class/net/usb0 ]; then
        ip link set usb0 up
        ip addr replace 172.22.1.1/24 dev usb0
        echo "usb-gadget-net: usb0 up at 172.22.1.1/24"
        exit 0
    fi
    i=$((i + 1))
    sleep 1
done

echo "usb-gadget-net: usb0 never appeared (gadget not active?)"
exit 0
