#!/usr/bin/env bash

source /root/artix-install-config.sh

# Update repositories
pacman -Sy

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

# TODO: VFIO setup

# Fix for issue at end of post: https://forum.artixlinux.org/index.php/topic,1541.msg10698.html#msg10698
pacman -Rc --noconfirm artix-grub-theme

# Update initramfs
sed -i "s/block filesystems/block keyboard keymap encrypt lvm2 resume filesystems/g" /etc/mkinitcpio.conf
mkinitcpio -P

# Install GRUB 
if [ "${ARTIX_LEGACY}" != "0" ]; then
    grub-install --target=i386-pc --boot-directory=/boot --bootloader-id="${ARTIX_BOOTLOADER_ID}" --recheck "${ARTIX_DISK}"
else
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="${ARTIX_BOOTLOADER_ID}" --removable --recheck "${ARTIX_DISK}"
fi

LVM_PARTITION_UUID=$(blkid -s UUID -o value "${ARTIX_DISK_LVM}")

# LUKS2 workaround - doesn't seem to work
# # Fix for issue at end of post: https://forum.artixlinux.org/index.php/topic,1541.msg10698.html#msg10698
# cat <<EOT > /root/grub-pre.cfg
# set crypto_uuid=${LVM_PARTITION_UUID}
# cryptomount -u \$crypto_uuid
# set root=cryptouuid/\$crypto_uuid
# set prefix=(\$root)/boot/grub
# insmod normal
# normal
# EOT

# cat <<EOT > /root/update-grub.sh
# grub-mkconfig -o /boot/grub/grub.cfg
# grub-mkimage -p /boot/grub -O x86_64-efi -c /root/grub-pre.cfg -o /tmp/grubx64.efi luks2 part_gpt cryptodisk gcry_rijndael pbkdf2 gcry_sha256 ext2 lvm
# install -v /tmp/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
# EOT

# chmod +x /root/update-grub.sh
# /root/update-grub.sh

# Set kernel commandline
# TODO: Optimize swap-specific options
if [ "${ARTIX_SWAP_SIZE_GB}" != "0" ]; then
    # FIXME: Fails
    sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${LVM_PARTITION_UUID}:vg0 root=\/dev\/vg0\/lv-root resume=\/dev\/vg0\/lv-swap\"/g" /etc/default/grub
else
    sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${LVM_PARTITION_UUID}:vg0 root=\/dev\/vg0\/lv-root\"/g" /etc/default/grub
fi

# Enable LVM support for GRUB
sed -i "s/#GRUB_ENABLE_CRYPTODISK/GRUB_ENABLE_CRYPTODISK/g" /etc/default/grub

# Remember last GRUB selection
sed -i "s/GRUB_DEFAULT=0/GRUB_DEFAULT=saved/g" /etc/default/grub
sed -i "s/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/g" /etc/default/grub

# Escape GRUB colors
GRUB_COLOR_NORMAL=$(printf '%s\n' "$ARTIX_GRUB_COLOR_NORMAL" | sed -e 's/[\/&]/\\&/g')
GRUB_COLOR_HIGHLIGHT=$(printf '%s\n' "$ARTIX_GRUB_COLOR_HIGHLIGHT" | sed -e 's/[\/&]/\\&/g')

# Change GRUB colors
sed -i "s/#GRUB_COLOR_NORMAL=\"light-blue\/black\"/GRUB_COLOR_NORMAL=\"${GRUB_COLOR_NORMAL}\"/g" /etc/default/grub
sed -i "s/#GRUB_COLOR_HIGHLIGHT=\"light-cyan\/blue\"/GRUB_COLOR_HIGHLIGHT=\"${GRUB_COLOR_HIGHLIGHT}\"/g" /etc/default/grub

# Create GRUB config
grub-mkconfig -o /boot/grub/grub.cfg

# Set root password
usermod -s "/bin/${ARTIX_USER_SHELL}" root
echo "root:${ARTIX_ROOT_PASSWORD}" | chpasswd

