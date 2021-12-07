#!/usr/bin/env bash

# TODO: Keep hashes of config files, scan before 

# TODO: AMD-specific steps (amd-ucode etc.)

function read_password() {
  stty -echo
  printf "${1}"
  read "${2}"
  stty echo
  printf "\n"
}

function run_guided_editor() {
    tmux \
        new-session  "nano $1 && tmux kill-window -t 0" \; \
        split-window -h "cat docs/_common.txt $2 | less" \; \
        select-pane -t 0
}

function run_guided_editor_dev() {
    tmux \
        new-session  "nano $1" \; \
        split-window -h "nano $2" \; \
        select-pane -t 0
}

alias guided_editor=run_guided_editor_dev

source ./artix-install-config.sh

read_password "Enter your desired LUKS passphrase: " ARTIX_LUKS_PASSPHRASE

# Don't run if virtual disk is not attached
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
    echo 2 # Partition 1
    echo   # Confirm default (end of last partition)
    echo   # Confirm default (rest of disk)
    echo Y # Confirm signature removal (ignored if not present)
    echo t # Change type
    echo 2
    echo 1 # EFI

    echo w # Write changes
) | fdisk "${ARTIX_DISK}"

# Format EFI partition
mkfs.fat -F32 "${ARTIX_DISK_EFI}"
fatlabel "${ARTIX_DISK_EFI}" PTEFI

# Format LVM partition
echo -n "${ARTIX_LUKS_PASSPHRASE}" | cryptsetup luksFormat --cipher aes-xts-plain64 --use-random "${ARTIX_DISK_LVM}" --batch-mode -
echo -n "${ARTIX_LUKS_PASSPHRASE}" | cryptsetup luksOpen "${ARTIX_DISK_LVM}" lvm -

# Create LVM volumes
pvcreate /dev/mapper/lvm
vgcreate vg0 /dev/mapper/lvm

# Calculate volume sizes
PV_CAPACITY_BYTES=$(pvdisplay /dev/mapper/lvm -s --units B | tr -d -c 0-9)
LV_ROOT_SIZE_BYTES=$(echo "$ARTIX_ROOT_SIZE_GB * 1024 * 1024 * 1024" | bc)
LV_SWAP_SIZE_BYTES=$(echo "$ARTIX_SWAP_SIZE_GB * 1024 * 1024 * 1024" | bc)
LV_HOME_SIZE_BYTES=$(echo "$PV_CAPACITY_BYTES - $LV_ROOT_SIZE_BYTES - $LV_SWAP_SIZE_BYTES" | bc);

# Create logical volumes
lvcreate --size "${LV_HOME_SIZE_BYTES}B" vg0 --name lv-home
lvcreate --size "${LV_ROOT_SIZE_BYTES}B" vg0 --name lv-root

# Create and format swap if size is not zero
if [ "${ARTIX_SWAP_SIZE_GB}" != "0" ]; then
    lvcreate --size "${LV_SWAP_SIZE_BYTES}B" vg0 --name lv-swap
    mkswap -L pt-swap /dev/vg0/lv-swap
    swapon /dev/mapper/vg0-swap
fi

# Format logical volumes
mkfs.ext4 -L pt-root /dev/vg0/lv-root
mkfs.ext4 -L pt-home /dev/vg0/lv-home

# Mount the new system
mount /dev/vg0/lv-root /mnt

mkdir /mnt/boot /mnt/boot/efi /mnt/home

# Mount EFI partition
mount "${ARTIX_DISK_EFI}" /mnt/boot/efi

# Update pacman repositories
pacman -Sy

# Bootstrap the base system
basestrap /mnt base base-devel openrc elogind-openrc \
    linux-zen linux-zen-headers linux-firmware \
    cryptsetup cryptsetup-openrc lvm2 lvm2-openrc grub os-prober efibootmgr \
    "${ARTIX_VENDOR}-ucode"

fstabgen -U /mnt >> /mnt/etc/fstab

cp /root/artix-install-config.sh /mnt/root
cp /root/artix-install-chroot.sh /mnt/root

# Run the next stage inside the chroot environment
artix-chroot /mnt /root/artix-install-chroot.sh
# artix-chroot /mnt /bin/bash
