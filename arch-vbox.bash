#!/usr/bin/bash
# SPDX-FileCopyrightText: Steven Ward
# SPDX-License-Identifier: OSL-3.0

# shellcheck disable=SC2086

declare -a ARGS=("$@")

# set -e is unreliable and convoluted
# https://mywiki.wooledge.org/BashFAQ/105
set -e

THIS_SCRIPT="$(realpath -- "$0")"

export LC_ALL=C

DEFAULT_DPY_W=1920
DEFAULT_DPY_H=1080

is_int() {
    # shellcheck disable=SC2065
    test "$1" -eq 0 -o "$1" -ne 0 &> /dev/null
}

is_uint() {
    is_int "$1" && test "$1" -ge 0
}

is_pos_int() {
    is_int "$1" && test "$1" -gt 0
}

setup_grub() {
    cp --backup=numbered /etc/default/grub /etc/default/grub.bak

    cat <<EOT >> /etc/default/grub

# Added by $THIS_SCRIPT
GRUB_TIMEOUT=2
GRUB_CMDLINE_LINUX_DEFAULT+=" mitigations=off random.trust_cpu=yes"
GRUB_GFXMODE=${DPY_W}x${DPY_H}x32,1280x1024x32,auto
EOT

    if $ENCRYPT_ROOT_PARTITION
    then
        echo 'GRUB_CMDLINE_LINUX+=" cryptdevice=/dev/sda2:cryptroot"' >> /etc/default/grub
    fi
    grub-install /dev/sda
    grub-mkconfig -o /boot/grub/grub.cfg
}

setup_hostname_hosts() {

    # shellcheck disable=SC1091
    source /usr/lib/os-release

    HOSTNAME="$ID"-vm
    # https://wiki.archlinux.org/title/Network_configuration#Set_the_hostname
    printf '%s\n' "$HOSTNAME" > /etc/hostname

    # https://wiki.archlinux.org/title/Chroot#Usage
    # Cannot be used inside a chroot
    #hostnamectl set-hostname "$HOSTNAME"
    #hostnamectl status

    cat <<EOT >> /etc/hosts
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOT
}

setup_reflector_service() {

    mv --backup=numbered -- /etc/xdg/reflector/reflector.conf /etc/xdg/reflector/reflector.conf.bak
    cat <<EOT > /etc/xdg/reflector/reflector.conf
--country US
--number 5
--protocol https
--save /etc/pacman.d/mirrorlist
--sort score
EOT

    # https://wiki.archlinux.org/title/Reflector#Automation
    # reflector.timer starts reflector.service weekly
    #systemctl start reflector.timer # Running in chroot, ignoring command 'start'
    systemctl enable reflector.timer
}

setup_paccache_timer() {

    # https://wiki.archlinux.org/title/Pacman#Cleaning_the_package_cache
    #systemctl start paccache.timer # Running in chroot, ignoring command 'start'
    systemctl enable paccache.timer
}

setup_vbox_service() {

    systemctl enable vboxservice.service
    # OR
    #modprobe -a vboxguest vboxsf vboxvideo

    cat <<EOT > /etc/X11/xinit/xinitrc.d/99-vboxclient-all.sh
#!/usr/bin/sh
# SPDX-FileCopyrightText: Steven Ward
# SPDX-License-Identifier: OSL-3.0

if command -v VBoxClient-all > /dev/null
then
    VBoxClient-all
fi
EOT

    chmod --changes 755 -- /etc/X11/xinit/xinitrc.d/99-vboxclient-all.sh
}

setup_xdg_vars() {

    # https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html

    : "${XDG_CACHE_HOME:=$HOME/.cache}"
    : "${XDG_CONFIG_DIRS:=/etc/xdg}"
    : "${XDG_CONFIG_HOME:=$HOME/.config}"
    : "${XDG_DATA_DIRS:=/usr/local/share/:/usr/share/}"
    : "${XDG_DATA_HOME:=$HOME/.local/share}"

    export XDG_CACHE_HOME
    export XDG_CONFIG_DIRS
    export XDG_CONFIG_HOME
    export XDG_DATA_DIRS
    export XDG_DATA_HOME

    mkdir --verbose --parents -- "$XDG_CACHE_HOME"
    mkdir --verbose --parents -- "$XDG_CONFIG_HOME"
    mkdir --verbose --parents -- "$XDG_DATA_HOME"

    # XDG environment variables have been set
    # XDG base directories have been created
}

