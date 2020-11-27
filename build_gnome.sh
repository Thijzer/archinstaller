#! /bin/bash

CHROOT_PATH=/mnt

/bin/bash build.sh

arch-chroot ${CHROOT_PATH} /bin/bash <<EOF

# install gnome
pacman -Sy rsync gnome networkmanager
systemctl enable NetworkManager

# AUR


EOF
