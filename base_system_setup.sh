#! /bin/bash

# This script works with a manifest
# password and ssh_pub_key will be prompted.

set -e
set -x

if [ $EUID -ne 0 ]; then
	echo "$(basename $0) must be run as root"
	exit 1
fi

source manifest

# script start

loadkeys be-latin1
timedatectl set-ntp true

# prep disk
mkfs.fat - /dev/root_partition
mkfs.ext4 /dev/root_partition

# prep chrooted mount
mount /dev/sda2/ /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
pacstrap /mnt base linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt

# config chrooted
timedatectl set-timezone ${TZONE}
hostnamectl set-hostname ${my_hostname}
pacman -S nano htop ssh rsync


# root passwd prompt
passwd --lock root

# create user
if [ -n "${ENABLE_AUT0LOGIN}" ]; then
  groupadd -r autologin
  useradd -m ${USERNAME} -G autologin,wheel
else
  useradd -m ${USERNAME} -G wheel
fi

echo "${USERNAME}:${USERNAME}" | chpasswd
echo "
root ALL=(ALL) ALL
${USERNAME} ALL=(ALL) ALL

#includedir /etc/sudoers.d
" > /etc/sudoers

# base
pacman -S nano htop openssh
systemctl enable openssh

hostname
localectl --no-convert set-x11-keymap be

cp /etc/locale.conf /etc/locale.conf.bak
cp /etc/locale.gen /etc/locale.gen.bak

echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen

locale -a # list
localectl set-locale LANG=${system_locale}

# network


mkinitcpio -P

systemctl enable ${SERVICES}
systemctl --global enable ${USER_SERVICES}

network
flatpak steam
network
pacman gnome
