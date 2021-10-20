#! /bin/bash

cat << EOF > /etc/modprobe.d/blacklist.conf
blacklist intel_rapl
blacklist i2c_piix4
EOF

# Virtualbox Guest setup 

pacman -S --noconfirm linux-headers virtualbox-guest-utils
modprobe -a vboxguest vboxsf vboxvideo

cat << EOF > /etc/modules-load.d/virtualbox.conf
vboxguest
vboxsf
vboxvideo
EOF

# Synchronize time with the host machine
systemctl enable vboxservice