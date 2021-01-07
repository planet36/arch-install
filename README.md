# arch-install

## Introduction
Use this installation script so you can honestly say _"I use Arch btw"_.

## Description
- [arch-vbox.bash](arch-vbox.bash)
  - The script to [install Arch Linux](https://wiki.archlinux.org/index.php/Installation_guide) in a [VirtualBox](https://www.virtualbox.org/) guest
- [arch-pkgs.txt](arch-pkgs.txt)
  - The list of [Arch Linux packages](https://www.archlinux.org/packages/) to install

## Usage
In an  [Arch Linux livecd](https://www.archlinux.org/download/) environment, download the installation script and run it.
```sh
curl https://raw.githubusercontent.com/planet36/arch-install/main/arch-vbox.bash > arch-vbox.bash

bash arch-vbox.bash -u NEW_USER [-s NEW_USER_SHELL] [-w DPY_W] [-h DPY_H] -d DPY_D [-e ENCRYPT_PASSPHRASE]
```

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
  - The default value is **1920**.
- `-h DPY_H`
  - Specify the height (in pixels) of the display.
  - The default value is **1080**.
- `-d DPY_D`
  - Specify the diagonal size (in inches) of the display.
- `-e ENCRYPT_PASSPHRASE`
  - Specify the encryption passphrase used to encrypt the root partition (**/dev/sda2**).
  - The passphrase may not be empty.
  - If the `-e` option is absent, no partitions will be encrypted during installation.

If mandatory arguments are absent, you will be prompted to enter values for them.

The display dimensions are used to calculate the <abbr title="Dots Per Inch">DPI</abbr>.

### Dotfiles
Dotfiles for the new user are cloned from [planet36/dotfiles](https://github.com/planet36/dotfiles).

## License
[OSL-3.0](https://opensource.org/licenses/OSL-3.0)

