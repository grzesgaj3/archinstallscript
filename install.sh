#!/bin/bash

# Partition the disk
parted -s /dev/sda \
    mklabel gpt \
    mkpart primary fat32 1MiB 261MiB \
    set 1 esp on \
    mkpart primary linux-swap 261MiB 8GiB \
    mkpart primary btrfs 8GiB 100% \
    name 1 boot \
    name 2 swap \
    name 3 root

# Format the partitions
mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2
swapon /dev/sda2
cryptsetup luksFormat /dev/sda3
cryptsetup open --type luks /dev/sda3 cryptroot
mkfs.btrfs /dev/mapper/cryptroot
mount -t btrfs -o noatime,compress=lzo,space_cache,subvol=/ /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@
umount /mnt

# Mount the partitions
cryptsetup open --type luks /dev/sda3 crypthome
mkfs.btrfs /dev/mapper/crypthome
mount -t btrfs -o noatime,compress=lzo,space_cache,subvol=/ /dev/mapper/crypthome /mnt
btrfs subvolume create /mnt/@home
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

# Install the base system and necessary packages
pacstrap /mnt base base-devel btrfs-progs i3-gaps rofi grub efibootmgr dosfstools openssh dialog wpa_supplicant

# Generate the fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt

# Set the timezone
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc

# Set the locale
sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

# Set the hostname
echo "archlinux" > /etc/hostname

# Configure the network
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 archlinux.localdomain archlinux" >> /etc/hosts
systemctl enable dhcpcd.service

# Set the root password
passwd

# Install and configure GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Install and configure yay
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ..
rm -rf yay

# Install Xorg and additional packages
pacman -S xorg xorg-xinit xorg-xrandr mesa xf86-video-intel alsa-utils pulseaudio pulseaudio-alsa

# Configure i3
echo "exec i3" > ~/.xinitrc

# Configure Rofi
mkdir ~/.config
mkdir ~/.config/rofi
cat > ~/.config/rofi/config.rasi <<EOF
configuration {
  font: "DejaVu Sans Mono 10";
  terminal: "alacritty";
  window-thumbnail: false;
  sidebar-mode:
