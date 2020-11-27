#! /bin/bash

# This script works with a manifest
# password and ssh_pub_key will be prompted.

# SYSTEM_LOCALE, USER_LOCALE, MY_MOSTNAME, KEY_LAYOUT, TZONE, USERNAME, ENABLE_AUT0LOGIN, SYSTEM_DISK, EFI_PART, ROOT_PART

set -e
set -x

if [ $EUID -ne 0 ]; then
	echo "$(basename $0) must be run as root"
	exit 1
fi

echo -n "User password: "
read USERPASSWORD

echo -n "User SSH key: (enter to skip)"
read USERKEY

source manifest

EFI_PART=1
ROOT_PART=2
CHROOT_PATH=/mnt

# script start
pacman -S terminus-font
setfont ter-v32n
loadkeys ${KEY_LAYOUT}
timedatectl set-ntp true

# prep disk
sgdisk --zap-all ${SYSTEM_DISK}
sgdisk -n ${EFI_PART}:0:+200M -t ${EFI_PART}:ef00 -n ${ROOT_PART}:0:0 ${SYSTEM_DISK}

mkfs.vfat -F 32 ${SYSTEM_DISK}${EFI_PART}
mkfs.ext4 ${SYSTEM_DISK}${ROOT_PART}

# disk mount
mount ${SYSTEM_DISK}${ROOT_PART} ${CHROOT_PATH}
mkdir ${CHROOT_PATH}/boot
mount ${SYSTEM_DISK}${EFI_PART} ${CHROOT_PATH}/boot
genfstab -U ${CHROOT_PATH} >> /mnt/etc/fstab

# pacman prep disk
pacstrap ${CHROOT_PATH} base linux linux-firmware nano htop openssh rsync

# copy over files
cp arch.conf ${CHROOT_PATH}/root/arch.conf

## chroot script
arch-chroot ${CHROOT_PATH} /bin/bash <<EOF

# init # HOOKS=(base systemd autodetect modconf block filesystems keyboard fsck)
#/etc/mkinitcpio.conf
mkinitcpio -p linux

# ssh
systemctl enable openssh

# root passwd prompt
passwd --lock root

# hostname
hostnamectl set-hostname ${MY_HOSTNAME}
sed -i "/^hosts:/ s/resolve/mdns resolve/" /etc/nsswitch.conf

# locale
cp /etc/locale.conf /etc/locale.conf.bak
cp /etc/locale.gen /etc/locale.gen.bak
localectl --no-convert set-x11-keymap be
localectl set-locale LANG=${system_locale}
echo "${USER_LOCALE} UTF-8 \n ${SYSTEM_LOCALE} UTF-8" > /etc/locale.gen
locale-gen

# datetime
timedatectl set-timezone ${TZONE}
loadkeys ${KEY_LAYOUT}
timedatectl set-ntp true

# boot
bootctl install
cp /root/arch.conf /boot/loader/entries/arch.conf
UUID=$(blkid | tr -s ' ' | grep 'TYPE="ext4"' | cut -f2 -d'"')
sed -e "s/\[UUID\]/\"${UUID}\"/g" /boot/loader/entries/arch.conf
bootctl update

# wired network
#cp /root/en.network /etc/systemd/network/en.network
systemctl enable systemd-networkd
systemctl enable systemd-resolvd

# create user
if [ -n "${ENABLE_AUT0LOGIN}" = true ]; then
  groupadd -r autologin
  useradd -m ${USERNAME} -G autologin,wheel
else
  useradd -m ${USERNAME} -G wheel
fi

echo "${USERNAME}:${USERPASSWORD}" | chpasswd

echo "
root ALL=(ALL) ALL
wheel ALL=(ALL) ALL
${USERNAME} ALL=(ALL) ALL

#includedir /etc/sudoers.d
" > /etc/sudoers
EOF
