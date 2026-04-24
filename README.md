<p align="center">
  <a href="https://www.yumi-lab.com">
    <img src="assets/logo_yumi.png" alt="Yumi Lab" width="200"/>
  </a>
</p>

# SmartPi-armbian

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Version](https://img.shields.io/badge/Version-1.8.0--rc1-green.svg)](https://github.com/Yumi-Lab/SmartPi-armbian/releases)
[![Build Images](https://github.com/Yumi-Lab/SmartPi-armbian/actions/workflows/BuildImages.yml/badge.svg)](https://github.com/Yumi-Lab/SmartPi-armbian/actions/workflows/BuildImages.yml)
[![Wiki](https://img.shields.io/badge/Wiki-Documentation-orange?logo=gitbook&logoColor=white)](https://wiki.yumi-lab.com)

Custom Armbian image builder for SmartPi devices by **[Yumi Lab](https://www.yumi-lab.com)**.

## Table of Contents

- [Introduction](#introduction)
- [Supported Hardware](#supported-hardware)
- [Supported Distributions](#supported-distributions)
- [H3 CPU Overclock](#h3-cpu-overclock)
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

SmartPi-armbian is a custom image builder for SmartPi devices, leveraging the Armbian operating system. This repository contains the tools and configurations necessary to create tailored Linux images for SmartPi hardware, with automated build processes.

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

| Codename | Version | Status |
|----------|---------|--------|
| ![Bullseye](https://img.shields.io/badge/Bullseye-Debian_11-A81D33?logo=debian&logoColor=white) | Debian 11 | Legacy |
| ![Bookworm](https://img.shields.io/badge/Bookworm-Debian_12-A81D33?logo=debian&logoColor=white) | Debian 12 | **Current Stable** |
| ![Trixie](https://img.shields.io/badge/Trixie-Debian_13-A81D33?logo=debian&logoColor=white) | Debian 13 | Testing |

### Ubuntu
![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)

| Codename | Version | Status |
|----------|---------|--------|
| ![Jammy](https://img.shields.io/badge/Jammy-22.04_LTS-E95420?logo=ubuntu&logoColor=white) | Ubuntu 22.04 | LTS |
| ![Noble](https://img.shields.io/badge/Noble-24.04_LTS-E95420?logo=ubuntu&logoColor=white) | Ubuntu 24.04 | **Current LTS** |

## H3 CPU Overclock

Since **v1.8.0**, all images include a kernel patch that enables the H3 CPU to scale up to **1368 MHz** (stock: 1296 MHz) at 1.40V. The overclock is managed automatically by the cpufreq governor under load.

| Frequency | Voltage | Status |
|-----------|---------|--------|
| 1296 MHz | 1.34V | stock |
| **1368 MHz** | **1.40V** | enabled |

Thermal throttle activates at 85°C. A heatsink with active fan is recommended for sustained workloads.

```bash
# Verify max frequency
cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq
# Expected: 1368000

# Monitor temperature
cat /sys/class/thermal/thermal_zone0/temp
```

See [docs/H3-OVERCLOCK.md](docs/H3-OVERCLOCK.md) for technical details.

## Image Naming Convention

All images include the distribution name and version for easy identification.

### Armbian Images
```
{Vendor}-{board}-{codename}-{distro_version}-{variant}-{timestamp}.img.xz
```
**Examples:**
- `Yumi-smartpi1-bookworm-debian12-server-2026-02-02-1234.img.xz`
- `Yumi-smartpad-noble-ubuntu24.04-desktop-2026-02-02-1234.img.xz`

## First-Boot Configuration

> **Note:** The first-boot configuration system (`smartpi-config.txt`) is currently disabled and under development. It will be re-enabled in a future release.

At first boot, Armbian will prompt you to create a root password and a first user account. For headless setup, connect via serial console or SSH (root login with no password on first connection) and follow the interactive setup.

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
│   ├── BuildImages.yml         # Main build workflow (18 images)
│   └── Release.yml             # Release workflow
├── actions/
│   └── build-image/            # Armbian build action
├── boards/
│   └── smartpad.wip            # H3 board config (shared by SmartPi1 & SmartPad)
├── configs/
│   ├── config-default.conf     # Default build settings
│   ├── smartpi1-*.conf         # SmartPi One variants
│   └── smartpad-*.conf         # SmartPad variants
├── docs/
│   └── H3-OVERCLOCK.md         # Overclock documentation
├── userpatches/
│   ├── customize-image.sh      # Image customization script
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
