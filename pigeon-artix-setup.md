# Use cases
- Replacement for Arch desktop distribution (Garuda, Endeavour etc.)

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
- Store installer in /opt, provide option to run certain steps while in the system (package bundles, applications etc.)
- Calculate recommended partition sizes (55GB for 512GB drive)
- Print commands that are run, log to file
- Sanity checks at every step
- Don't autoconfirm certain steps (package installations with optional dependencies) to let the user choose  when using the guided installer
- base directory = SETUP_BASE | XDG_SHARE/pigeon-artix-setup | /usr/share/pigeon-artix-setup
- Powerline console fonts (aur/powerline-console-fonts-git, rename according to https://superuser.com/a/1532933)
- Gaming optimization toggle (Wine + Winetricks + Protontricks, Lutris, Esync, Steam)
- Select kernels
- Support multiple locales, more precise control (time, monetary etc.)
- Custom XDG directories
- Make separate boot partition/volume optional 
- Source empty default configuration before the user's to ensure variables introduced by a newer version still get set when using old config files
- Enable password prompting via separate variable
- Define package groups in advanced section in configuration file
 - KDE_APPLICATIONS="konsole ..."
 - Additional packages defined in KDE_APPLICATIONS_CUSTOM so merging is easier
 - Description for each package whose name isn't obvious
- KDE global menu + gtk appmenu
- Proper microcode support (initrd enable?)
- ext4 SSD trim support (disclaimer: https://forums.freebsd.org/threads/56951/#post-328912:~:text=Ext4%27s%20discard%20feature)
- Optional rankmirrors support
- Copy all touched files to .bak
- Guided config generator (sane defaults or ask all options)
- _ENABLE flags for major features (LVM, VFIO, swap ...) and options  that are ignored if feature is turned off
- Group packages, wrap pacman
- Make encrypted /boot optional, notify user that some features will not work with it (i.e. remembering last GRUB selection)
- More configuration (disk labels, volume names ...)
- Legacy support
- Make LVM optional
- Provide option to automatically add ungoogled-chromium pacman repository
- Init system selection
- Semi-automatic detection of PCIe devices for VFIO passthrough
- Allow user to specify additional packages to be installed
- Allow user to set partition numbers manually and launch fdisk for manual partitioning
- Add prints at most steps, suppress large output (pacman, fdisk etc.) and only display errors
- Allow user to choose if /home should be a separate partition/volume
- Add support for installing AUR packages (place repositories in /home/$ARTIX_USER_NAME/pkg) 
- Split installation process into multiple files, source in optional steps
 - Custom steps (20-partition, ignore if 20-partition.custom exists, provide 20-partition.custom-example)
 - ? Custom scripts that can be inserted at specific install stages
- If any partitions exist on the target disk, force the user to type something in to wipe and provide flag to wipe without confirmation
- Presets (desktop, mobile, server)
- KDE, GNOME, XFCE application sets (reduced, essential)
- suckless application set
- Wizard to generate config
- Arch support
- Keep hashes of config files, scan before - run guided editor if changed
- Parallel pacman downloads
- use variables wherever possible
- extend rn script?
 - list of packages to replace with the -openrc, -s6 etc. variants
- make interactive script?
 - ! full ci integration (installer boot to working system)
 - backup all files
 - log all actions
 - don't automatically edit configs, launch editor to do so
  - ! keep hashes of configuration files - only prompt if unknown (show diff between old original config and update one)
   - ? scan before to know if installation requires interaction
  - prepend small, commented guide on what to change

## artix-base-openrc-20211121-x86_64

# SETUP

- loadkeys de

- fdisk
 - 300MB efi
 - 500MB boot
 - lvm container
  - 80GB root
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

## TODO: KDE Latte?

- Kvantum theme?
- Papirus icons?
- KRunner in screen center
- Open KRunner with Meta key:
 - kwriteconfig5 --file kwinrc --group ModifierOnlyShortcuts --key Meta "org.kde.krunner,/App,,toggleDisplay"
