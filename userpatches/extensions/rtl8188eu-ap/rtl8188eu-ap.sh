#!/usr/bin/env bash
#
# Realtek's 8188eu driver for RTL8188EUS USB WiFi dongles (0bda:8179 and kin),
# so they can also run as an access point: nmcli device wifi hotspot ...
#
# Mainline hands these dongles to rtl8xxxu, which only does managed and monitor
# mode for the 8188E (AP support is still an RFC on lkml). Armbian's own
# driver_rtl8188EU_rtl8188ETV() only grafts 8188eu onto kernels older than 5.15,
# so EXTRAWIFI no longer adds it to our 6.12 and 6.18.
#
# Built in-tree as an ordinary module, shipped in linux-image: no DKMS, nothing
# compiled on the board. Modelled on armbian's sophgo-sg200x-aic8800 extension.
# The copy happens from custom_kernel_config, not kernel_copy_extra_sources:
# patching does a git reset --hard plus a clean of untracked files, so anything
# staged earlier is wiped.
#
# Nothing here sets up an access point: the dongle stays a normal WiFi client.

declare -g RTL8188EU_REPO="https://github.com/SimplyCEO/rtl8188eus"
# Pinned; a mutable branch ref would break kernel build caching. 2026-07-07,
# builds up to 7.1 (aircrack-ng/rtl8188eus still lacks recent kernels, PR #275).
declare -g RTL8188EU_REF="commit:b5f02e742fad6ae27d893ffae62d05e27374c0ed"
declare -g RTL8188EU_MODULE="8188eu"

function custom_kernel_config__rtl8188eu_ap() {
	# The fixes that make the pinned driver build in-tree on 6.12 and 6.18 (see
	# each patch's message). Written against the driver repo, applied to the copy.
	declare -a patches=()
	mapfile -t patches < <(find "${EXTENSION_DIR}" -maxdepth 1 -name '*.patch' | sort)

	# Rebuild the kernel when the driver revision or the patches change.
	kernel_config_modifying_hashes+=("rtl8188eu_ap=${RTL8188EU_REF}")
	kernel_config_modifying_hashes+=("rtl8188eu_ap_patches=$(cat /dev/null "${patches[@]}" | sha256sum | cut -d' ' -f1)")

	# Also called during version calculation, with no kernel tree.
	[[ ! -f .config ]] && return 0

	# fetch_from_repo changes directory; the rest works relative to the kernel tree.
	declare kernel_cwd="${PWD}"
	fetch_from_repo "${RTL8188EU_REPO}" "rtl8188eus-simplyceo" "${RTL8188EU_REF}" "yes"
	cd "${kernel_cwd}" || exit_with_error "rtl8188eu" "could not return to ${kernel_cwd}"

	declare src_dir="${SRC}/cache/sources/rtl8188eus-simplyceo/${RTL8188EU_REF#*:}"
	declare wireless_dir="${kernel_work_dir}/drivers/net/wireless"
	declare driver_dir="${wireless_dir}/rtl8188eu"

	display_alert "rtl8188eu" "adding the ${RTL8188EU_MODULE} driver to the kernel tree" "info"
	run_host_command_logged rm -rf "${driver_dir}"
	run_host_command_logged mkdir -p "${driver_dir}"
	run_host_command_logged cp -a "${src_dir}"/{core,hal,include,os_dep,platform,Makefile,Kconfig} "${driver_dir}/"

	declare patch_file
	for patch_file in "${patches[@]}"; do
		display_alert "rtl8188eu" "applying $(basename "${patch_file}")" "info"
		run_host_command_logged patch --batch -p1 -d "${driver_dir}" "<" "${patch_file}" ||
			exit_with_error "rtl8188eu patch did not apply" "$(basename "${patch_file}")"
	done

	# Hook the driver into the wireless Kconfig and Makefile. olddefconfig drops a
	# symbol no Kconfig declares without a word, so make sure the source line landed.
	if ! grep -q "rtl8188eu/Kconfig" "${wireless_dir}/Kconfig"; then
		sed -i 's|^source "drivers/net/wireless/ti/Kconfig"|&\nsource "drivers/net/wireless/rtl8188eu/Kconfig"|' \
			"${wireless_dir}/Kconfig"
	fi
	grep -q "rtl8188eu/Kconfig" "${wireless_dir}/Kconfig" ||
		exit_with_error "rtl8188eu" "could not hook the driver into drivers/net/wireless/Kconfig"
	if ! grep -q "rtl8188eu/" "${wireless_dir}/Makefile"; then
		echo 'obj-$(CONFIG_RTL8188EU) += rtl8188eu/' >> "${wireless_dir}/Makefile"
	fi

	kernel_config_set_m CONFIG_RTL8188EU
}

# Both drivers match the RTL8188E USB IDs and the first one registered binds.
# softdep loads 8188eu ahead of rtl8xxxu, so 8188eu claims the IDs in its own
# table (the RTL8188E family only) and every other Realtek dongle stays with
# rtl8xxxu. A blacklist of rtl8xxxu would strand those other dongles.
function post_family_tweaks__rtl8188eu_ap_prefer_8188eu() {
	display_alert "rtl8188eu" "loading ${RTL8188EU_MODULE} ahead of rtl8xxxu" "info"
	echo "softdep rtl8xxxu pre: ${RTL8188EU_MODULE}" > "${SDCARD}/etc/modprobe.d/${RTL8188EU_MODULE}.conf"
}
