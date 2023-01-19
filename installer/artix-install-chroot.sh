#!/usr/bin/env bash

# Source the temporary config file and delete it
# source /.artix-install-config.tmp
# rm -f /.artix-install-config.tmp

# Update repositories
pacman -Sy

# Create LUKS keyfile
dd if=/dev/random of=/crypto_keyfile.bin bs=512 count=8 iflag=fullblock
chmod 000 /crypto_keyfile.bin
sed -i "s/FILES=(/FILES=(\/crypto_keyfile.bin/g" /etc/mkinitcpio.conf
echo -n "${ARTIX_LUKS_PASSPHRASE}" | cryptsetup luksAddKey "${ARTIX_DISK_LVM}" /crypto_keyfile.bin -

# TODO: VFIO setup

# Remove Artix GRUB theme
#  Fixes issue at end of post: https://forum.artixlinux.org/index.php/topic,1541.msg10698.html#msg10698
pacman -Rc --noconfirm artix-grub-theme

# Enable initramfs hooks
# TODO: Add resume option only if swap is enabled and at least the size of ram
sed -i "s/block filesystems/block keyboard keymap encrypt lvm2 filesystems/g" /etc/mkinitcpio.conf
mkinitcpio -P

LVM_PARTITION_UUID=$(blkid -s UUID -o value "${ARTIX_DISK_LVM}")

# Set kernel commandline
#  TODO: Optimize swap-specific options
if [ "${ARTIX_SWAP_SIZE_GB}" != "0" ]; then
    sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${LVM_PARTITION_UUID}:vg root=\/dev\/vg\/lv-root resume=\/dev\/vg\/lv-swap\"/g" /etc/default/grub
else
    sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${LVM_PARTITION_UUID}:vg root=\/dev\/vg\/lv-root\"/g" /etc/default/grub
fi

# Enable LVM support for GRUB
sed -i "s/#GRUB_ENABLE_CRYPTODISK/GRUB_ENABLE_CRYPTODISK/g" /etc/default/grub

# Remember last GRUB selection
#  Breaks when boot partition in LVM: https://bugs.launchpad.net/ubuntu/+source/grub2/+bug/1274320
# sed -i "s/GRUB_DEFAULT=0/GRUB_DEFAULT=saved/g" /etc/default/grub
# sed -i "s/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/g" /etc/default/grub

# Escape and set GRUB colors
GRUB_COLOR_NORMAL=$(printf '%s\n' "$ARTIX_GRUB_COLOR_NORMAL" | sed -e 's/[\/&]/\\&/g')
GRUB_COLOR_HIGHLIGHT=$(printf '%s\n' "$ARTIX_GRUB_COLOR_HIGHLIGHT" | sed -e 's/[\/&]/\\&/g')
sed -i "s/#GRUB_COLOR_NORMAL=\"light-blue\/black\"/GRUB_COLOR_NORMAL=\"${GRUB_COLOR_NORMAL}\"/g" /etc/default/grub
sed -i "s/#GRUB_COLOR_HIGHLIGHT=\"light-cyan\/blue\"/GRUB_COLOR_HIGHLIGHT=\"${GRUB_COLOR_HIGHLIGHT}\"/g" /etc/default/grub

# Enable wheel group permissions
sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g" /etc/sudoers

# Install GRUB 
if [ "${ARTIX_LEGACY}" != "0" ]; then
    echo "legacy boot currently unsupported"
    exit 1
    # grub-install --target=i386-pc --boot-directory=/boot --bootloader-id="${ARTIX_BOOTLOADER_ID}" --recheck "${ARTIX_DISK}"
else
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="${ARTIX_BOOTLOADER_ID}" --removable --recheck "${ARTIX_DISK}"
fi

# Create GRUB config
grub-mkconfig -o /boot/grub/grub.cfg

# Set root password
usermod -s "/bin/${ARTIX_USER_SHELL}" root
echo -e "${ARTIX_ROOT_PASSWORD}\n${ARTIX_ROOT_PASSWORD}" | passwd root

# Create user and set password
useradd -m -G "${ARTIX_USER_GROUPS}" -s "/bin/${ARTIX_USER_SHELL}" "${ARTIX_USER}"
echo -e "${ARTIX_USER_PASSWORD}\n${ARTIX_USER_PASSWORD}" | passwd "${ARTIX_USER}"

# Create custom XDG directories
source "/home/${ARTIX_USER}/.config/user-dirs.dirs"
mkdir -p "${XDG_DESKTOP_DIR}" "${XDG_DOWNLOAD_DIR}" "${XDG_TEMPLATES_DIR}" \
         "${XDG_PUBLICSHARE_DIR}" "${XDG_DOCUMENTS_DIR}" "${XDG_MUSIC_DIR}" \
         "${XDG_PICTURES_DIR}" "${XDG_VIDEOS_DIR}"

# Set keymap
echo "keymap=${ARTIX_KEYMAP}" > /etc/conf.d/keymaps
echo "KEYMAP=${ARTIX_KEYMAP}" > /etc/vconsole.conf

