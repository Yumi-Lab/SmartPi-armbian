#
# Yumi override of armbian/build extensions/network/net-network-manager.sh
# (userpatches/extensions is searched before the built-in extensions).
# Single change: Debian 14 (forky) renamed the NetworkManager applet
# package network-manager-gnome to network-manager-applet, which made
# every forky desktop build fail with "no installation candidate".
# The config-nm/ directory next to this file mirrors the upstream one,
# since EXTENSION_DIR points here when the override is picked up.
#
# Extension to manage network interfaces with NetworkManager + Netplan
#
function extension_prepare_config__install_network_manager() {
	# Sanity check
	if [[ "${NETWORKING_STACK}" != "network-manager" ]]; then
		exit_with_error "Extension: ${EXTENSION}: requires NETWORKING_STACK='network-manager', currently set to '${NETWORKING_STACK}'"
	fi

	display_alert "Extension: ${EXTENSION}: Adding extra packages to image" "network-manager network-manager-openvpn netplan.io" "info"
	add_packages_to_image network-manager network-manager-openvpn netplan.io

	if [[ "${BUILD_DESKTOP}" == "yes" ]]; then
		# Debian renamed the applet package in forky (Debian 14)
		local nm_applet="network-manager-gnome"
		case "${RELEASE}" in
			forky) nm_applet="network-manager-applet" ;;
		esac
		display_alert "Extension: ${EXTENSION}: Adding extra packages for desktop to image" "${nm_applet} network-manager-ssh network-manager-vpnc" "info"
		add_packages_to_image "${nm_applet}" network-manager-ssh network-manager-vpnc
	fi

	if [[ "${DISTRIBUTION}" == "Ubuntu" ]]; then
		display_alert "Extension: ${EXTENSION}: Adding extra packages for Ubuntu to image" "network-manager-config-connectivity-ubuntu" "info"
		add_packages_to_image network-manager-config-connectivity-ubuntu
	fi
}

function pre_install_kernel_debs__configure_network_manager() {
	display_alert "Extension: ${EXTENSION}: Enabling Network-Manager" "" "info"

	# Enable resolved
	# Very likely not needed to enable manually since resolved is enabled by default
	# NetworkManager can use systemd-resolved as a DNS resolver and cache.
	# systemd-resolved will be used automatically if /etc/resolv.conf is a symlink to /run/systemd/resolve/stub-resolv.conf (source: https://wiki.archlinux.org/title/NetworkManager)
	chroot_sdcard systemctl enable systemd-resolved.service || display_alert "Failed to enable systemd-resolved.service" "" "wrn"

	# We can't disable/mask systemd-networkd.service since it is required by Netplan
	# There shouldn't be any conflicts since Netplan is configured in such a way that NetworkManager manages all network devices

	# Most likely we don't need to wait for nm to get online
	chroot_sdcard systemctl disable NetworkManager-wait-online.service

	# Copy network config files into the appropriate folders
	display_alert "Configuring" "NetworkManager and Netplan" "info"
	local netplan_config_src_folder="${EXTENSION_DIR}/config-nm/netplan/"
	local netplan_config_dst_folder="${SDCARD}/etc/netplan/"

	local network_manager_config_src_folder="${EXTENSION_DIR}/config-nm/NetworkManager/"
	local network_manager_config_dst_folder="${SDCARD}/etc/NetworkManager/conf.d/"

	run_host_command_logged cp -v "${netplan_config_src_folder}"* "${netplan_config_dst_folder}"
	run_host_command_logged cp -v "${network_manager_config_src_folder}"* "${network_manager_config_dst_folder}"

	# Change the file permissions according to https://netplan.readthedocs.io/en/stable/security/
	chmod -v 600 "${SDCARD}"/etc/netplan/*
}
