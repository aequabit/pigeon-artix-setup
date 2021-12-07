#!/usr/bin/env bash

source /root/artix-install-config.sh

# Update repositories
pacman -Sy

# Set keymap
sed -r "s/(keymap *= *\").*/\1${ARTIX_KEYMAP}1\"/" /etc/conf.d/keymaps > /etc/conf.d/keymaps
sed -r "s/(KEYMAP *= *).*/\1${ARTIX_KEYMAP}/" /etc/vconsole.conf > /etc/vconsole.conf

# Set timezone
ln -sf "/usr/share/zoneinfo/${ARTIX_TIMEZONE}" /etc/localtime
hwclock --systohc

# Generate locales
locale-gen
echo 'LC_COLLATE="C"' >> /etc/locale.conf

# TODO: VFIO setup

# Fix for issue at end of post: https://forum.artixlinux.org/index.php/topic,1541.msg10698.html#msg10698
pacman -Rc --noconfirm -y artix-grub-theme

# Update initramfs
sed -i "s/block filesystems/block keymap encrypt lvm2 resume filesystems/g" /etc/mkinitcpio.conf
mkinitcpio -P

# Install GRUB
if [ "${ARTIX_LEGACY}" != "0" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="${ARTIX_BOOTLOADER_ID}" --removable --recheck --debug "${ARTIX_DISK}"
else
    echo 1
    # TODO: BIOS install
fi

# Set kernel commandline
# TODO: Optimize swap-specific options
if [ "${ARTIX_SWAP_SIZE_GB}" != "0" ]; then
    # TODO: Specify device via UUID instead of device path (  )
    # FIXME: Fails
    LVM_PARTITION_UUID=$(blkid -s UUID -o value "${ARTIX_DISK_LVM}")
    sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${LVM_PARTITION_UUID}:vg0 root=\/dev\/mapper\/vg0-lv-root resume=\/dev\/mapper\/vg0-lv-swap\"/g" /etc/default/grub
else
    sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${LVM_PARTITION_UUID}:vg0 root=\/dev\/mapper\/vg0-lv-root\"/g" /etc/default/grub
fi

# Enable LVM support for GRUB
sed -i "s/#GRUB_ENABLE_CRYPTODISK/GRUB_ENABLE_CRYPTODISK/g" /etc/default/grub

# Remember last GRUB selection
sed -i "s/GRUB_DEFAULT=0/GRUB_DEFAULT=saved/g" /etc/default/grub
sed -i "s/#GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=true/g" /etc/default/grub

# Change GRUB colors
sed -i "s/#GRUB_COLOR_NORMAL=\"light-blue/black\"/GRUB_COLOR_NORMAL=\"${ARTIX_GRUB_COLOR}\"/g" /etc/default/grub
sed -i "s/#GRUB_COLOR_HIGHLIGHT=\"light-cyan/blue\"/GRUB_COLOR_HIGHLIGHT=\"${ARTIX_GRUB_COLOR_HIGHLIGHT}\"/g" /etc/default/grub

# Create GRUB config
grub-mkconfig -o /boot/grub/grub.cfg

# Set root password
usermod -s "/bin/${ARTIX_USER_SHELL}" root
echo "root:${ARTIX_ROOT_PASSWORD}" | chpasswd

# Create user and set password
useradd -m "${ARTIX_USER}" -G "${ARTIX_USER_GROUPS}" -s "/bin/${ARTIX_USER_SHELL}"
echo "${ARTIX_USER}:${ARTIX_USER_PASSWORD}" | chpasswd

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
# pacman -S --noconfirm -q git wget code discord teamspeak3 telegram-desktop \
#     qbittorrent obs-studio qemu libvirt virt-manager gnome-clocks "${ARTIX_USER_SHELL}"