# Create user and set password
useradd -m "${ARTIX_USER}" -G "${ARTIX_USER_GROUPS}" -s "/bin/${ARTIX_USER_SHELL}"
echo "${ARTIX_USER}:${ARTIX_USER_PASSWORD}" | chpasswd

# Set keymap
sed -r "s/(keymap *= *\").*/\1${ARTIX_KEYMAP}1\"/" /etc/conf.d/keymaps > /etc/conf.d/keymaps
sed -r "s/(KEYMAP *= *).*/\1${ARTIX_KEYMAP}/" /etc/vconsole.conf > /etc/vconsole.conf

# Set timezone
ln -sf "/usr/share/zoneinfo/${ARTIX_TIMEZONE}" /etc/localtime
hwclock --systohc

# Generate locales
locale-gen
echo 'LC_COLLATE="C"' >> /etc/locale.conf

# Set hostname
echo "${ARTIX_HOSTNAME}" > /etc/hostname
echo "hostname=\"${ARTIX_HOSTNAME}\"" > /etc/conf.d/hostname

# Configure hostfile
echo "127.0.0.1 localhost ${ARTIX_HOSTNAME}.localdomain ${ARTIX_HOSTNAME}" >> /etc/hosts
echo "127.0.1.1 localhost ${ARTIX_HOSTNAME}.localdomain ${ARTIX_HOSTNAME}" >> /etc/hosts
echo "::1 localhost ${ARTIX_HOSTNAME}.localdomain ${ARTIX_HOSTNAME}" >> /etc/hosts

# Install wireless packages if needed
if [ "${ARTIX_WIRELESS}" != "0" ]; then
    pacman -S --noconfirm -q wpa_supplicant dialog wireless_tools
fi

# Install networkmanager
pacman -S --noconfirm -q networkmanager networkmanager-openrc networkmanager-openvpn network-manager-applet
rc-update add NetworkManager

# Install additional services
pacman -S --noconfirm -q ntp ntp-openrc acpid acpid-openrc syslog-ng syslog-ng-openrc
rc-update add ntpd default
rc-update add acpid default
rc-update add syslog-ng default

# Enable pacman colors
sed -i "s/#Color/Color/g" /etc/pacman.conf

# Add support for Arch packages
pacman -S --noconfirm -q artix-archlinux-support

echo "
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[community]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch" >> /etc/pacman.conf

pacman-key --populate archlinux

# Update repositories
pacman -Sy

echo "done!"
exit 0
# Install X
pacman -S --noconfirm -q xorg-server xorg-apps xorg-xinit

# Install vendor-specific graphics packages
if [ "${ARTIX_GFX_VENDOR}" = "intel" ]; then
    pacman -S --noconfirm -q xf86-video-intel lib32-mesa lib32-libgl
elif [ "${ARTIX_GFX_VENDOR}" = "nvidia" ]; then
    pacman -S --noconfirm -q nvidia-utils-openrc nvidia-utils nvidia-dkms \
        lib32-nvidia-utils lib32-nvidia-libgl nvidia-settings
elif [ "${ARTIX_GFX_VENDOR}" = "amd" ]; then
    echo 1
    # TODO: AMD packages
fi

# Install elogind, SDDM and KDE
pacman -S --noconfirm -q elogind elogind-openrc sddm-openrc sddm plasma plasma-nm ttf-dejavu ttf-liberation
rc-update add elogind
rc-update add sddm

# Install KDE applications
# pacman -S --noconfirm -q akonadi-calendar-tools akonadi-import-wizard akonadiconsole \
#     akregator ark dolphin dolphin-plugins ffmpegthumbs filelight kalarm kcalc \
#     kcharselect kcolorchooser kcron kde-dev-utils kdenlive kdepim-addons kdf \
#     kdialog kfind kgpg kleopatra kmail kmail-account-wizard kmix kompare konsole \
#     kontact konversation kopete korganizer krdc ksystemlog ktouch kwalletmanager \
#     kwrite markdownpart partitionmanager svgpart sweeper umbrello

# Install additional tools
# pacman -S --noconfirm -q wget code discord teamspeak3 telegram-desktop \
#     qbittorrent obs-studio qemu libvirt virt-manager gnome-clocks "${ARTIX_USER_SHELL}"