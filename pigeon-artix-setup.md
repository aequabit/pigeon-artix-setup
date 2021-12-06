https://wiki.artixlinux.org/Main/Installation
https://gist.github.com/aequabit/0bca46e233b7ecaed65fbfa01e68dd3e#file-arch-lvm-setup-md
https://github.com/mikilian/arch-luks-setup
https://gist.github.com/themagicalmammal/37276c97897d40598e975f5e563252a6

## Consider
https://gist.github.com/mattiaslundberg/8620837
https://gist.github.com/huntrar/e42aee630bee3295b2c671d098c81268
https://gist.github.com/CodeSigils/b3079626a5b32cd463dd09d853a820e1
https://gist.github.com/psygo/5ba37d093072f01f75c6df43e221f976
https://gist.github.com/artixnous/aec84543cf96eaf177b70bf7d09f7a3c
https://gist.github.com/artixnous/41f4bde311442aba6a4f5523db921415
https://www.youtube.com/watch?v=QzY2T3B4wlo
https://www.youtube.com/watch?v=mIpZA6z-Ctk
https://github.com/Zaechus/artix-installer

# TODO
- use variables wherever possible
- extend rn script?
 - list of packages to replace with the -openrc, -s6 etc. variants
- make interactive script?
 - ! full ci integration (installer boot to working system)
 - backup all files
 - log all actions
 - don't automatically edit configs, launch editor to do so
  - ! keep hashes of configuration files - only prompt if unknown
   - ? scan before to know if installation requires interaction
  - prepend small, commented guide on what to change

## artix-base-openrc-20211121-x86_64

# SETUP

- loadkeys de

- fdisk
 - 300MB efi
 - 500MB boot
 - lvm container
  - 50GB root
  - rest home

## TODO: https://wiki.artixlinux.org/Main/InstallationWithFullDiskEncryption

## change labels
- mkfs.fat -F 32 /dev/...
- fatlabel /dev/... pt-boot
- mkfs.ext4 -L pt-root /dev/...
- mkfs.ext4 -L pt-home /dev/...

- mount /dev/disk/by-label/pt-root /mnt
- mkdir /mnt/boot
- mkdir /mnt/home

## TODO: Try runit

- basestrap /mnt base base-devel openrc elogind-openrc
- basestrap /mnt linux-zen linux-zen-headers linux-lts linux-lts-headers linux-firmware lvm2
- (intel) basestrap /mnt intel-ucode
- (amd) basestrap /mnt amd-ucode

- fstabgen -U /mnt >> /mnt/etc/fstab

- artix-chroot /mnt

- nano /etc/conf.d/keymaps
 - keymap="de-latin1"
- nano /etc/vconsole.conf
 - KEYMAP=de-latin1

- ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
- hwclock --systohc

- pacman -S nano
- nano /etc/locale.gen
- locale-gen
- nano /etc/locale.conf
 - export LANG="en_US.UTF-8"
 - export LC_COLLATE="C"

- pacman -S grub os-prober efibootmgr
- (bios) grub-install --recheck /dev/...
- (uefi) grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=pigeon_artix
- grub-mkconfig -o /boot/grub/grub.cfg

- passwd
- useradd -m felix
- passwd felix

- nano /etc/hostname
- nano /etc/hosts
 - 127.0.0.1 localhost felix-master.localdomain felix-master
 - 127.0.1.1 localhost felix-master.localdomain felix-master
 - ::1 localhost felix-master.localdomain felix-master
- nano /etc/conf.d/hostname
 - hostname='felix-master'

- pacman -S dhcpcd
- (wireless) pacman -S wpa_supplicant dialog wireless_tools
## TODO: Use networkmanager
- pacman -S connman-openrc 
- rc-update add connmand

- exit
- umount -R /mnt
- reboot

# POSTINSTALL

## Add Arch package support
- pacman -S artix-archlinux-support
- add the repositories to /etc/pacman.conf
- pacman-key --populate archlinux

## X11 install
- pacman -S xorg-server xorg-apps xorg-xinit

- (intel) pacman -S xf86-video-intel lib32-intel-dri lib32-mesa lib32-libgl
- (nvidia) pacman -S nvidia-utils-openrc nvidia-utils nvidia-dkms \
    lib32-nvidia-utils lib32-nvidia-libgl nvidia-settings

## TODO: Needed ???
- pacman -S elogind elogind-openrc
- rc-update add elogind

# KDE install
- pacman -S sddm-openrc sddm plasma plasma-nm ttf-dejavu ttf-liberation
- rc-update add sddm
- pacman -S akonadi-calendar-tools akonadi-import-wizard akonadiconsole \
    akregator ark dolphin dolphin-plugins ffmpegthumbs filelight kalarm kcalc \
    kcharselect kcolorchooser kcron kde-dev-utils kdenlive kdepim-addons kdf \
    kdialog kfind kgpg kleopatra kmail kmail-account-wizard kmix kompare konsole \
    kontact konversation kopete korganizer krdc ksystemlog ktouch kwalletmanager \
    kwrite markdownpart partitionmanager svgpart sweeper umbrello 

## TODO: Install ungoogled-chromium

- pacman -S zsh git wget code discord teamspeak3 telegram-desktop qbittorrent \
    obs-studio qemu libvirt virt-manager gnome-clocks

# ?? package replacements
- kate (instead of kwrite?)
- cervisia (version management gui)

- usermod -s /bin/zsh root
- usermod -s /bin/zsh felix

# CUSTOMIZATION

- enable color in /etc/pacman.conf

## TODO: Parachute
https://github.com/tcorreabr/Parachute
https://www.reddit.com/r/kde/comments/me68sm/comment/gsdubkf

- Open KRunner with Meta key:
 - kwriteconfig5 --file kwinrc --group ModifierOnlyShortcuts --key Meta "org.kde.krunner,/App,,display"
