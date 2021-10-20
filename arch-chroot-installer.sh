#! /bin/bash
EDITOR=nano visudo

pacman -Syy --noconfirm networkmanager dhclient glibc reflector flatpak git

## aur start
  cd /tmp
  git clone "https://aur.archlinux.org/yay.git"
  cd /tmp/yay
  makepkg -si --noconfirm
  rm -rf /tmp/yay
## aur end

## snap start
  yay -Syy --noconfirm snapd
  sudo systemctl enable --now snapd.socket
  sudo ln -s /var/lib/snapd/snap /snap
## snap end

## mirrorlist start
  iso=$(curl -4 ifconfig.co/country-iso)
  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
  reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
## mirrorlist end

## locale start
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

  localectl --no-ask-password set-locale LANG="${USER_LOCALE}" LC_COLLATE="" LC_TIME="${USER_LOCALE}"
## locale end

## keyb start
  loadkeys ${KEY_LAYOUT}
  localectl --no-ask-password set-keymap ${KEY_LAYOUT}
## keyb end

## datetime start
  timedatectl --no-ask-password set-timezone ${TZONE}
  timedatectl --no-ask-password set-ntp 1
## datetime end

## init systemd start
  cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak
  echo "
  MODULES=()
  BINARIES=()
  FILES=()
  HOOKS=(base systemd udev autodetect modconf block filesystems keyboard fsck)
  " > /etc/mkinitcpio.conf
  mkinitcpio -p linux
## init systemd end

## hostname start
  hostnamectl --no-ask-password set-hostname ${HOSTNAME}
## hostname end

## network start
  #cp /root/en.network /etc/systemd/network/en.network
  systemctl enable systemd-networkd
  systemctl enable systemd-resolved
  systemctl enable NetworkManager
## network end

## bootctl start
  if [ ! -z "${SYSTEM_DISK}" ]; then
    bootctl install
    mv /root/arch.conf /boot/loader/entries/arch.conf
    sed -e "s/\[ROOT_UUID\]/\"${UUID}\"/g" /boot/loader/entries/arch.conf
    bootctl update
  fi
## bootctl end

## root start
  passwd --lock root
  systemctl enable sshd
## root end

## user start
  if [ -n "${ENABLE_AUT0LOGIN}" = true ]; then
    groupadd -r autologin
    useradd -m -g users -G autologin,wheel,video -s /bin/bash ${USERNAME}
  else
    useradd -m -g users -G wheel,video -s /bin/bash ${USERNAME}
  fi

  echo "${USERNAME}:${USERPASSWORD}" | chpasswd

  cp /etc/sudoers /etc/sudoers.bak
  echo "
  root ALL=(ALL) ALL
  wheel ALL=(ALL) ALL
  ${USERNAME} ALL=(ALL) ALL

  #includedir /etc/sudoers.d
  " > /etc/sudoers
## user end
