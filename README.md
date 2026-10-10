<p align="center">
  <a href="https://www.yumi-lab.com">
    <img src="assets/logo_yumi.png" alt="Yumi Lab" width="200"/>
  </a>
</p>

# SmartPi-armbian

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Version](https://img.shields.io/badge/Version-1.8.0--rc6-green.svg)](https://github.com/Yumi-Lab/SmartPi-armbian/releases)
[![Build Images](https://github.com/Yumi-Lab/SmartPi-armbian/actions/workflows/BuildImages.yml/badge.svg)](https://github.com/Yumi-Lab/SmartPi-armbian/actions/workflows/BuildImages.yml)
[![Wiki](https://img.shields.io/badge/Wiki-Documentation-orange?logo=gitbook&logoColor=white)](https://wiki.yumi-lab.com)

Custom Armbian image builder for SmartPi devices by **[Yumi Lab](https://www.yumi-lab.com)**.

### Key features (since v1.7.0)

- **Instant boot logo** (since v1.8.0) — the Yumi logo is built into U-Boot and drawn centered the moment the video output initialises, before anything is read from the SD card
- **Works on any screen up to 4K UHD** (since v1.8.0) — display fixed at 1280x720@60, accepted and upscaled by every screen from the SmartPad panel to 4K monitors
- **H3 CPU overclock to 1368 MHz** (since v1.8.0) — explicit opt-in through `sudo smartpi-oc on` (stock 1296 MHz with the adaptive governor by default)
- **SSH over the USB OTG port** (since v1.8.0) — one cable powers the board and provides network access (NCM gadget: Linux, Windows 11, macOS)
- **Hardened against power cuts** — file systems are repaired automatically at boot (`fsck.repair=yes`, the Raspberry Pi OS default), a damaged FAT `/boot` cannot block the boot (`nofail`), the ext4 root runs in `data=ordered` with `errors=remount-ro` instead of Armbian's writeback default, a hang or a panic reboots by itself (`panic=10`, hardware watchdog), the journal stays in RAM, and `/boot/yumi-boot.log` records every unclean shutdown and repair, readable from any PC
- **Kernel headers pre-installed** — compile and load kernel modules directly on the board (WiFi drivers, DKMS modules) without a cross-compilation setup
- **Flash-time configuration** (since v1.8.0) — hostname, user, WiFi and SSH set from Raspberry Pi Imager's customization screen (cloud-init), or by editing `user-data` / `network-config` on the boot partition from any computer
- **12 images** built automatically for 6 distros (single `smartpi1` board, also used on SmartPad), flashable through Raspberry Pi Imager with the Yumi repository

## Table of Contents

- [Introduction](#introduction)
- [Supported Hardware](#supported-hardware)
- [Supported Distributions](#supported-distributions)
- [H3 CPU Overclock](#h3-cpu-overclock)
- [Image Naming Convention](#image-naming-convention)
- [First-Boot Configuration](#first-boot-configuration)
- [Raspberry Pi Imager](#raspberry-pi-imager)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Adding a New Distribution](#adding-a-new-distribution)
- [Contribution](#contribution)
- [License](#license)
- [Disclaimer](#disclaimer)
- [Contact](#contact)

## Introduction

SmartPi-armbian is a custom image builder for SmartPi devices, leveraging the Armbian operating system. This repository contains the tools and configurations necessary to create tailored Linux images for SmartPi hardware, with automated build processes.

## Supported Hardware

### SmartPi One
![SmartPi One](https://img.shields.io/badge/SmartPi_One-Allwinner_H3-orange?style=for-the-badge&logo=arm&logoColor=white)

| Specification | Value |
|---------------|-------|
| **SoC** | Allwinner H3 quad-core |
| **RAM** | 1GB |
| **Variants** | Server / Desktop |

### SmartPad
![SmartPad](https://img.shields.io/badge/SmartPad-Allwinner_H3-orange?style=for-the-badge&logo=arm&logoColor=white)

The SmartPad is a SmartPi One fitted with a 4.3" 800x480 HDMI touchscreen — it uses the **same `smartpi1` images**. The SmartPad screen is detected at runtime (800x480 resolution + touchscreen present) and the 180° rotation is applied automatically; on a normal HDMI monitor the display stays in its normal orientation.

| Specification | Value |
|---------------|-------|
| **SoC** | Allwinner H3 quad-core |
| **RAM** | 1GB |
| **Display** | 4.3" 800x480 touchscreen (auto-detected, auto-rotated 180°) |
| **Extras** | On-screen keyboard (Onboard, shown only when a touchscreen is detected) |
| **Variants** | Server / Desktop |

## Supported Distributions

### Debian
![Debian](https://img.shields.io/badge/Debian-A81D33?style=for-the-badge&logo=debian&logoColor=white)

| Codename | Version | Status |
|----------|---------|--------|
| ![Bullseye](https://img.shields.io/badge/Bullseye-Debian_11-A81D33?logo=debian&logoColor=white) | Debian 11 | Legacy (server only) |
| ![Bookworm](https://img.shields.io/badge/Bookworm-Debian_12-A81D33?logo=debian&logoColor=white) | Debian 12 | Oldstable |
| ![Trixie](https://img.shields.io/badge/Trixie-Debian_13-A81D33?logo=debian&logoColor=white) | Debian 13 | **Current Stable** |
| ![Forky](https://img.shields.io/badge/Forky-Debian_14-A81D33?logo=debian&logoColor=white) | Debian 14 | Testing preview (desktops ship Firefox ESR: Debian 14 no longer builds Chromium for armhf) |

### Ubuntu
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)

| Codename | Version | Status |
|----------|---------|--------|
| ![Jammy](https://img.shields.io/badge/Jammy-22.04_LTS-E95420?logo=ubuntu&logoColor=white) | Ubuntu 22.04 | LTS (server only) |
| ![Noble](https://img.shields.io/badge/Noble-24.04_LTS-E95420?logo=ubuntu&logoColor=white) | Ubuntu 24.04 | **Current LTS** |

## H3 CPU Overclock

By default the images run the stock frequency table — up to **1296 MHz** with the adaptive cpufreq governor. The **1368 MHz** overclock is an explicit opt-in through the `smartpi-oc` command:

```bash
sudo smartpi-oc on       # enable the overclock, then reboot
sudo smartpi-oc off      # back to stock, then reboot
sudo smartpi-oc status   # current state
```

After `smartpi-oc on` and a reboot, verify:

```bash
sudo smartpi-oc status
# overclock: on
# current max: 1368000 kHz
# governor:    performance
```

How it works: `smartpi-oc on` enables a device-tree overlay (`/boot/overlay-user/opp1368.dtbo`) that adds the 1368 MHz operating point, and boots with the `performance` governor so the CPU sits at 1368 MHz instead of hopping between frequencies. Rapid frequency transitions with the 1368 MHz point in the table are what used to hang boards during startup; a fixed frequency has months of stress-test validation behind it. The thermal throttle stays active at 85 C — a heatsink with active fan is recommended for sustained workloads.

| Mode | Max frequency | Governor |
|------|---------------|----------|
| default | 1296 MHz | adaptive (ondemand) |
| `smartpi-oc on` | 1368 MHz | performance |

Note on voltage: the SmartPi One has no software-controlled CPU regulator — VDD-CPUX is fixed by the board hardware, so the voltages listed in kernel OPP tables are never actually applied. 1368 MHz is stress-test validated on Yumi boards at that fixed voltage.

See [docs/H3-OVERCLOCK.md](docs/H3-OVERCLOCK.md) for technical details.

## Image Naming Convention

Every image name states its distribution, its version and — for desktop images — which desktop environment it ships, so a downloaded file is identifiable on its own.

```
{Vendor}-{board}-{codename}-{distro_version}-{variant}-{timestamp}.img.xz
```

| Field | Values |
|-------|--------|
| `variant` | `server`, or `desktop_<DE>` |
| `<DE>` | `XFCE`, `MATE`, `i3` — always present on desktop images |

**Examples:**
- `Yumi-smartpi1-bookworm-debian12-server-2026-02-02-1234.img.xz`
- `Yumi-smartpi1-trixie-debian13-desktop_XFCE-2026-02-02-1234.img.xz`
- `Yumi-smartpi1-trixie-debian13-desktop_i3-2026-02-02-1234.img.xz`
- `Yumi-smartpi1-forky-debian14-desktop_MATE-2026-02-02-1234.img.xz`

The name comes from the config file name (`configs/{board}-{codename}-{variant}.conf`) with the distribution version inserted, so naming a config correctly is enough to name its image correctly.

## Kernel Packages (DKMS)

Each release also ships the exact kernel/U-Boot `.deb` packages matching the
images (`linux-image`, `linux-headers`, `linux-dtb`, `linux-u-boot`), for both
kernel branches (`current` for Debian 12/13 & Ubuntu, `legacy` for Debian 11).
To build DKMS modules on the device, install the headers **from the release**,
not from apt.armbian.com (whose generic builds do not match this custom
kernel):

```bash
wget https://github.com/Yumi-Lab/SmartPi-armbian/releases/latest/download/linux-headers-current-sunxi_<version>.deb
sudo dpkg -i linux-headers-current-sunxi_<version>.deb
```

## SSH over USB (OTG)

The OTG port runs as a USB network gadget, so a single cable to a computer both
powers the board and carries the network. The board answers at `172.22.1.1`;
set `172.22.1.2/24` on the computer side, then:

```bash
ssh root@172.22.1.1
```

Note that unplugging the cable also cuts power. When running sustained
workloads at the 1368 MHz overclock, prefer a dedicated 5V/2A supply — a
computer's USB port may not deliver enough current.

## Boot Logo

The Yumi logo is built into the U-Boot binary and drawn centered on screen the
instant the video output initialises — no file is read from the SD card, so it
appears immediately at power-on and the boot console runs normally alongside
it. To change it, replace `userpatches/overlay/u-boot-logo.bmp` (8-bit
uncompressed BMP) and rebuild U-Boot with the "Build U-Boot only" workflow.

Legacy note: `boot.bmp` on the FAT partition is no longer displayed.

## Power Cuts and SD Cards

Boards get unplugged rather than shut down, so the images are hardened in place, without changing the partition layout:

- `fsck.repair=yes` on the kernel command line: the initramfs repairs the root file system instead of stopping on "requires a manual fsck"; systemd-fsck does the same for the FAT boot partition.
- `/boot` is mounted `nofail`: once the kernel is loaded, a damaged FAT partition does not block the boot.
- The ext4 root is set to `data=ordered` and `errors=remount-ro` in its superblock. Armbian builds every root in `data=writeback`, where a file written just before a power cut can come back filled with stale blocks.
- `panic=10` and the H3 hardware watchdog (16 s, pinged by systemd): a panic or a hang reboots the board instead of waiting forever.
- The systemd journal stays in RAM (`Storage=volatile`); Armbian would otherwise write it to the card continuously.

`yumi-bootlog` writes one line per boot to `/var/lib/yumi/boot.log` and, only after a power cut or a repair, to `/boot/yumi-boot.log` on the FAT partition. From any PC, `grep -c UNCLEAN yumi-boot.log` on that partition tells how many times the board was cut, and `root_fsck=repaired` lines show what fsck had to fix. Before reflashing a card that no longer boots, run `fsck.ext4 -n` on its second partition from a Linux PC: repairable errors mean the software path applies; a card that reads back zeros or turns read-only is a card or power supply problem.

## First-Boot Configuration

No screen or keyboard is needed. The first boot is configured by two text files
on the boot partition, which any computer can edit before the card goes into the
board (the partition is tagged FAT32, so Windows and macOS mount it like a
Raspberry Pi OS card). [cloud-init](https://cloudinit.readthedocs.io/) applies
them once, on the first boot, the way Raspberry Pi OS does.

- `user-data`: the hostname, the user name and its password, the root password.
  Change the values between the quotes. The passwords are in plain text so they
  can be typed in; once applied they are replaced by `(set on first boot)` so they
  do not stay readable on the card.
- `network-config`: Ethernet works as is. For WiFi, delete the `#` at the start of
  the seven lines of the WiFi block and put the network name and password between
  the quotes ([netplan v2 format](https://cloudinit.readthedocs.io/en/latest/reference/network-config-format-v2.html);
  `network-config.template` shows a static address).

Raspberry Pi Imager's customization screen (below) writes both files for you.
Flashed as-is, an image boots with:

| User | Password | Notes |
|------|----------|-------|
| `pi` | `yumi` | sudo + hardware groups (gpio, i2c, spi, dialout…) |
| `root` | `yumi` | |

Change them after the first login. Armbian's interactive first-login wizard is
disabled, cloud-init replaces it. Network interfaces keep the classic names
`eth0` / `wlan0` (`net.ifnames=0`), the ones Raspberry Pi Imager writes in
`network-config`. On Debian 11 the root password keeps Armbian's default (`1234`,
to change at the first login): its cloud-init is too old for the root setting.

## Raspberry Pi Imager

The images can be browsed, flashed **and customized** with Raspberry Pi Imager
through the Yumi repository (the official catalog only lists operating systems
for Raspberry Pi hardware). Start the Imager with:

```bash
rpi-imager --repo https://yumi-lab.github.io/SmartPi-armbian/os_list.json
```

On Windows or macOS, create a shortcut to the Raspberry Pi Imager executable with
the same `--repo` argument; Imager 2 also accepts a custom repository URL in its
settings. Pick the SmartPi One (or SmartPad) and an image: the customization
step then sets the hostname, a user and password, an SSH key, the WiFi network
and the locale, written to the boot partition as cloud-init files and applied on
the first boot. The catalog declares `init_format: cloudinit` and is regenerated
automatically for every release by the `PublishImagerRepo` workflow.

## Getting Started

### Prerequisites
- GitHub account with Actions enabled
- Basic knowledge of Armbian build system

### Quick Start

1. Fork this repository
2. Clone to your local machine:
   ```bash
   git clone https://github.com/YOUR_USERNAME/SmartPi-armbian.git
   ```
3. Customize configuration files in `configs/` directory
4. Push changes to trigger automated build

## Usage

### Automated Builds

![GitHub Actions](https://img.shields.io/badge/CI/CD-GitHub_Actions-2088FF?style=flat-square&logo=github-actions&logoColor=white)

The build process is fully automated using GitHub Actions.

**Triggers:**
- Push to `develop` branch
- Pull requests
- Manual workflow dispatch

**To manually trigger a build:**
1. Go to the **Actions** tab
2. Select **Build Images** workflow
3. Click **Run workflow**

### Creating a Release

1. Go to **Actions** tab
2. Select **Release** workflow
3. Click **Run workflow**
4. Enter version number (e.g., `v1.5.5`)

## Project Structure

```
SmartPi-armbian/
├── .github/workflows/
│   ├── BuildImages.yml         # Main build workflow (8 images)
│   └── Release.yml             # Release workflow
├── actions/
│   └── build-image/            # Armbian build action
├── boards/
│   └── smartpi1.wip            # H3 board config (SmartPi One & SmartPad)
├── configs/
│   ├── config-default.conf     # Default build settings
│   └── smartpi1-*.conf         # SmartPi One variants (also used on SmartPad)
├── docs/
│   └── H3-OVERCLOCK.md         # Overclock documentation
├── userpatches/
│   ├── customize-image.sh      # Image customization script
│   ├── extensions/rtl8188eu-ap/  # 8188eu driver in the kernel (RTL8188EUS access point mode)
│   ├── kernel/archive/sunxi-6.18/
│   │   └── 0001-...-overclock-opp.patch  # H3 1368 MHz OC patch
│   └── overlay/                # Files copied to image
└── README.md
```

## Adding a New Distribution

### 1. Create Configuration File

Create a new config in `configs/`:
```bash
# configs/{board}-{codename}-{variant}.conf
BOARD="smartpi1"
RELEASE="newrelease"
BUILD_DESKTOP="no"
BOOTSIZE="512"
BOOTFS_TYPE="fat"
```

### 2. Update Version Mapping

Edit `.github/workflows/BuildImages.yml` and add the mapping in the "Generate Name Prefix" step:
```yaml
-e 's/newrelease-/newrelease-debian14-/'
```

## Contribution

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch:
   ```bash
   git checkout -b feature/my-feature
   ```
3. Make your changes
4. Commit with clear messages:
   ```bash
   git commit -m "feat: Add support for new distribution"
   ```
5. Push and open a Pull Request

### Development Branch

All development happens on the `develop` branch. PRs should target `develop`.

## License

This project is licensed under the GPL-3.0 License. See the [LICENSE](LICENSE) file for details.

## Disclaimer

This project is based on the work of [meteyou](https://github.com/meteyou), specifically the `mainsail-crew/armbian-builds` project. It has been modified by [KwadFan](https://github.com/KwadFan) and the Yumi Lab team to fit the specific needs of SmartPi devices.

Please note that while the original work is open-source and licensed under the GPL-3.0, always review the license and documentation for the most accurate information.

## Contact

- **Wiki:** [wiki.yumi-lab.com](https://wiki.yumi-lab.com) - Full documentation and tutorials
- **Website:** [yumi-lab.com](https://www.yumi-lab.com) - Official Yumi Lab website
- **Issues:** [GitHub Issues](https://github.com/Yumi-Lab/SmartPi-armbian/issues) - Report bugs or request features

---

<p align="center">
  <b>Built with</b>
</p>
<p align="center">
  <a href="https://www.armbian.com">
    <img src="assets/armbian-logo.png" alt="Armbian" height="50"/>
  </a>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <a href="https://www.yumi-lab.com">
    <img src="assets/logo_yumi.png" alt="Yumi Lab" height="50"/>
  </a>
</p>
<p align="center">
  <a href="https://wiki.yumi-lab.com">
    <img src="https://img.shields.io/badge/Docs-Wiki-orange?style=for-the-badge&logo=gitbook&logoColor=white" alt="Wiki"/>
  </a>
</p>
