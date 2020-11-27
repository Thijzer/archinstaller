#! /bin/bash

CHROOT_PATH=/mnt

sh build.sh

arch-chroot ${CHROOT_PATH} /bin/bash <<EOF

# install gnome
pacman -Sy gnome networkmanager
systemctl enable NetworkManager

EOF
