#!/usr/bin/env bash
#
# AICSemi AIC8800 USB WiFi 6 + Bluetooth dongles (sold as "WiFi 6 AX900,
# driver free"; lsusb 1111:1111 "88M80"), working as soon as they are plugged in.
#
# The dongle boots in three stages. It first shows up as a fake disk holding a
# Windows driver (1111:1111); a vendor SCSI command, sent by usb_modeswitch from
# a udev rule, switches it to its ROM (a69c:8d80), where aic_load_fw uploads the
# firmware. It then comes back as a69c:8d81: WiFi on aic8800_fdrv, Bluetooth on
# mainline btusb. It falls back to the fake disk at every power loss.
#
# Driver and firmware are Radxa's packaging of the vendor driver, pinned. The
# driver is built in-tree like rtl8188eu-ap: shipped in linux-image, no DKMS,
# nothing compiled on the board. Only aic_load_fw and aic8800_fdrv: Radxa's
# aic_btusb would race btusb for the Bluetooth interfaces. The firmware is
# Radxa's too: the older copy in armbian-firmware (/lib/firmware/aic8800) hangs
# the dongle right after the upload ("can't set config #1, error -110").

declare -g AIC8800_VERSION="5.0+git20260123.5f7be68d-9"
declare -g AIC8800_URL="https://github.com/radxa-pkg/aic8800/releases/download/${AIC8800_VERSION}"

# Extract the pinned Radxa package $1 into a fresh $2, downloading it into the cache first.
function aic8800_usb_extract() {
	declare deb="${SRC}/cache/aic8800-debs/${1}_${AIC8800_VERSION}_all.deb"
	if [[ ! -f "${deb}" ]]; then
		run_host_command_logged mkdir -p "${deb%/*}"
		run_host_command_logged wget --no-verbose --output-document="${deb}.tmp" "${AIC8800_URL}/${deb##*/}" ||
			exit_with_error "aic8800" "could not download ${deb##*/}"
		run_host_command_logged mv "${deb}.tmp" "${deb}"
	fi
	run_host_command_logged rm -rf "${2}"
	run_host_command_logged dpkg-deb -x "${deb}" "${2}"
}

function custom_kernel_config__aic8800_usb() {
	# Rebuild the kernel when the driver version changes.
	kernel_config_modifying_hashes+=("aic8800_usb=${AIC8800_VERSION}")

	# Also called during version calculation, with no kernel tree.
	[[ ! -f .config ]] && return 0

	declare src_dir="${SRC}/cache/aic8800-src"
	aic8800_usb_extract aic8800-usb-dkms "${src_dir}"
	declare wireless_dir="${kernel_work_dir}/drivers/net/wireless"
	declare driver_dir="${wireless_dir}/aic8800"

	display_alert "aic8800" "adding aic_load_fw and aic8800_fdrv to the kernel tree" "info"
	run_host_command_logged rm -rf "${driver_dir}"
	run_host_command_logged cp -a "${src_dir}"/usr/src/aic8800-usb-*/USB/driver_fw/drivers/aic8800 "${driver_dir}"

	# The vendor Makefile already builds both modules as m; one Kconfig symbol gates the directory.
	cat <<- KCONFIG > "${driver_dir}/Kconfig"
		config AIC8800_USB
			tristate "AICSemi AIC8800 USB WiFi 6 (Radxa packaging of the vendor driver)"
			depends on USB && CFG80211
	KCONFIG

	# olddefconfig drops a symbol no Kconfig declares without a word, so make sure the source line landed.
	if ! grep -q "aic8800/Kconfig" "${wireless_dir}/Kconfig"; then
		sed -i 's|^source "drivers/net/wireless/ti/Kconfig"|&\nsource "drivers/net/wireless/aic8800/Kconfig"|' \
			"${wireless_dir}/Kconfig"
	fi
	grep -q "aic8800/Kconfig" "${wireless_dir}/Kconfig" ||
		exit_with_error "aic8800" "could not hook the driver into drivers/net/wireless/Kconfig"
	if ! grep -q "aic8800/" "${wireless_dir}/Makefile"; then
		echo 'obj-$(CONFIG_AIC8800_USB) += aic8800/' >> "${wireless_dir}/Makefile"
	fi

	kernel_config_set_m CONFIG_AIC8800_USB
}

# usb_modeswitch sends the switch; bluez drives the Bluetooth half.
function extension_prepare_config__aic8800_usb_packages() {
	add_packages_to_image usb-modeswitch bluez
}

function post_family_tweaks__aic8800_usb() {
	declare fw_dir="${SRC}/cache/aic8800-fw"
	aic8800_usb_extract aic8800-firmware "${fw_dir}"
	# USB firmware only, in the folder the driver reads by default.
	display_alert "aic8800" "Radxa firmware in /lib/firmware/aic8800_fw/USB" "info"
	run_host_command_logged mkdir -p "${SDCARD}/lib/firmware/aic8800_fw"
	run_host_command_logged cp -a "${fw_dir}/lib/firmware/aic8800_fw/USB" "${SDCARD}/lib/firmware/aic8800_fw/"

	declare disk_vid="1111" disk_pid="1111"
	display_alert "aic8800" "udev switch out of the fake driver disk ${disk_vid}:${disk_pid}" "info"
	cat <<- RULE > "${SDCARD}/etc/udev/rules.d/90-aic8800.rules"
		# AIC8800 WiFi 6 + Bluetooth USB dongles first show up as a fake driver disk (${disk_vid}:${disk_pid});
		# a vendor SCSI command switches them. Written by the aic8800-usb extension.
		ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="${disk_vid}", ATTR{idProduct}=="${disk_pid}", RUN+="/usr/sbin/usb_modeswitch -v ${disk_vid} -p ${disk_pid} -M 555342431010ecd800000000000010fd0000000000000000000000000000f2"
	RULE
}
