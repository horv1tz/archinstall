#!/bin/bash

echo -e "\e[32mОбновление системных часов\e[0m"
timedatectl set-ntp true

echo -e "\e[32mФорматирование разделов\e[0m"
mkfs.fat -F32 /dev/sda1 # EFI раздел
mkfs.btrfs /dev/sda2 # корневой раздел

echo -e "\e[32mМонтирование корневого раздела для создания субволюмов\e[0m"
mount /dev/sda2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

echo -e "\e[32mМонтирование субволюмов\e[0m"
mount -o noatime,compress=zstd,space_cache=v2,subvol=@ /dev/sda2 /mnt
mkdir /mnt/{boot,home}
mount -o noatime,compress=zstd,space_cache=v2,subvol=@home /dev/sda2 /mnt/home
mount /dev/sda1 /mnt/boot

echo -e "\e[32mУстановка основных пакетов\e[0m"
pacstrap /mnt base linux linux-firmware btrfs-progs networkmanager

echo -e "\e[32mГенерация fstab\e[0m"
genfstab -U /mnt >> /mnt/etc/fstab

echo -e "\e[32mНастройка системы в chroot\e[0m"
cat <<EOF > /mnt/setup_chroot.sh
#!/bin/bash

echo -e "\e[32mНастройка часового пояса\e[0m"
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

echo -e "\e[32mНастройка vconsole\e[0m"
echo "KEYMAP=ru" > /etc/vconsole.conf
echo "FONT=cyr-sun16" >> /etc/vconsole.conf

echo -e "\e[32mЛокализация\e[0m"
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf

echo -e "\e[32mНастройка сети\e[0m"
echo "horvitz-pc" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 horvitz-pc.localdomain horvitz-pc" >> /etc/hosts

echo -e "\e[32mУстановка и настройка NetworkManager\e[0m"
systemctl enable NetworkManager

echo -e "\e[32mУстановка загрузчика\e[0m"
pacman -S grub efibootmgr --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

EOF

chmod +x /mnt/setup_chroot.sh

echo -e "\e[32mПереход в chroot и выполнение настройки\e[0m"
arch-chroot /mnt ./setup_chroot.sh
