#!/usr/bin/env bash
# Patch the Armbian framework so Debian 14 desktop images find every package
# the armbian-config desktop lists ask for. Debian 14 (forky) moved three of
# them, as of 2026-10:
#
#   network-manager-gnome  renamed network-manager-applet
#   evince                 dropped from testing; atril is its GTK3 fork,
#                          which MATE already ships and the XFCE theme fits
#   chromium (armhf)       armhf build removed (Debian #1148256, FTBFS);
#                          firefox-esr, configng's own pick where chromium
#                          is missing (riscv64)
#
# The old names are asked for in two places:
#
#   1. armbian/build's net-network-manager extension (NM applet only) —
#      handled cleanly by userpatches/extensions/net-network-manager.sh
#      (userpatches win over the built-in extensions).
#   2. The desktop package lists shipped INSIDE the armbian-config .deb,
#      which is installed in the chroot and then run to install the desktop.
#      The configng git clone the framework makes only feeds the DE picker
#      and the cache hash, so patching it changes nothing here.
#
# This script addresses (2): it inserts a release-guarded rewrite into
# rootfs-create.sh, between the armbian-config install and the call that
# uses those lists — the only window where the files exist and are unused.
# The inserted code runs on the build host against ${SDCARD} (no chroot
# quoting), finds the files itself instead of hardcoding a packaging path,
# and warns if it finds none (which is what we expect once configng ships
# the fixes upstream: see Yumi-Lab/configng branch forky-nm-applet).
# The chromium swap is confined to the forky block of configng's browser:
# table, so the other releases keep chromium.
#
# Usage: fix-forky-desktop-in-framework.sh <path to the armbian build tree>
# Idempotent: running it twice is a no-op.

set -euo pipefail

BUILD_DIR="${1:?usage: $0 <armbian build dir>}"
TARGET="${BUILD_DIR}/lib/functions/rootfs/rootfs-create.sh"

[[ -f "${TARGET}" ]] || { echo "not found: ${TARGET}" >&2; exit 1; }

python3 - "${TARGET}" <<'PY'
import sys

path = sys.argv[1]
src = open(path).read()

marker = 'Yumi: Debian 14 package moves'
if marker in src:
    print('already patched, nothing to do')
    sys.exit(0)

anchor = '\t\tchroot_sdcard_apt_get_install armbian-config\n'
if anchor not in src:
    sys.exit('anchor not found: the armbian-config install line moved, '
             'this patch needs to be revisited')

block = '''\t\t# Yumi: Debian 14 package moves the armbian-config desktop lists do not
\t\t# know about yet (see tools/fix-forky-desktop-in-framework.sh). Rewrite
\t\t# them in the copy that lives in the rootfs.
\t\tif [[ "${RELEASE}" == "forky" ]]; then
\t\t\tdeclare -a yumi_forky_yamls=()
\t\t\tmapfile -t yumi_forky_yamls < <(grep -rlE 'network-manager-gnome|^\\s*- evince\\s*$|^\\s*armhf:\\s*chromium' "${SDCARD}/usr/share" --include='*.yaml' 2> /dev/null || true)
\t\t\tif [[ ${#yumi_forky_yamls[@]} -gt 0 ]]; then
\t\t\t\tdisplay_alert "Yumi: Debian 14 package moves in desktop lists" "${#yumi_forky_yamls[@]} file(s)" "info"
\t\t\t\trun_host_command_logged sed -i \\
\t\t\t\t\t-e "'s/network-manager-gnome/network-manager-applet/g'" \\
\t\t\t\t\t-e "'s/^\\(\\s*- \\)evince\\s*$/\\1atril/'" \\
\t\t\t\t\t-e "'/^  forky:/,/^  [a-z]/ s/^\\(\\s*armhf:\\s*\\)chromium\\b/\\1firefox-esr/'" \\
\t\t\t\t\t"${yumi_forky_yamls[@]}"
\t\t\telse
\t\t\t\tdisplay_alert "Yumi: no Debian 14 package move left in the rootfs yaml" "fixed upstream?" "wrn"
\t\t\tfi
\t\tfi
'''

open(path, 'w').write(src.replace(anchor, anchor + block, 1))
print('rootfs-create.sh patched (Debian 14 package moves)')
PY
