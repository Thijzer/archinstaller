#! /bin/bash
source manifest

CHROOT_PATH=/mnt

/bin/bash build.sh

BUILD_IMG=${SYSTEM_NAME}-build.img
mount ${BUILD_IMG} ${CHROOT_PATH}

arch-chroot ${CHROOT_PATH} /bin/bash <<EOF
set -e
set -x
# install gnome
pacman -Sy --noconfirm rsync gnome networkmanager
systemctl enable NetworkManager
EOF

# cleanup
umount ${CHROOT_PATH}

if [ -z "${SYSTEM_DISK}" ]; then
  mkdir -p /workdir/output
  ARCHIVE=${BUILD_IMG}.gnome.gz
  gzip --keep --fast ${BUILD_IMG}
  mv ${ARCHIVE} /workdir/output/${ARCHIVE}
  sha256sum /workdir/output/${ARCHIVE} > /workdir/output/${ARCHIVE}-sha256sum.txt
fi