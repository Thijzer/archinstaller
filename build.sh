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

## copy over files
cp /workdir/skel/boot/loader/entries/arch.conf ${CHROOT_PATH}/root/arch.conf
cp /workdir/skel/root/en.network ${CHROOT_PATH}/root/en.network 

## chroot script
arch-chroot ${CHROOT_PATH} /bin/bash <<EOF
set -ex

## essentials
# -Syy glibc for reinstalling language packs, only required for docker container
pacman -Syy --noconfirm vim nano htop rsync curl openssh

source <(curl -sL https://raw.githubusercontent.com/Thijzer/archinstaller/main/arch-choot-installer.sh)
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
