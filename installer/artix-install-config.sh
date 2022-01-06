ARTIX_DISK="/dev/vda"
ARTIX_SWAP_SIZE_GB="0" # 
ARTIX_ROOT_SIZE_GB="15" # 55 for 512GB drive
ARTIX_KEYMAP="de-latin1"
ARTIX_TIMEZONE="Europe/Berlin"
ARTIX_VENDOR="intel" # intel, amd
ARTIX_GFX_VENDOR="none" # none, intel, nvidia, amd
ARTIX_LEGACY=0 # not implemented yet
ARTIX_LUKS_PASSPHRASE="1" # set to "prompt" for the installer to ask
ARTIX_BOOTLOADER_ID="pigeon-artix"
ARTIX_GRUB_COLOR_NORMAL="red/black"
ARTIX_GRUB_COLOR_HIGHLIGHT="light-gray/red"

ARTIX_INITCPIO_MODULES="ext4"
ARTIX_INITCPIO_MODULES_VFIO="vfio_pci vfio vfio_iommu_type1 vfio_virqfd"
ARTIX_INITCPIO_MODULES_NVIDIA="nvidia nvidia_modeset nvidia_uvm nvidia_drm"

ARTIX_HOSTNAME="pigeon-artix"
ARTIX_USER="pigeon"
ARTIX_USER_PASSWORD="1" # change after installation or set to "prompt" for the installer to ask
ARTIX_USER_GROUPS="wheel"
ARTIX_USER_HOME="/home/${ARTIX_USER}"
ARTIX_USER_SHELL="zsh"
ARTIX_ROOT_SHELL=$ARTIX_USER_SHELL
ARTIX_ROOT_PASSWORD="1" # change after installation or set to "prompt" for the installer to ask
ARTIX_WIRELESS=0

if [[ "${ARTIX_DISK}" == *"nvme"* ]];
then
    ARTIX_DISK_LVM="${ARTIX_DISK}p1"
    ARTIX_DISK_EFI="${ARTIX_DISK}p2"
else
    ARTIX_DISK_LVM="${ARTIX_DISK}1"
    ARTIX_DISK_EFI="${ARTIX_DISK}2"
fi
