# Changing the boot logo

The logo shown when a SmartPi powers on is built into U-Boot, the bootloader on the SD card. U-Boot draws it, centred, the instant it starts the HDMI output, before it reads anything from the card. To change it you replace one image file and rebuild U-Boot, either on GitHub or on your own Linux computer, then write the new U-Boot to the card.

Nothing before U-Boot can display an image: the HDMI output only exists once U-Boot has started it.

## 1. Prepare the image

U-Boot needs a BMP file with these properties:

| Property | Value |
|---|---|
| Format | BMP, Windows 3 (`BMP3`), uncompressed |
| Colours | 8-bit indexed, 256 colours at most |
| Size | anything up to 1280 × 720, the display mode of the images; the current logo is 400 × 138 |
| Background | black: the screen around the logo stays black |

Convert a PNG with ImageMagick, transparency flattened onto black:

```
magick logo.png -background black -alpha remove -alpha off -colors 256 -type palette BMP3:u-boot-logo.bmp
```

(`convert` instead of `magick` with ImageMagick 6.) Check the result:

```
file u-boot-logo.bmp
u-boot-logo.bmp: PC bitmap, Windows 3.x format, 400 x 138 x 8, ...
```

The `x 8` at the end matters: U-Boot shows nothing for a 24-bit file.

Then replace `userpatches/overlay/u-boot-logo.bmp` in this repository with your file, under the same name.

## 2a. Build U-Boot on GitHub

1. Commit the new `u-boot-logo.bmp` to a branch of your copy of this repository.
2. Open **Actions → Build U-Boot only → Run workflow**, pick your branch, keep `current` and `trixie`, and run it.
3. When it ends, download the artifact `uboot-smartpi1-current`: it holds `linux-u-boot-smartpi1-current_<version>_armhf.deb`.

A full image build (`Build Images`) picks the logo up as well; the U-Boot-only build just takes a few minutes instead of an hour.

## 2b. Build U-Boot on your own computer

You need an x86-64 Linux machine (Ubuntu 22.04 or 24.04, or any distribution with Docker), about 10 GB of free disk space, and an internet connection. Armbian builds inside a Docker container it sets up by itself.

```
git clone https://github.com/armbian/build.git
git clone https://github.com/Yumi-Lab/SmartPi-armbian.git
cp -R SmartPi-armbian/boards/* build/config/boards/
mkdir -p build/userpatches && cp -R SmartPi-armbian/userpatches/* build/userpatches/
cp /path/to/your/u-boot-logo.bmp build/userpatches/overlay/u-boot-logo.bmp
cd build
./compile.sh uboot BOARD=smartpi1 BRANCH=current RELEASE=trixie BUILD_MINIMAL=no BUILD_DESKTOP=no KERNEL_CONFIGURE=no
```

The package lands in `output/debs/linux-u-boot-smartpi1-current_<version>_armhf.deb`.

## 3. Write the new U-Boot to the card

On the SmartPi, as root, first keep a copy of the U-Boot it runs now, then install the package and write it to the card (U-Boot lives in a raw area at 8 KiB from the start of the card, outside any partition):

```
dd if=/dev/mmcblk0 of=/root/u-boot-before.bin bs=1k skip=8 count=1016
dpkg -i linux-u-boot-smartpi1-current_*.deb
dd if=/usr/lib/linux-u-boot-current-smartpi1/u-boot-sunxi-with-spl.bin of=/dev/mmcblk0 bs=1024 seek=8 conv=fsync
reboot
```

On a computer instead, with the SD card in a reader, write `u-boot-sunxi-with-spl.bin` (extracted from the package) the same way at 8 KiB: `dd ... of=/dev/sdX bs=1024 seek=8 conv=fsync`, where `/dev/sdX` is the card, not your system disk.

If the board no longer starts, the new U-Boot is faulty: put the card in a computer and write `u-boot-before.bin` back with the same `dd` command, or reflash the card with a SmartPi image.

## Good to know

- The file U-Boot actually links is `drivers/video/u_boot_logo.bmp` in its sources. The hook `pre_config_uboot_target__smartpi1_yumi_logo` in `boards/smartpi1.wip` copies `userpatches/overlay/u-boot-logo.bmp` there before each build; `tools/logos/`, which U-Boot's own documentation points to, is not the one that ends up in the binary.
- The logo is centred by `userpatches/u-boot/v2026.07-sunxi/0002-video-center-the-built-in-logo.patch`; without it U-Boot draws it in the top-left corner.
- Drawing the logo from the boot script (`bmp display` in `boot.cmd`) does not work: the text console paints over it as it scrolls, and silencing the console breaks the hand-over of the screen to Linux.
- `CONFIG_VIDEO_LOGO` must stay enabled (it is by default); disabling it removes the logo altogether.
