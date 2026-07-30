#!/usr/bin/env bash
# Patch the Armbian framework so Debian 14 desktop images can install the
# NetworkManager applet.
#
# Debian 14 (forky) renamed network-manager-gnome to network-manager-applet.
# Two places still ask for the old name:
#
#   1. armbian/build's net-network-manager extension — handled cleanly by
#      userpatches/extensions/net-network-manager.sh (userpatches win over
#      the built-in extensions).
#   2. The desktop package lists shipped INSIDE the armbian-config .deb,
#      which is installed in the chroot and then run to install the desktop.
#      The configng git clone the framework makes only feeds the DE picker
#      and the cache hash, so patching it changes nothing here.
#
# This script addresses (2): it inserts a release-guarded rename into
# rootfs-create.sh, between the armbian-config install and the call that
# uses those lists — the only window where the files exist and are unused.
# The inserted code runs on the build host against ${SDCARD} (no chroot
# quoting), finds the files itself instead of hardcoding a packaging path,
# and warns if it finds none (which is what we expect once configng ships
# the fix upstream: see Yumi-Lab/configng branch forky-nm-applet).
#
# Usage: fix-nm-applet-in-framework.sh <path to the armbian build tree>
# Idempotent: running it twice is a no-op.

set -euo pipefail

BUILD_DIR="${1:?usage: $0 <armbian build dir>}"
TARGET="${BUILD_DIR}/lib/functions/rootfs/rootfs-create.sh"

[[ -f "${TARGET}" ]] || { echo "not found: ${TARGET}" >&2; exit 1; }

python3 - "${TARGET}" <<'PY'
import sys

path = sys.argv[1]
src = open(path).read()

marker = 'Yumi: renaming the NM applet package'
if marker in src:
    print('already patched, nothing to do')
    sys.exit(0)

anchor = '\t\tchroot_sdcard_apt_get_install armbian-config\n'
if anchor not in src:
    sys.exit('anchor not found: the armbian-config install line moved, '
             'this patch needs to be revisited')

block = '''\t\t# Yumi: Debian 14 renamed network-manager-gnome to network-manager-applet,
\t\t# but the armbian-config package still lists the old name in its desktop
\t\t# package lists. Rename it in the copy that lives in the rootfs.
\t\tif [[ "${RELEASE}" == "forky" ]]; then
\t\t\tdeclare -a yumi_nm_yamls=()
\t\t\tmapfile -t yumi_nm_yamls < <(grep -rl network-manager-gnome "${SDCARD}/usr/share" --include='*.yaml' 2> /dev/null || true)
\t\t\tif [[ ${#yumi_nm_yamls[@]} -gt 0 ]]; then
\t\t\t\tdisplay_alert "Yumi: renaming the NM applet package in desktop lists" "${#yumi_nm_yamls[@]} file(s)" "info"
\t\t\t\trun_host_command_logged sed -i 's/network-manager-gnome/network-manager-applet/g' "${yumi_nm_yamls[@]}"
\t\t\telse
\t\t\t\tdisplay_alert "Yumi: no network-manager-gnome reference in the rootfs yaml" "fixed upstream?" "wrn"
\t\t\tfi
\t\tfi
'''

open(path, 'w').write(src.replace(anchor, anchor + block, 1))
print('rootfs-create.sh patched (Debian 14 NM applet rename)')
PY
