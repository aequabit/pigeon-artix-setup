 #!/usr/bin/env bash

function guided_editor() {
  tmux \
    new-session  "nano $1 && tmux kill-window -t 0" \; \
    split-window -h "cat docs/_common.txt $2 | less" \; \
    select-pane -t 0
}

function guided_editor_dev() {
  tmux \
    new-session  "nano $1" \; \
    split-window -h "nano $2" \; \
    select-pane -t 0
}

alias guided_editor=guided_editor_dev

ARTIX_DISK=/dev/vda
ARTIX_DISK_EFI="$ARTIX_DISK"1
ARTIX_DISK_BOOT="$ARTIX_DISK"2
ARTIX_DISK_LVM="$ARTIX_DISK"3

# Don't run if virtual disk is not attached
if [ ! -e "$ARTIX_DISK" ]; then
    echo "$ARTIX_DISK doesn't exist, exiting"
    exit 1
fi

# Since we want to be as modular as possible,
# the most permanent partitions will be created first.
# This layout is preferable: 
# 
# lvm (/dev/xxx1)
#  -> lv-home
#  -> lv-root
# efi (/dev/xxx2)
# 


# (
#   echo g # Create GPT

#   echo n # Create EFI partition
#   echo 1 # Partition 1
#   echo # Confirm default (beginning of disk)
#   echo +300M
#   echo Y # Confirm signature removal (ignored if not present)
#   echo t # Change type
#   echo 1 # EFI

#   echo n # Create boot partition
#   echo 2 # Partition 2
#   echo # Confirm default (end of last partition)
#   echo +500M
#   echo Y # Confirm signature removal (ignored if not present)
#   echo t # Change type
#   echo 2
#   echo 20 # Linux filesystem

#   echo n # Create LVM partition
#   echo 3 # Partition 2
#   echo # Confirm default (end of last partition)
#   echo # Confirm default (rest of disk)
#   echo Y # Confirm signature removal (ignored if not present)
#   echo t # Change type
#   echo 3
#   echo 30 # Linux LVM
  
#   echo w # Write changes
# ) | fdisk $ARTIX_DISK

# echo $ARTIX_DISK
# echo $ARTIX_DISK_EFI
# echo $ARTIX_DISK_BOOT
# echo $ARTIX_DISK_LVM

# mkfs.fat -F32 $ARTIX_DISK_EFI
# fatlabel $ARTIX_DISK_BOOT pt-boot
# mkfs.ext4 -L pt-root /dev/...
# mkfs.ext4 -L pt-home /dev/...