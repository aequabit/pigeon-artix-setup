#!/usr/bin/env bash

function read_password() {
  if [ $1 -eq 0 || $2 -eq 0 ]; then
    echo "example usage: read_password \"Enter your password: \" OUTPUT_VARIABLE_NAME"
  fi
  stty -echo
  printf "${1}"
  read "${2}"
  stty echo
  printf "\n"
}

source ./artix-install-config.sh

if [ "${ARTIX_LUKS_PASSPHRASE}" = "prompt" ]; then
    read_password "Enter your desired LUKS passphrase: " ARTIX_LUKS_PASSPHRASE
fi
if [ "${ARTIX_USER_PASSWORD}" = "prompt" ]; then
    read_password "Enter your desired user password: " ARTIX_USER_PASSWORD
fi
if [ "${ARTIX_ROOT_PASSWORD}" = "prompt" ]; then
    read_password "Enter your desired root password: " ARTIX_ROOT_PASSWORD
fi

# Don't run if target disk is not attached
if [ ! -e "${ARTIX_DISK}" ]; then
    echo "${ARTIX_DISK} doesn't exist, exiting"
    exit 1
fi

# Double check if running in VM (TODO: Remove)
if [ ! -e "/dev/vda" ]; then
    echo "/dev/vda does not exist, probably not running vm"
    echo "bye"
    exit 1
fi

# Upgrade the system
pacman -Sy

# Since we want to be as modular as possible, the most permanent partitions will be created first.
# This layout is preferable: 
#
# lvm (/dev/xxx1) (first, so changing bootloader, resizing to add partitions etc. is easier)
#  -> lv-home (first, so the root volume can be replaced without moving anything around)
#  -> lv-root
#  -> (lv-swap) (TODO: Maybe move up since it doesn't need to be removed when replacing the root volume?
#                      Would also make disabling it harder, though)
# efi (/dev/xxx2) (last, since it can be wiped and replaced at any time)
# 

# TODO: This could be replaced with parted, which is easier to automate. Don't like it's syntax, though.
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
vgcreate vg /dev/mapper/lvm

# Calculate logical volume sizes
PV_CAPACITY_BYTES=$(pvdisplay /dev/mapper/lvm -s --units B | tr -d -c 0-9)
LV_ROOT_SIZE_BYTES=$(echo "$ARTIX_ROOT_SIZE_GB * 1024 * 1024 * 1024" | bc)
LV_SWAP_SIZE_BYTES=$(echo "$ARTIX_SWAP_SIZE_GB * 1024 * 1024 * 1024" | bc)
LV_HOME_SIZE_BYTES=$(echo "$PV_CAPACITY_BYTES - $LV_ROOT_SIZE_BYTES - $LV_SWAP_SIZE_BYTES" | bc);

# Create logical volumes
lvcreate --name lv-home --size "${LV_HOME_SIZE_BYTES}B" vg
lvcreate --name lv-root --size "${LV_ROOT_SIZE_BYTES}B" vg

# Create and format swap if enabled
if [ "${ARTIX_SWAP_SIZE_GB}" != "0" ]; then
    lvcreate --name lv-swap --size "${LV_SWAP_SIZE_BYTES}B" vg
    mkswap -L pt-swap /dev/vg/lv-swap
    swapon /dev/vg/lv-swap
fi

# Format logical volumes
mkfs.ext4 -L pt-root /dev/vg/lv-root
mkfs.ext4 -L pt-home /dev/vg/lv-home

# Mount root volume
mount /dev/vg/lv-root /mnt

# Create boot and home directories
mkdir /mnt/boot /mnt/home

# Mount home partition
mount /dev/vg/lv-home /mnt/home

# Mount EFI partition
mkdir /mnt/boot/efi
mount "${ARTIX_DISK_EFI}" /mnt/boot/efi

# Bootstrap the base system
basestrap /mnt base base-devel openrc \
    linux-zen linux-zen-headers linux-firmware \
    elogind-openrc elogind cryptsetup-openrc cryptsetup lvm2-openrc lvm2 \
    sudo wget curl nano ntfs-3g grub os-prober efibootmgr dosfstools freetype2 fuse2 gptfdisk libisoburn mtools os-prober \
    "${ARTIX_USER_SHELL}" "${ARTIX_ROOT_SHELL}" "${ARTIX_VENDOR}-ucode"

# Create fstab
fstabgen -U /mnt >> /mnt/etc/fstab

# Copy scripts for the next installation step
cp /root/artix-install-config.sh /mnt/root
cp /root/artix-install-chroot.sh /mnt/root

# Save the LUKS passphrase temporarily for the chroot environment
# echo "ARTIX_LUKS_PASSPHRASE=${ARTIX_LUKS_PASSPHRASE@Q}
# ARTIX_USER_PASSWORD=${ARTIX_USER_PASSWORD@Q}
# ARTIX_ROOT_PASSWORD=${ARTIX_ROOT_PASSWORD@Q}" > /mnt/.artix-install-config.tmp

# Run the next stage inside the chroot environment (@Q escapes the string)
CHROOT_ENV="ARTIX_LUKS_PASSPHRASE=${ARTIX_LUKS_PASSPHRASE@Q};ARTIX_USER_PASSWORD=${ARTIX_USER_PASSWORD@Q};ARTIX_ROOT_PASSWORD=${ARTIX_ROOT_PASSWORD@Q}"
artix-chroot /mnt /bin/bash -c "source /root/artix-install-config.sh;${CHROOT_ENV};/root/artix-install-chroot.sh"

# artix-chroot /mnt /bin/bash

# Unmount all partitions
umount -a

# :^)
reboot
