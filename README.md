# arch-install

## Introduction
Use this script to [install Arch Linux](https://wiki.archlinux.org/title/Installation_guide) within a [VirtualBox](https://www.virtualbox.org/) guest VM.  Then you can honestly say _"I use Arch btw"_.

## Usage
When the [Arch Linux Live CD](https://archlinux.org/download/) boot loader menu appears, choose option <u>`Arch Linux install medium (x86_64, BIOS)`</u>.

At the prompt, download the installation script and run it.
```sh
curl -O https://raw.githubusercontent.com/planet36/arch-install/main/vbox.bash

bash vbox.bash -u NEW_USER [-w DPY_W] [-h DPY_H] [-d DPY_D] [-e]
```

The installation process is uninterruptible.  That is, if it's stopped before finishing, it can't be resumed.

After the install script finishes, the Live CD will be ejected before reboot.
If it isn't ejected (because the VM had insufficient RAM), the system will reboot to the Live CD instead of the new installation.

### Options
- `-u NEW_USER`
  - Specify the username of the new user.
  - The default password is the same as the username.  Change it after the installation is finished!
- `-w DPY_W`
  - Specify the width (in pixels) of the display.
  - The default width is **1920**.
- `-h DPY_H`
  - Specify the height (in pixels) of the display.
  - The default height is **1080**.
- `-d DPY_D`
  - Specify the diagonal size (in inches) of the display.
- `-e`
  - Encrypt the root partition (**/dev/sda2**).
  - The passphrase may not be empty.

If mandatory arguments are absent, you will be prompted to enter values for them.

The display dimensions are used to calculate the [PPI](https://en.wikipedia.org/wiki/Pixel_density#Calculation_of_monitor_PPI).  If not given, a default PPI of **96** will be used.

### Dotfiles
Dotfiles for the new user are cloned from [planet36/dotfiles](https://github.com/planet36/dotfiles).

## Recommended Virtual Machine Resources
- Storage >= 30 GB
- Base Memory >= 2048 MB

## License
[OSL-3.0](https://opensource.org/license/osl-3-0-php/)

