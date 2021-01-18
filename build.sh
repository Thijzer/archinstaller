#!/bin/bash

# This script works with a manifest
# password and ssh_pub_key will be prompted.

# SYSTEM_LOCALE, USER_LOCALE, SYSTEM_NAME, KEY_LAYOUT, TZONE, USERNAME, ENABLE_AUT0LOGIN, SYSTEM_DISK, SYSTEM_SIZE, EFI_PART, ROOT_PART

if [ $EUID -ne 0 ]; then
	echo "$(basename $0) must be run as root"
	exit 1
fi

#echo -n "User password: "
#read USERPASSWORD

#echo -n "User SSH key: (enter to skip)"
#read USERKEY

#blkid
#echo -n "Choose system disk: "
#read SYSTEM_DISK

source manifest

EFI_PART=1
ROOT_PART=2
CHROOT_PATH=/mnt
USERPASSWORD='random'
USERKEY=''
ROOT_UUID=$(blkid | tr -s ' ' | grep 'TYPE="ext4"' | cut -f2 -d'"')

set -e
set -x

# script start
pacman -Sy --noconfirm terminus-font
setfont ter-v32n
loadkeys ${KEY_LAYOUT}

# datetime
#timedatectl set-ntp true

# prep disk
if [ ! -z "${SYSTEM_DISK}" ]; then
  sgdisk --zap-all ${SYSTEM_DISK}
  sgdisk -n ${EFI_PART}:0:+200M -t ${EFI_PART}:ef00 -n ${ROOT_PART}:0:0 ${SYSTEM_DISK}

  mkfs.vfat -F 32 ${SYSTEM_DISK}${EFI_PART}
  mkfs.ext4 ${SYSTEM_DISK}${ROOT_PART}

  # disk mount
  mount ${SYSTEM_DISK}${ROOT_PART} ${CHROOT_PATH}
  mkdir ${CHROOT_PATH}/boot
  mount ${SYSTEM_DISK}${EFI_PART} ${CHROOT_PATH}/boot
  genfstab -U ${CHROOT_PATH} >> ${CHROOT_PATH}/etc/fstab
else
  BUILD_IMG=${SYSTEM_NAME}-build.img

  fallocate -l ${SYSTEM_SIZE} ${BUILD_IMG}
  mkfs.ext4 ${BUILD_IMG}
  mount ${BUILD_IMG} ${CHROOT_PATH}
  mkdir ${CHROOT_PATH}/etc
  echo "
LABEL=root /         ext4   defaults,discard   0 1
LABEL=efi  /boot      vfat  rw,noatime,nofail  0 0
" > ${CHROOT_PATH}/etc/fstab
fi
 
# pacman prep disk
pacstrap ${CHROOT_PATH} base linux linux-firmware

# copy over files
cp /workdir/boot/loader/entries/arch.conf ${CHROOT_PATH}/root/arch.conf

## chroot script
arch-chroot ${CHROOT_PATH} /bin/bash <<EOF
set -e
set -x

# essentials
# -Syy glibc for reinstalling language packs
# only required for docker container
pacman -Syy --noconfirm networkmanager vim nano htop openssh glibc

# locale
cp /etc/locale.gen /etc/locale.gen.bak
echo "LANG=${SYSTEM_LOCALE}
LANG=${USER_LOCALE}
LC_NUMERIC=${USER_LOCALE}
LC_TIME=${USER_LOCALE}
LC_MONETARY=${USER_LOCALE}
LC_PAPER=${USER_LOCALE}
LC_MEASUREMENT=${USER_LOCALE}
" > /etc/locale.conf
echo "${USER_LOCALE} UTF-8
${SYSTEM_LOCALE} UTF-8
" > /etc/locale.gen
locale-gen

# datetime
ln -sf /usr/share/zoneinfo/${TZONE} /etc/localtime

# init systemd # /etc/mkinitcpio.conf
cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak
echo "
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base systemd udev autodetect modconf block filesystems keyboard fsck)
" > /etc/mkinitcpio.conf
mkinitcpio -p linux

# root passwd prompt
passwd --lock root

# hostname
echo ${SYSTEM_NAME} > /etc/hostname
sed -i "/^hosts:/ s/resolve/mdns resolve/" /etc/nsswitch.conf

# keyb
loadkeys ${KEY_LAYOUT}

# boot
if [ ! -z "${SYSTEM_DISK}" ]; then
  bootctl install
  mv /root/arch.conf /boot/loader/entries/arch.conf
  sed -e "s/\[ROOT_UUID\]/\"${UUID}\"/g" /boot/loader/entries/arch.conf
  bootctl update
fi

# wired network
#cp /root/en.network /etc/systemd/network/en.network
systemctl enable systemd-networkd
systemctl enable systemd-resolved

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

# ssh
systemctl enable sshd
EOF

# cleanup
umount ${CHROOT_PATH}

if [ -z "${SYSTEM_DISK}" ]; then
  mkdir -p /workdir/output
  ARCHIVE=${BUILD_IMG}.gz
  gzip --keep --fast ${BUILD_IMG}
  mv ${ARCHIVE} /workdir/output/${ARCHIVE}
  sha256sum /workdir/output/${ARCHIVE} > /workdir/output/${ARCHIVE}-sha256sum.txt
fi