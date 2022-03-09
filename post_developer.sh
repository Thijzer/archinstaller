#! /bin/bash

PKGS=(
'python-pip'
'zip'
'zsh'
'zsh-syntax-highlighting'
'zsh-autosuggestions'
)

for PKG in "${PKGS[@]}"; do
    echo "INSTALLING: ${PKG}"
    sudo pacman -S "$PKG" --noconfirm --needed
done

snap install code phpstorm --classic
flatpak install typora
flatpak install flathub com.github.alainm23.planner
