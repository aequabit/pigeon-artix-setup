#!/usr/bin/env bash

# TODO: Presets (desktop, mobile, server?)
# TODO: KDE application sets (reduced, essential)
# TODO: Wizard to generate config
# TODO: Arch support
# TODO: Keep hashes of config files, scan before - run guided editor if changed

function read_password() {
  stty -echo
  printf "${1}"
  read "${2}"
  stty echo
  printf "\n"
}

source ./artix-install-config.sh

read_password "Enter your desired LUKS passphrase: " ARTIX_LUKS_PASSPHRASE

# Don't run if target disk is not attached
if [ ! -e "${ARTIX_DISK}" ]; then
    echo "${ARTIX_DISK} doesn't exist, exiting"
    exit 1
fi

# Since we want to be as modular as possible,
# the most permanent partitions will be created first.
# This layout is preferable: 
# 
# lvm (/dev/xxx1)
#  -> lv-home
#  -> lv-root
#  -> (lv-swap)
# efi (/dev/xxx2)
# 

(
    echo g # Create GPT

    echo n     # Create LVM partition
    echo 1     # Partition 1
    echo       # Confirm default (beginning of disk)
    echo -800M # Leave 300MB for EFI partition (+500MB for optional boot partition)
    echo Y     # Confirm signature removal (ignored if not present)
    echo t     # Change type
    echo 30    # Linux LVM

    echo n # Create EFI partition
    echo 2 # Partition 2
    echo   # Confirm default (end of last partition)
    echo   # Confirm default (rest of disk)
    echo Y # Confirm signature removal (ignored if not present)
    echo t # Change type
    echo 2
    echo 1 # EFI System

    echo w # Write changes
) | fdisk "${ARTIX_DISK}"

# Format EFI partition
mkfs.fat -n PTEFI -F32 "${ARTIX_DISK_EFI}"

# Format LVM partition
#  LUKS1 is required since GRUB doesn't support booting from LUKS2 - see this:
#   https://wiki.archlinux.org/title/GRUB#Encrypted_/boot
#   https://savannah.gnu.org/bugs/?55093
echo -n "${ARTIX_LUKS_PASSPHRASE}" | cryptsetup luksFormat --type luks1 --cipher aes-xts-plain64 --use-random "${ARTIX_DISK_LVM}" --batch-mode -
echo -n "${ARTIX_LUKS_PASSPHRASE}" | cryptsetup luksOpen "${ARTIX_DISK_LVM}" lvm -

# Create LVM container and volume group 
pvcreate /dev/mapper/lvm
vgcreate vg0 /dev/mapper/lvm

# Calculate logical volume sizes
PV_CAPACITY_BYTES=$(pvdisplay /dev/mapper/lvm -s --units B | tr -d -c 0-9)
LV_ROOT_SIZE_BYTES=$(echo "$ARTIX_ROOT_SIZE_GB * 1024 * 1024 * 1024" | bc)
LV_SWAP_SIZE_BYTES=$(echo "$ARTIX_SWAP_SIZE_GB * 1024 * 1024 * 1024" | bc)
LV_HOME_SIZE_BYTES=$(echo "$PV_CAPACITY_BYTES - $LV_ROOT_SIZE_BYTES - $LV_SWAP_SIZE_BYTES" | bc);

# Create logical volumes
lvcreate --name lv-home --size "${LV_HOME_SIZE_BYTES}B" vg0
lvcreate --name lv-root --size "${LV_ROOT_SIZE_BYTES}B" vg0

# Create and format swap if enabled
if [ "${ARTIX_SWAP_SIZE_GB}" != "0" ]; then
    lvcreate --name lv-swap --size "${LV_SWAP_SIZE_BYTES}B" vg0
    mkswap -L pt-swap /dev/vg0/lv-swap
    swapon /dev/vg0/lv-swap
fi

# Format logical volumes
mkfs.ext4 -L pt-root /dev/vg0/lv-root
mkfs.ext4 -L pt-home /dev/vg0/lv-home

# Mount root volume
mount /dev/vg0/lv-root /mnt

# Create boot and home directories
mkdir /mnt/boot /mnt/home

# Mount home partition
mount /dev/vg0/lv-home /mnt/home

# Mount EFI partition
mkdir /mnt/boot/efi
mount "${ARTIX_DISK_EFI}" /mnt/boot/efi

# Update pacman repositories
pacman -Sy

# Bootstrap the base system
basestrap /mnt base base-devel openrc \
    linux-zen linux-zen-headers linux-firmware \
    cryptsetup cryptsetup-openrc lvm2 lvm2-openrc \
    sudo wget curl nano grub os-prober efibootmgr dosfstools freetype2 fuse2 gptfdisk libisoburn mtools os-prober \
    "${ARTIX_USER_SHELL}" "${ARTIX_VENDOR}-ucode"

# Create fstab
fstabgen -U /mnt >> /mnt/etc/fstab

# Copy scripts for the next installation step
cp /root/artix-install-config.sh /mnt/root
cp /root/artix-install-chroot.sh /mnt/root

# Save the LUKS passphrase temporarily for the chroot environment
printf "${ARTIX_LUKS_PASSPHRASE}" > /mnt/luks-passphrase

# Run the next stage inside the chroot environment
artix-chroot /mnt /root/artix-install-chroot.sh

# artix-chroot /mnt /bin/bash

# Unmount all partitions
umount -a

# :^)
reboot
