ARTIX_DISK="/dev/vda"
ARTIX_SWAP_SIZE_GB="0"
ARTIX_ROOT_SIZE_GB="15"
ARTIX_KEYMAP="de-latin1"
ARTIX_TIMEZONE="Europe/Berlin"
ARTIX_VENDOR="intel" # intel, amd
ARTIX_GFX_VENDOR="none" # none, intel, nvidia, amd
ARTIX_LEGACY=0 # not implemented yet
ARTIX_LUKS_PASSPHRASE="1" # set to "prompt" for the installer to ask
ARTIX_BOOTLOADER_ID="pigeon_artix"
ARTIX_GRUB_COLOR_NORMAL="red/black"
ARTIX_GRUB_COLOR_HIGHLIGHT="light-gray/red"

ARTIX_HOSTNAME="artix"
ARTIX_USER="felix"
ARTIX_USER_PASSWORD="1" # change after installation or set to "prompt" for the installer to ask
ARTIX_USER_GROUPS="wheel"
ARTIX_USER_SHELL="zsh"
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