setup_dpi() {

    DPI=96

    if [[ -n "$DPY_W" ]] && [[ -n "$DPY_H" ]] && [[ -n "$DPY_D" ]]
    then
        DPI=$(~/.local/bin/calc-dpi -w "$DPY_W" -h "$DPY_H" "$DPY_D")
    fi

    # ~/.xprofile is sourced by some display managers
    #printf "xrandr --dpi %d\n" "$DPI" >> $XDG_CONFIG_HOME/xorg/xprofile

    #printf 'Xft.dpi: %d\n' "$DPI" >> "$XDG_CONFIG_HOME"/xorg/Xresources
    printf 'Xft.dpi: %d\n' "$DPI" >> "$XDG_CONFIG_HOME"/xorg/Xresources-xft
}

setup_0() {

    if ((EUID != 0))
    then
        echo 'Error: must run as root'
        exit 1
    fi

    # {{{ Set console font
    if command -v setfont > /dev/null
    then
        # To print the character set of the active font: showconsolefont

        # Fonts are in:
        # /usr/share/kbd/consolefonts (arch)
        # /lib/kbd/consolefonts (fedora)

        setfont Lat2-Terminus16
    fi
    # }}}

    ENCRYPT_PASSPHRASE=''

    if $ENCRYPT_ROOT_PARTITION
    then
        if [ ! -t 0 ]
        then
            echo 'Error: must run in an interactive shell'
            exit 1
        fi

        while true
        do
            read -r -s -p 'Enter encryption passphrase: ' ENCRYPT_PASSPHRASE
            echo
            if [ -z "$ENCRYPT_PASSPHRASE" ]
            then
                echo 'Error: passphrase for encrypting the root partition may not be empty'
                continue
            fi

            read -r -s -p 'Confirm encryption passphrase: ' ENCRYPT_PASSPHRASE2
            echo
            if [[ "$ENCRYPT_PASSPHRASE" != "$ENCRYPT_PASSPHRASE2" ]]
            then
                echo 'Error: passphrases do not match'
                continue
            fi

            break
        done
    fi

    # {{{ Partition /dev/sda
    #parted --script --align optimal /dev/sda mklabel msdos unit % mkpart primary 0 100
    parted --script --align optimal /dev/sda mklabel msdos \
    mkpart primary 1MiB 256MiB \
    mkpart primary 256MiB 100%
    parted --script /dev/sda set 1 boot on
    # }}}

    # {{{ Format root partition
    if $ENCRYPT_ROOT_PARTITION
    then
        # https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system
        # https://linuxhint.com/setup-luks-encryption-on-arch-linux/

        modprobe dm-crypt

        echo 'cryptsetup (1) ...'
        printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup --verbose --batch-mode luksFormat /dev/sda2

        echo 'cryptsetup (2) ...'
        printf '%s' "$ENCRYPT_PASSPHRASE" | cryptsetup --verbose --batch-mode open /dev/sda2 cryptroot

        mkfs.ext4 -L root /dev/mapper/cryptroot
        mount --verbose -- /dev/mapper/cryptroot /mnt
    else
        mkfs.ext4 -L root /dev/sda2
        mount --verbose -- /dev/sda2 /mnt
    fi
    # }}}

    # {{{ Format boot partition
    mkfs.ext4 -L boot /dev/sda1
    mkdir --verbose -- /mnt/boot
    mount --verbose -- /dev/sda1 /mnt/boot
    # }}}

    # {{{ Update mirrorlist
    cp --verbose -- /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
    reflector --country US --number 5 --protocol https --save /etc/pacman.d/mirrorlist --sort score
    # }}}

    # {{{ Change pacman.conf misc options
    sed -E -i 's/^#(VerbosePkgLists)\>/\1/' /etc/pacman.conf
    sed -E -i 's/^#(ParallelDownloads)\>/\1/' /etc/pacman.conf
    # }}}

    #pacstrap /mnt base linux
    pacstrap /mnt base

    genfstab -U /mnt >> /mnt/etc/fstab

    # Do not copy to /mnt/tmp because it is cleared after chroot
    cp --verbose -- "$0" /mnt/

    # https://wiki.archlinux.org/title/Systemd-networkd#Wired_adapter_using_DHCP
    cp --verbose /etc/systemd/network/* /mnt/etc/systemd/network/

    arch-chroot /mnt bash /"$(basename -- "$0")" "${ARGS[@]}"

    umount --verbose --recursive -- /mnt

    if findmnt -c -n --source /dev/cdrom -o TARGET > /dev/null
    then
        # https://lists.freedesktop.org/archives/systemd-devel/2012-September/006568.html

        # https://www.linux.org/docs/man8/systemd-shutdown.html
        #       Immediately before executing the actual system halt/poweroff/reboot/kexec systemd-shutdown will run all
        #       executables in /usr/lib/systemd/system-shutdown/ and pass one arguments to them: either "halt", "poweroff",
        #       "reboot" or "kexec", depending on the chosen action. All executables in this directory are executed in
        #       parallel, and execution of the action is not continued before all executables finished.

        cat <<EOT > /usr/lib/systemd/system-shutdown/eject.shutdown
#!/usr/bin/sh
/usr/bin/eject -v -T
EOT

        chmod 755 /usr/lib/systemd/system-shutdown/eject.shutdown
    else
        eject -v -T
    fi

    # if interactive
    if [ -t 0 ]
    then
        printf '\nTook %d seconds\n\n' "$SECONDS"

        echo 'Press Enter key to reboot now'
        # shellcheck disable=SC2034
        read -r DUMMY < /dev/tty
        #read -r -p 'Press Enter key to reboot'
    fi

    systemctl reboot
}

# setup system, install packages
setup_1() {

    if ((EUID != 0))
    then
        echo 'Error: must run as root'
        exit 1
    fi

    # {{{ Locale
    mv --backup=numbered -- /etc/locale.gen /etc/locale.gen.bak
    #sed -E -i 's/^#\s*\(en_US.UTF-8\)/\1/' /etc/locale.gen
    #sed -E -i 's/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
    echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
    locale-gen

    # {{{ Set console font
    # https://www.man7.org/linux/man-pages/man5/vconsole.conf.5.html
    # Should be set before mkinitcpio is called
    cat <<EOT >> /etc/vconsole.conf
KEYMAP=us
FONT=Lat2-Terminus16
EOT
    # }}}

    #export LANG=en_US.UTF-8
    #echo "LANG=$LANG" > /etc/locale.conf

    # https://wiki.archlinux.org/title/Chroot#Usage
    # Cannot be used inside a chroot
    #localectl set-locale LANG=en_US.UTF-8
    # }}}

    # {{{ Change pacman.conf misc options
    sed -E -i 's/^#(VerbosePkgLists)\>/\1/' /etc/pacman.conf
    sed -E -i 's/^#(ParallelDownloads)\>/\1/' /etc/pacman.conf
    # }}}

    # {{{ Update the keyring if it's out-of-date
    # Do not use the "--needed" option
    pacman -S          --noconfirm -y archlinux-keyring
    pacman -S --needed --noconfirm -u
    # }}}

    # {{{ Edit /etc/mkinitcpio.conf
    if $ENCRYPT_ROOT_PARTITION
    then
        ENCRYPT_HOOK='encrypt'
    else
        # Must not add "encrypt" if the "crypt=" parameter won't be given to kernel
        ENCRYPT_HOOK=''
    fi

    # https://wiki.archlinux.org/title/Mkinitcpio#Common_hooks
    cat <<EOT >> /etc/mkinitcpio.conf

# Added by $THIS_SCRIPT
# Changes to HOOKS array:
#   Move "keyboard" after "block"
#   Add "keymap consolefont" after "keyboard"
#   If encrypt, "keyboard" must be before "encrypt" to enter the passphrase
HOOKS=(base udev autodetect modconf block keyboard keymap consolefont $ENCRYPT_HOOK fsck filesystems)
EOT

    #mkinitcpio -p linux
    # OR
    #mkinitcpio -P # all presets
    # }}}

    # {{{ Install Linux
    # Install initramfs compression methods listed in /etc/mkinitcpio.conf
    pacman -S --needed --noconfirm \
        linux grub \
        bzip2 gzip lz4 lzop xz zstd
    # }}}

    # {{{ Install Arch packages
    curl -L https://raw.githubusercontent.com/planet36/arch-install/main/arch-pkgs.txt | grep -E -o '^[^#]+' | xargs -r pacman -S --needed --noconfirm
    # }}}

    # {{{ Configure grub
    setup_grub
    # }}}

    # {{{ System time zone, NTP
    # https://wiki.archlinux.org/title/Chroot#Usage
    # Cannot be used inside a chroot
    #timedatectl status
    #timedatectl set-timezone America/New_York
    #timedatectl set-ntp true
    #timedatectl status

    # https://wiki.archlinux.org/title/Systemd-timesyncd
    #systemctl enable systemd-timesyncd.service
    # }}}

    # Use static IP address
#    cat <<EOT >> /etc/systemd/network/20-ethernet.network
#
## Added by $THIS_SCRIPT
#[Network]
#DHCP=no
#Address=10.0.2.15/24
#Gateway=10.0.2.2
##DNS=8.8.8.8
##DNS=8.8.4.4
#EOT

#    cat <<EOT > /etc/resolv.conf.head
#nameserver 1.1.1.1
#nameserver 1.0.0.1
#EOT

#    cat <<EOT > /etc/resolv.conf.tail
#nameserver 1.1.1.1
#nameserver 1.0.0.1
#EOT
#nameserver 8.8.8.8
#nameserver 8.8.4.4


    #systemctl enable dhcpcd
    systemctl enable systemd-networkd
    systemctl enable systemd-resolved

    # Print DNS info
    #resolvectl status

    # {{{ Update mirrorlist service
    setup_reflector_service
    # }}}

    setup_paccache_timer

    setup_hostname_hosts

    # {{{ Virtualbox service
    setup_vbox_service
    # }}}

    # {{{ Disable systemd core dump archives, and use traditional Linux behavior
    # https://man7.org/linux/man-pages/man5/core.5.html
    echo 'kernel.core_pattern=core.%p' > /etc/sysctl.d/50-coredump.conf
    # }}}

    # {{{ Fix bash in /etc/shells
    # https://bugs.archlinux.org/task/33677
    # https://bugs.archlinux.org/task/33694
    # https://bugs.archlinux.org/task/69699
    echo '/usr/bin/bash' >> /etc/shells
    # }}}

    # Lock the root account
    passwd --lock root

    # {{{ Sudo
    echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/01_group_wheel
    echo 'Defaults timestamp_timeout=-1' > /etc/sudoers.d/02_disable_timestamp_timeout
    echo 'Defaults timestamp_type=global' > /etc/sudoers.d/03_disable_per_terminal_sudo
    # }}}

    # {{{ Doas
    echo 'permit nopass keepenv :wheel' > /etc/doas.conf
#    cat <<EOT > /etc/doas.conf
#permit persist keepenv :wheel
#permit nopass keepenv root
#EOT
    #echo 'permit persist :wheel' > /etc/doas.conf
    # }}}

    # {{{ Modify defaults for all users

    # {{{ /etc/login.defs used by useradd and newusers
    cat <<EOT >> /etc/login.defs

# Added by $THIS_SCRIPT
CREATE_HOME yes
EOT
    # }}}

    # {{{ Set XDG_* env vars
    # https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
    cat <<EOT >> /etc/security/pam_env.conf

# Added by $THIS_SCRIPT
XDG_CACHE_HOME  DEFAULT=@{HOME}/.cache
XDG_CONFIG_DIRS DEFAULT=/etc/xdg
XDG_CONFIG_HOME DEFAULT=@{HOME}/.config
XDG_DATA_DIRS   DEFAULT=/usr/local/share/:/usr/share/
XDG_DATA_HOME   DEFAULT=@{HOME}/.local/share
EOT
    # }}}

    # {{{ Create common directories in /etc/skel
    cd /etc/skel

    rm --verbose -- .bash_logout

    mkdir --verbose --parents -- \
        .cache \
        .config \
        .local/share

    mkdir --verbose --parents -- \
        .local/{bin,include,lib,src}

    mkdir --verbose --parents -- Downloads

    mkdir --verbose --parents -- \
        .local/share/nvim/{site/autoload,backup,colors,swap,undo}

    mkdir --verbose --mode=0700 -- .local/share/Trash

    mkdir --verbose --parents -- .cache/xorg

    mkdir --verbose --parents -- \
        .local/share/{bash,fish}
    # }}}

    printf '\n# Added by %q\n' "$THIS_SCRIPT" >> /etc/profile

    cat <<'EOT' >> /etc/profile

# Prepend user path
PATH="$HOME/.local/bin:$PATH"

# Set XDG vars
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
: "${XDG_CACHE_HOME:=$HOME/.cache}"
: "${XDG_CONFIG_DIRS:=/etc/xdg}"
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_DIRS:=/usr/local/share/:/usr/share/}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
export XDG_CACHE_HOME
export XDG_CONFIG_DIRS
export XDG_CONFIG_HOME
export XDG_DATA_DIRS
export XDG_DATA_HOME
EOT

    printf '\n# Added by %q\n' "$THIS_SCRIPT" >> /etc/fish/config.fish

    cat <<'EOT' >> /etc/fish/config.fish

# Prepend user path
# Move ~/.local/bin to the front of PATH.
fish_add_path --move "$HOME"/.local/bin

# Set XDG vars
# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
if not set --query XDG_CACHE_HOME  ; set --export --global XDG_CACHE_HOME  "$HOME"/.cache                ; end
if not set --query XDG_CONFIG_DIRS ; set --export --global XDG_CONFIG_DIRS /etc/xdg                      ; end
if not set --query XDG_CONFIG_HOME ; set --export --global XDG_CONFIG_HOME "$HOME"/.config               ; end
if not set --query XDG_DATA_DIRS   ; set --export --global XDG_DATA_DIRS   /usr/local/share/:/usr/share/ ; end
if not set --query XDG_DATA_HOME   ; set --export --global XDG_DATA_HOME   "$HOME"/.local/share          ; end
EOT

    # }}}

    # {{{ Create new user
    useradd \
        --gid wheel \
        --groups vboxsf \
        -- "$NEW_USER"

    # The initial password is the user name
    printf '%s\n%s\n' "$NEW_USER" "$NEW_USER" | passwd --quiet -- "$NEW_USER"
    # }}}

    # Must use absolute path of $0
    su --login "$NEW_USER" -- "$(realpath -- "$0")" "${ARGS[@]}"
}

# setup user dotfiles and programs
setup_2() {

    # {{{ Setup dotfiles
    cd

    if [ ! -d .dotfiles ]
    then
        git clone --quiet https://github.com/planet36/dotfiles.git .dotfiles
    fi

    bash .dotfiles/install.bash -r -p

    setup_xdg_vars

    # May only be after the dotfiles are installed
    setup_dpi
    # }}}

    # https://www.colour-science.org/installation-guide/
    #sudo --set-home pip install colour-science

    # https://github.com/gtaylor/python-colormath
    #sudo --set-home pip install colormath
}

parse_options() {

    # Used in setup_1
    NEW_USER=''
    # Used in setup_dpi (setup_2)
    DPY_W=''
    DPY_H=''
    DPY_D=''
    # Used in setup_0, setup_grub, setup_1
    ENCRYPT_ROOT_PARTITION=false

    while getopts 'u:w:h:d:e' OPTION "${ARGS[@]}"
    do
        case $OPTION in
            u) NEW_USER="$OPTARG" ;;
            w) DPY_W="$OPTARG" ;; # pixels
            h) DPY_H="$OPTARG" ;; # pixels
            d) DPY_D="$OPTARG" ;; # inches
            e) ENCRYPT_ROOT_PARTITION=true ;;
            \?) exit 1 ;;
            *) ;;
        esac
    done
    # Do not shift because options will be re-used
    #shift $((OPTIND - 1))

    if [ -z "$NEW_USER" ]
    then
        if [ ! -t 0 ]
        then
            echo 'Error: must run in an interactive shell'
            exit 1
        fi

        printf 'Enter new user: '
        read -r NEW_USER < /dev/tty
        #read -r -p 'Enter new user: ' NEW_USER
        ARGS+=(-u "$NEW_USER")
    fi

    if [ -z "$DPY_W" ]
    then
        DPY_W="$DEFAULT_DPY_W"
        #printf 'Enter the width (in pixels) of the display: '
        #read -r DPY_W < /dev/tty
        ARGS+=(-w "$DPY_W")
    fi

    if ! is_pos_int "$DPY_W"
    then
        printf 'Error: display width must be a positive integer: %s\n' "$DPY_W"
        exit 1
    fi

    if [ -z "$DPY_H" ]
    then
        DPY_H="$DEFAULT_DPY_H"
        #printf 'Enter the height (in pixels) of the display: '
        #read -r DPY_H < /dev/tty
        ARGS+=(-h "$DPY_H")
    fi

    if ! is_pos_int "$DPY_H"
    then
        printf 'Error: display height must be a positive integer: %s\n' "$DPY_H"
        exit 1
    fi

    # This is optional
    #if [ -z "$DPY_D" ]
    #then
    #    printf 'Enter the diagonal size (in inches) of the display: '
    #    read -r DPY_D < /dev/tty
    #    #read -r -p 'Enter the diagonal size (in inches) of the display: ' NEW_USER
    #    ARGS+=(-d "$DPY_D")
    #fi
}

main() {

    if ((EUID == 0))
    then # as root
        if ! systemd-detect-virt -r
        then # not in chroot
            setup_0 "${ARGS[@]}"
        else # in chroot
            setup_1 "${ARGS[@]}"
        fi
    else # not as root
        setup_2 "${ARGS[@]}"
    fi
}

parse_options "${ARGS[@]}"

main "${ARGS[@]}"

# vim: set expandtab shiftwidth=4 softtabstop=4 tabstop=4:
