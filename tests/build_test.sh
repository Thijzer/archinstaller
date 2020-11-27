#!/bin/bash

if [ $EUID -ne 0 ]; then
	echo "$(basename $0) must be run as root"
	exit 1
fi

source manifest

CHROOT_PATH=/mnt

BUILD_IMG=${SYSTEM_NAME}-build.img

fallocate -l ${SYSTEM_SIZE} ${BUILD_IMG}
mkfs.ext4 ${BUILD_IMG}
mount ${BUILD_IMG} ${CHROOT_PATH}

pacman --noconfirm -Syy
pacman --noconfirm -Syu
pacman --noconfirm -S arch-install-scripts

pacstrap ${CHROOT_PATH} base

arch-chroot ${CHROOT_PATH} /bin/bash <<EOF
set -e
set -x

### 
EOF