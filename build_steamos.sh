#! /bin/bash

CHROOT_PATH=/mnt

sh build.sh

arch-chroot ${CHROOT_PATH} /bin/bash <<EOF

# install steam
flatpak install steam

EOF
