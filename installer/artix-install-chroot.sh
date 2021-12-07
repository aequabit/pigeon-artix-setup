#!/usr/bin/env bash

source /root/artix-install-config.sh

# Read the passphrase and delete the temporary file
ARTIX_LUKS_PASSPHRASE=$(cat /luks-passphrase)
rm -f /luks-passphrase

# Update repositories
pacman -Sy

# Create LUKS keyfile
#  TODO: Could be done outside of chroot, making /luks-passphrase obsolete
dd if=/dev/random of=/crypto_keyfile.bin bs=512 count=8 iflag=fullblock
chmod 000 /crypto_keyfile.bin
sed -i "s/FILES=(/FILES=(\/crypto_keyfile.bin/g" /etc/mkinitcpio.conf
echo -n "${ARTIX_LUKS_PASSPHRASE}" | cryptsetup luksAddKey "${ARTIX_DISK_LVM}" /crypto_keyfile.bin -

# TODO: VFIO setup

# Remove Artix GRUB theme
#  Fixes issue at end of post: https://forum.artixlinux.org/index.php/topic,1541.msg10698.html#msg10698
pacman -Rc --noconfirm artix-grub-theme

# Enable initramfs hooks
sed -i "s/block filesystems/block keyboard keymap encrypt lvm2 resume filesystems/g" /etc/mkinitcpio.conf
mkinitcpio -P

LVM_PARTITION_UUID=$(blkid -s UUID -o value "${ARTIX_DISK_LVM}")

# Set kernel commandline
#  TODO: Optimize swap-specific options
if [ "${ARTIX_SWAP_SIZE_GB}" != "0" ]; then
    sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${LVM_PARTITION_UUID}:vg0 root=\/dev\/vg0\/lv-root resume=\/dev\/vg0\/lv-swap\"/g" /etc/default/grub
else
    sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${LVM_PARTITION_UUID}:vg0 root=\/dev\/vg0\/lv-root\"/g" /etc/default/grub
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
echo "127.0.0.1 localhost ${ARTIX_HOSTNAME}.localdomain ${ARTIX_HOSTNAME}" >> /etc/hosts
echo "127.0.1.1 localhost ${ARTIX_HOSTNAME}.localdomain ${ARTIX_HOSTNAME}" >> /etc/hosts
echo "::1 localhost ${ARTIX_HOSTNAME}.localdomain ${ARTIX_HOSTNAME}" >> /etc/hosts

# Install wireless packages if needed
if [ "${ARTIX_WIRELESS}" != "0" ]; then
    pacman -S --noconfirm -q wpa_supplicant dialog wireless_tools
fi

# Install networkmanager
pacman -S --noconfirm -q networkmanager networkmanager-openrc networkmanager-openvpn network-manager-applet
rc-update add NetworkManager default

# Install additional services
pacman -S --noconfirm -q ntp ntp-openrc acpid acpid-openrc syslog-ng syslog-ng-openrc
rc-update add ntpd default
rc-update add acpid default
rc-update add syslog-ng default

# Disable beep
echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf

# Enable pacman colors
sed -i "s/#Color/Color/g" /etc/pacman.conf

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

# Install necessary X packages
pacman -S --noconfirm -q xorg-server xorg-apps xorg-xinit

# Install vendor-specific graphics packages
if [ "${ARTIX_GFX_VENDOR}" = "intel" ]; then
    pacman -S --noconfirm -q xf86-video-intel lib32-mesa lib32-libgl
elif [ "${ARTIX_GFX_VENDOR}" = "nvidia" ]; then
    pacman -S --noconfirm -q nvidia-utils-openrc nvidia-utils nvidia-dkms \
        lib32-nvidia-utils lib32-nvidia-libgl nvidia-settings
elif [ "${ARTIX_GFX_VENDOR}" = "amd" ]; then
    # TODO: AMD graphics packages
    echo "currently no amd gfx support"
fi

# Install elogind, SDDM and KDE
pacman -S --noconfirm -q elogind elogind-openrc sddm sddm-openrc plasma plasma-nm ttf-dejavu ttf-liberation
rc-update add elogind
rc-update add sddm

# Install KDE applications
# pacman -S --noconfirm -q akonadi-calendar-tools akonadi-import-wizard akonadiconsole \
#     akregator ark dolphin dolphin-plugins ffmpegthumbs filelight kalarm kcalc \
#     kcharselect kcolorchooser kcron kde-dev-utils kdenlive kdepim-addons kdf \
#     kdialog kfind kgpg kleopatra kmail kmail-account-wizard kmix kompare konsole \
#     kontact konversation kopete korganizer krdc ksystemlog ktouch kwalletmanager \
#     kwrite markdownpart partitionmanager svgpart sweeper umbrello

# Additional applications
# pacman -S --noconfirm -q code discord teamspeak3 telegram-desktop \
#     qbittorrent obs-studio qemu libvirt virt-manager gnome-clocks

# Add ungoogled-chromium repository (https://github.com/ungoogled-software/ungoogled-chromium-archlinux)
curl -s 'https://download.opensuse.org/repositories/home:/ungoogled_chromium/Arch/x86_64/home_ungoogled_chromium_Arch.key' | sudo pacman-key -a -
echo '[home_ungoogled_chromium_Arch]
SigLevel = Required TrustAll
Server = https://download.opensuse.org/repositories/home:/ungoogled_chromium/Arch/$arch
' | tee --append /etc/pacman.conf

# Install ungoogled-chromium
pacman -Sy ungoogled-chromium

# TODO: Custom user-dirs

# TODO: Install AUR packages to ~/pkg
#  yay lightly-qt

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