#!/usr/bin/env bash

set -e

# Edit this:
DISK=/dev/vda1
NIX_SIZE="120G"
SWAP_SIZE="32G"
USER_NAME="user"  # also change it in configuration.nix

BOOT="${DISK}1"
ROOT="${DISK}2"
CRYPT_ROOT=dmcrypt0

# Create disk partitions
(
echo g  # (gpt disk label)
echo n
echo    # default (1 partition number [1/128])
echo    # default (2048 first sector)
echo +500M # last sector (boot sector size)
echo t
echo 1  # EFI System
echo n
echo 2
echo    # default (fill up partition)
echo    # default (fill up partition)
echo w  # write
) | fdisk $DISK

# Format boot partition
mkfs.fat -F 32 ${BOOT}

# Create LUKS partition
echo "Enter the password to unlock the root partition:"
cryptsetup --type luks2 --cipher aes-xts-plain64 --hash sha512 --iter-time 5000 --key-size 512 --pbkdf argon2id --use-urandom --verify-passphrase luksFormat ${ROOT}

# Unlock
cryptsetup open ${ROOT} ${CRYPT_ROOT}

# Create a physical volume on top of the LUKS one
pvcreate /dev/mapper/${CRYPT_ROOT}

# Create a volume group
vgcreate vg0 /dev/mapper/${CRYPT_ROOT}

# Create all logical volumes on the volume group
lvcreate -L ${SWAP_SIZE} -n swap vg0
lvcreate -L ${NIX_SIZE} -n root vg0
lvcreate -l 100%FREE -n home vg0

# Leave 256 MiB free space in the volume group to allow using e2scrub
lvreduce -L -256M vg0/home

# Format partitions
mkfs.ext4 /dev/vg0/root
mkswap /dev/vg0/swap

# Format home partition
mkfs.ext4 /dev/vg0/home

# Mount your root file system
mount -t tmpfs none /mnt

# Create directories
mkdir -p /mnt/{boot,nix,etc/nixos,var/log,home/${USER_NAME}}

# Mount /boot, /nix and /home/user
mount ${BOOT} /mnt/boot
mount /dev/vg0/root /mnt/nix
mount /dev/vg0/home /mnt/home/${USER_NAME}

# Create persistent directories
mkdir -p /mnt/nix/persist/{etc/nixos,var/log}

# Persistent bind mounts
mount -o bind /mnt/nix/persist/etc/nixos /mnt/etc/nixos
mount -o bind /mnt/nix/persist/var/log /mnt/var/log

# Create missing persistent dir
mkdir -p /mnt/nix/persist/etc/NetworkManager/system-connections

# Add disk labels
fatlabel ${BOOT} "BOOT"
cryptsetup config ${ROOT} --label "ROOT"
e2label /dev/vg0/root "NIXROOT"
e2label /dev/vg0/home "HOME"

# Set user password
echo "Enter the user password:"
mkpasswd > /mnt/nix/persist/user.pass
chmod 400 /mnt/nix/persist/user.pass

# Copy configuration
cp configuration.nix /mnt/etc/nixos/
cp hardware-configuration.nix /mnt/etc/nixos/

# Install NixOS
nixos-install --root /mnt
