# arch-install

## Introduction
Use this installation script so you can honestly say _"I use Arch btw"_.

## File Description
- [arch-vbox.bash](arch-vbox.bash)
  - Script to [install Arch Linux](https://wiki.archlinux.org/index.php/Installation_guide) in a [VirtualBox](https://www.virtualbox.org/) guest
- [arch-pkgs.txt](arch-pkgs.txt)
  - List of [Arch Linux packages](https://www.archlinux.org/packages/) to install

## Usage
In an  [Arch Linux livecd](https://www.archlinux.org/download/) environment, download the installation script and run it.
```sh
curl -O https://raw.githubusercontent.com/planet36/arch-install/main/arch-vbox.bash

bash arch-vbox.bash -u NEW_USER [-s NEW_USER_SHELL] [-w DPY_W] [-h DPY_H] [-d DPY_D] [-e]
```

The installation process is uninterruptible.  That is, if it's stopped before finishing, it can't be resumed.

### Options
- `-u NEW_USER`
  - Specify the username of the new user.
  - The default password is the same as the username.  Change it after the installation is finished!
- `-s NEW_USER_SHELL`
  - Specify the _basename_ of the shell of the new user.
  - The default shell is **bash**.
  - See **/etc/shells** for available shells.
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
  - Prompt for the passphrase, which may not be empty.
  - If absent, no partitions will be encrypted during installation.

If mandatory arguments are absent, you will be prompted to enter values for them.

The display dimensions are used to calculate the [PPI](https://en.wikipedia.org/wiki/Pixel_density#Calculation_of_monitor_PPI).  If not given, a default PPI of **96** will be used.

### Dotfiles
Dotfiles for the new user are cloned from [planet36/dotfiles](https://github.com/planet36/dotfiles).

## Recommended Virtual Machine Resources
- Storage >= 30 GB
- Base Memory >= 2048 MB

## License
[OSL-3.0](https://opensource.org/licenses/OSL-3.0)