# Set timezone
ln -sf "/usr/share/zoneinfo/${ARTIX_TIMEZONE}" /etc/localtime
hwclock --systohc

# Set locales
locale-gen
printf "LANG=en_US.UTF-8\nLC_COLLATE=C\n" > /etc/locale.conf

# Set hostname
echo "${ARTIX_HOSTNAME}" > /etc/hostname
echo "hostname=\"${ARTIX_HOSTNAME}\"" > /etc/conf.d/hostname

# Configure hostfile
#  TODO: Single write command
echo "127.0.0.1 localhost ${ARTIX_HOSTNAME}.localdomain ${ARTIX_HOSTNAME}" >> /etc/hosts
echo "127.0.1.1 localhost ${ARTIX_HOSTNAME}.localdomain ${ARTIX_HOSTNAME}" >> /etc/hosts
echo "::1 localhost ${ARTIX_HOSTNAME}.localdomain ${ARTIX_HOSTNAME}" >> /etc/hosts

# Install wireless packages if needed
if [ "${ARTIX_WIRELESS}" != "0" ]; then
    pacman -S --noconfirm -q wpa_supplicant dialog wireless_tools
fi

# Install iptables
# TODO: Seems to break, download rc files manually?
# https://gitea.artixlinux.org/artixlinux/packages-openrc/raw/branch/master/iptables-openrc
pacman -S --noconfirm -q iptables-openrc iptables
rc-update add iptables default

# Install ebtables and firewalld (for libvirt, might be unnecessary)
# NOTE: ebtables scripts are included in the iptables-openrc package above
# pacman -S --noconfirm -q ebtables firewalld-openrc firewalld

# TODO: aur/ebtables aur/ebtables

# firewalld still expects nftables as the firewall backend by default, we probably don't want that
sed -i "s/FirewallBackend=nftables/FirewallBackend=iptables/g" /etc/firewalld/firewalld.conf

# Install networkmanager
pacman -S --noconfirm -q networkmanager-openrc networkmanager network-manager-applet
rc-update add NetworkManager default

# Install additional services
pacman -S --noconfirm -q ntp-openrc ntp acpid-openrc acpid syslog-ng-openrc syslog-ng
rc-update add ntpd default
rc-update add acpid default
rc-update add syslog-ng default

# Disable beep
echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf

# Enable pacman colors
sed -i "s/#Color/Color/g" /etc/pacman.conf

# Enable parallel pacman downloads
# TODO: optional
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = ${ARTIX_PACMAN_PARALLEL_DOWNLOADS}/g" /etc/pacman.conf

# Install support for Arch packages
pacman -S --noconfirm -q artix-archlinux-support

# Enable Arch package mirrors
echo "
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[community]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
" >> /etc/pacman.conf

# Import Arch package keys
pacman-key --populate archlinux

# Enable the lib32 repository
sed -i "/\[lib32\]/,/Include/"'s/^#//' /etc/pacman.conf

# Place favorable mirrors at the top
sed -i "s/## Europe/Server = https:\/\/ftp.ludd.ltu.se\/mirrors\/artix\/\$repo\/os\/\$arch\nServer = https:\/\/mirror.pascalpuffke.de\/artix-linux\/\$repo\/os\/\$arch\n\n## Worldwide/g" /etc/pacman.d/mirrorlist
sed -i "s/## Worldwide/Server = http:\/\/ftp.halifax.rwth-aachen.de\/archlinux\/\$repo\/os\/\$arch\nServer = http:\/\/ftp.u-strasbg.fr\/linux\/distributions\/archlinux\/\$repo\/os\/\$arch\n\n## Worldwide/g" /etc/pacman.d/mirrorlist-arch

# Update repositories
pacman -Sy

# Install systemd compatibility
pacman -S --noconfirm -q lib32-artix-archlinux-support

# Install necessary X packages
pacman -S --noconfirm -q xorg-server xorg-apps xorg-xinit

# Install vendor-specific graphics packages
if [ "${ARTIX_GFX_VENDOR}" = "intel" ]; then
    pacman -S --noconfirm -q xf86-video-intel lib32-mesa lib32-libgl
elif [ "${ARTIX_GFX_VENDOR}" = "nvidia" ]; then
    pacman -S --noconfirm -q nvidia-utils-openrc nvidia-dkms \
        nvidia-utils lib32-nvidia-utils lib32-nvidia-libgl \
        mesa-utils lib32-mesa-utils mesa-vdpau lib32-mesa-vdpau \
        nvidia-settings

    echo 'ACTION=="add", DEVPATH=="/bus/pci/drivers/nvidia", RUN+="/usr/bin/nvidia-modprobe -c0 -u"' > /etc/udev/rules.d/70-nvidia.rules
elif [ "${ARTIX_GFX_VENDOR}" = "amd" ]; then
    # TODO: AMD graphics packages
    echo "currently no amd gfx support"
fi

# Install SDDM and KDE
pacman -S --noconfirm -q sddm-openrc sddm sddm-kcm plasma plasma-nm ttf-dejavu ttf-liberation
rc-update add elogind
rc-update add sddm

