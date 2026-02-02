# SmartPi-armbian

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Version](https://img.shields.io/badge/Version-1.5.4-green.svg)](https://github.com/Yumi-Lab/SmartPi-armbian/releases)
[![Build Images](https://github.com/Yumi-Lab/SmartPi-armbian/actions/workflows/BuildImages.yml/badge.svg)](https://github.com/Yumi-Lab/SmartPi-armbian/actions/workflows/BuildImages.yml)

Custom Armbian image builder for SmartPi devices by **Yumi Lab**.

## Table of Contents

- [Introduction](#introduction)
- [Supported Hardware](#supported-hardware)
- [Supported Distributions](#supported-distributions)
- [Image Naming Convention](#image-naming-convention)
- [First-Boot Configuration](#first-boot-configuration)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Adding a New Distribution](#adding-a-new-distribution)
- [Contribution](#contribution)
- [License](#license)
- [Disclaimer](#disclaimer)
- [Contact](#contact)

## Introduction

SmartPi-armbian is a custom image builder for SmartPi devices, leveraging the Armbian operating system. This repository contains the tools and configurations necessary to create tailored Linux images for SmartPi hardware, with automated build and conversion processes including DietPi support.

## Supported Hardware

### SmartPi One
![SmartPi One](https://img.shields.io/badge/SmartPi_One-Allwinner_H3-orange?style=for-the-badge&logo=arm&logoColor=white)

| Specification | Value |
|---------------|-------|
| **SoC** | Allwinner H3 quad-core |
| **RAM** | 1GB |
| **Variants** | 🖥️ Server / 🖼️ Desktop |

### SmartPad
![SmartPad](https://img.shields.io/badge/SmartPad-Allwinner_H3-orange?style=for-the-badge&logo=arm&logoColor=white)

| Specification | Value |
|---------------|-------|
| **SoC** | Allwinner H3 quad-core |
| **RAM** | 1GB |
| **Display** | Integrated touchscreen (180° rotated) |
| **Extras** | On-screen keyboard (Onboard) |
| **Variants** | 🖥️ Server / 🖼️ Desktop |

## Supported Distributions

### Debian
![Debian](https://img.shields.io/badge/Debian-A81D33?style=for-the-badge&logo=debian&logoColor=white)

| Codename | Version | DietPi Support | Status |
|----------|---------|----------------|--------|
| ![Bullseye](https://img.shields.io/badge/Bullseye-Debian_11-A81D33?logo=debian&logoColor=white) | Debian 11 | ✅ Yes (target: 6) | Legacy |
| ![Bookworm](https://img.shields.io/badge/Bookworm-Debian_12-A81D33?logo=debian&logoColor=white) | Debian 12 | ✅ Yes (target: 7) | **Current Stable** |
| ![Trixie](https://img.shields.io/badge/Trixie-Debian_13-A81D33?logo=debian&logoColor=white) | Debian 13 | ✅ Yes (target: 8) | Testing |

### Ubuntu
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)

| Codename | Version | DietPi Support | Status |
|----------|---------|----------------|--------|
| ![Jammy](https://img.shields.io/badge/Jammy-22.04_LTS-E95420?logo=ubuntu&logoColor=white) | Ubuntu 22.04 | ❌ No | Server only |
| ![Noble](https://img.shields.io/badge/Noble-24.04_LTS-E95420?logo=ubuntu&logoColor=white) | Ubuntu 24.04 | ❌ No | **Current LTS** |

### DietPi
![DietPi](https://img.shields.io/badge/DietPi-5A9817?style=for-the-badge&logo=linux&logoColor=white)

DietPi conversion is available for **Debian server images only**.

## Image Naming Convention

All images include the distribution name and version for easy identification.

### Armbian Images
```
{Vendor}-{board}-{codename}-{distro_version}-{variant}-{timestamp}.img.xz
```
**Examples:**
- `Yumi-smartpi1-bookworm-debian12-server-2026-02-02-1234.img.xz`
- `Yumi-smartpad-noble-ubuntu24.04-desktop-2026-02-02-1234.img.xz`

### DietPi Images
```
{board}-DietPi-{codename}-{distro_version}-{variant}-{timestamp}.img.xz
```
**Example:**
- `smartpi1-DietPi-bookworm-debian12-server-2026-02-02-1234.img.xz`

## First-Boot Configuration

![Config](https://img.shields.io/badge/Headless_Setup-Supported-success?style=flat-square&logo=raspberrypi&logoColor=white)
![RPI Compatible](https://img.shields.io/badge/Raspberry_Pi_Imager-Compatible-C51A4A?style=flat-square&logo=raspberrypi&logoColor=white)

SmartPi images include a first-boot configuration system. The boot partition is **FAT formatted**, so you can edit configuration files on **Windows, Mac, or Linux** before inserting the SD card.

### Method 1: SmartPi Config File (Recommended)

Edit `/boot/smartpi-config.txt` on the SD card:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `APPLY_CONFIG` | Set to `1` to activate configuration | `0` |
| `HOSTNAME` | Device hostname | Board name |
| `SSH_ENABLED` | Enable SSH (`1` or `0`) | `1` |
| `USERNAME` | Create a user account | - |
| `USER_PASSWORD` | User password | - |
| `ROOT_PASSWORD` | Root password | - |
| `WIFI_SSID` | WiFi network name | - |
| `WIFI_PASSWORD` | WiFi password | - |
| `WIFI_COUNTRY` | WiFi country code | `FR` |
| `STATIC_IP` | Static IP address | - |
| `NETMASK` | Network mask | `255.255.255.0` |
| `GATEWAY` | Default gateway | - |
| `DNS` | DNS server | - |
| `TIMEZONE` | System timezone | - |
| `LOCALE` | System locale | - |

**Example:**
```ini
APPLY_CONFIG=1
HOSTNAME=my-smartpi
SSH_ENABLED=1
USERNAME=pi
USER_PASSWORD=raspberry
WIFI_SSID=MyNetwork
WIFI_PASSWORD=MyPassword
WIFI_COUNTRY=FR
TIMEZONE=Europe/Paris
```

### Method 2: Raspberry Pi Imager Compatible

You can also use **Raspberry Pi Imager** files directly on the boot partition:

| File | Description |
|------|-------------|
| `ssh` or `ssh.txt` | Empty file to enable SSH |
| `wpa_supplicant.conf` | Standard WiFi configuration |
| `userconf.txt` | User creation (`user:encrypted_password`) |
| `hostname` | Plain text hostname |
| `firstrun.sh` | Custom script executed on first boot |

This means you can use tools like **Raspberry Pi Imager** to pre-configure WiFi and SSH, then flash a SmartPi image!

### How It Works

1. On first boot, the `smartpi-firstboot` service runs
2. It checks for Raspberry Pi Imager files first
3. Then processes `smartpi-config.txt` if `APPLY_CONFIG=1`
4. Configuration is logged to `/var/log/smartpi-firstboot.log`
5. Processed files are removed or renamed to `.done`

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
│   ├── BuildImages.yml      # Main build workflow
│   └── Release.yml          # Release workflow
├── actions/
│   ├── build-image/         # Armbian build action
│   └── convert-dietpi/      # DietPi conversion action
├── boards/
│   ├── smartpi1.wip         # SmartPi One board config
│   └── smartpad.wip         # SmartPad board config
├── configs/
│   ├── config-default.conf  # Default build settings
│   ├── smartpi1-*.conf      # SmartPi One variants
│   └── smartpad-*.conf      # SmartPad variants
├── userpatches/
│   ├── customize-image.sh   # Image customization script
│   └── overlay/             # Files copied to image
│       ├── smartpi-config.txt
│       ├── smartpi-firstboot.sh
│       └── smartpi-firstboot.service
├── context.txt              # Project documentation
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

### 3. Add DietPi Support (Optional)

Add to the DietPi matrix in `BuildImages.yml`:
```yaml
- configfile: smartpi1-newrelease-server
  distro_target: "9"
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

- **Issues:** Open an issue on the [GitHub repository](https://github.com/Yumi-Lab/SmartPi-armbian/issues)
- **Website:** [Yumi Lab](https://www.yumi-lab.com)

---

<p align="center">
  <img src="https://img.shields.io/badge/Built_with-Armbian-red?style=for-the-badge&logo=linux&logoColor=white" alt="Armbian"/>
  <img src="https://img.shields.io/badge/Made_by-Yumi_Lab-blue?style=for-the-badge" alt="Yumi Lab"/>
</p>