# # Set SDDM keymap
# echo "setxkbmap ${ARTIX_KEYMAP}" > /usr/share/sddm/scripts/Xsetup

# # Fix SDDM for NVIDIA
# if [ "${ARTIX_GFX_VENDOR}" = "nvidia" ]; then
#   echo "xrandr --setprovideroutputsource modesetting NVIDIA-0" > /usr/share/sddm/scripts/Xsetup
#   echo "xrandr --auto" > /usr/share/sddm/scripts/Xsetup
# fi

# KDE application packages
# pacman -S --noconfirm -q akonadi-calendar-tools akonadi-import-wizard akonadiconsole \
#     akregator ark dolphin dolphin-plugins ffmpegthumbs filelight gimp kalarm kcalc \
#     kcharselect kcolorchooser kcron kde-dev-utils kdenlive kdepim-addons kdf \
#     kdialog kfind kgpg kleopatra kmail kmail-account-wizard kmix kompare konsole \
#     kontact konversation kopete korganizer krdc ksystemlog ktouch kwalletmanager \
#     kwallet ksshaskpass kwrite markdownpart partitionmanager svgpart sweeper umbrello

# Quality of life packages
# pacman -S --noconfirm -q pulseaudio-equalizer-ladspa okular p7zip net-tools

# Virtualization packages
# pacman -S --noconfirm -q libvirt-openrc libvirt dnsmasq-openrc dnsmasq virt-manager edk2-ovmf
# rc-update add libvirtd

# Additional applications
# pacman -S --noconfirm -q qemu libvirt-openrc libvirt virt-manager wine-staging \
#     baobab gnome-clocks xfce4-taskmanager qbittorrent

# OpenVPN
# pacman -S --noconfirm -q networkmanager-openvpn openvpn-openrc openvpn

# Custom applications
# pacman -S --noconfirm -q discord teamspeak3 telegram-desktop obs-studio

# Enable kwallet-pam (for kwallet unlock on login)
# sed -i "s/-auth   optional  pam_kwallet5.so/auth   optional  pam_kwallet5.so/g" /etc/pam.d/sddm
# sed -i "s/-session  optional  pam_kwallet5.so/session  optional  pam_kwallet5.so/g" /etc/pam.d/sddm

# Add ungoogled-chromium repository (https://github.com/ungoogled-software/ungoogled-chromium-archlinux)
curl -s 'https://download.opensuse.org/repositories/home:/ungoogled_chromium/Arch/x86_64/home_ungoogled_chromium_Arch.key' | pacman-key -a -
echo '[home_ungoogled_chromium_Arch]
SigLevel = Required TrustAll
Server = https://download.opensuse.org/repositories/home:/ungoogled_chromium/Arch/$arch
' | tee --append /etc/pacman.conf

# Install ungoogled-chromium
pacman -Sy --noconfirm -q ungoogled-chromium

# TODO: Custom user-dirs

# Fix KDE opening image URLs in the image viewer
xdg-settings set default-url-scheme-handler http

# TODO: Install AUR packages to ~/pkg
#  yay ebtables qview lightly-qt ttf-meslo-nerd-font-powerlevel10k zsh-theme-powerlevel10k-git visual-studio-code-bin

# # Enable NOPASSWD for nobody
# printf 'nobody ALL=(ALL) NOPASSWD: ALL\n' | tee -a /etc/sudoers

# # Install grub-git from the AUR (fixes boot from LUKS2-encrypted partitions)
# sudo -u nobody git clone https://aur.archlinux.org/grub-git.git /tmp/grub-git
# cd /tmp/grub-git
# sudo -u nobody makepkg -si --noconfirm

# # Create backup of package
# cp /tmp/grub-git/grub-git-*.pkg.tar.zst /root

# # Disable NOPASSWD for nobody
# sed -i "s/nobody ALL=(ALL) NOPASSWD: ALL//g" /etc/sudoers

# TODO: do aur installs with doas

# TODO: Install KDE Lightly Theme + Aritim Dark
# FIX: https://github.com/Luwx/Lightly/issues/93#issuecomment-813330541
# https://github.com/Luwx/Lightly/blob/master/kstyle/lightly.kcfg#L213

# Setup doas as a more lightweight replacement for sudo
# pacman -S --noconfirm -y doas
# echo -e "permit :wheel\npermit persist ${ARTIX_USER} as root\n" > /etc/doas.conf
# pacman -R --noconfirm -y sudo
# ln -s /usr/bin/doas /usr/bin/sudo

# Change maximum number of files a process can open (needed for Esync)
# TODO: Insert before EOF comment
# echo '${ARTIX_USER} hard nofile 524288' > /etc/security/limits.conf

# https://github.com/LukeSmithxyz/LARBS/blob/master/larbs.sh
# https://github.com/LukeSmithxyz/voidrice

# TODO: Modularize post-setup into separate files

# Install docker
# pacman -S --noconfirm -y docker-openrc docker docker-compose
# rc-update add docker default
# usermod -G docker -a "${ARTIX_USER}"
