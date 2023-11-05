#!/usr/bin/env bash

set -eu

if [[ $# -eq 0 ]]; then
  cat << EOF
Usage:

$0 <disk>
  <microcode:intel | amd>
  <DE:i3 | xfce | gnome | kde>
  <GPU:nvidia | amd | intel>
  <HostName>
  <UserName>
  <userPasword>
  <rootPassword>
  <partition-table-destroy:yes | exclude-efi | root-only | skip>
  <root_partition_size:Numbers only (GiB)>
EOF
  exit 1
fi

packagelist="base \
  base-devel \
  linux-zen \
  linux-zen-headers \
  linux-firmware \
  libva-vdpau-driver \
  vi \
  neovim \
  go \
  fd \
  sd \
  tldr \
  ripgrep \
  bat \
  sudo \
  zsh \
  curl \
  wget \
  fzf \
  git \
  openssh \
  htop \
  nmap \
  man-db \
  man-pages \
  xdg-user-dirs \
  wireplumber \
  pipewire \
  pipewire-pulse \
  noto-fonts \
  noto-fonts-cjk \
  noto-fonts-emoji \
  noto-fonts-extra \
  nerd-fonts \
  ttf-hack \
  fcitx5-im \
  fcitx5-mozc \
  docker \
  docker-compose \
  github-cli \
  discord \
  neofetch \
  reflector \
  xorg \
  xorg-apps \
  xorg-xinit \
  silicon \
  starship \
  lsd \
  eza \
  profile-sync-daemon \
  vivaldi \
  vivaldi-ffmpeg-codecs \
  pigz \
  lbzip2 \
  pv \
  lazygit \
  shfmt \
  shellcheck \
  unzip \
  virtualbox \
  virtualbox-host-dkms \
  virtualbox-guest-iso \
  stylua \
  nfs-utils"

NET_INTERFACE=$(ip -br link show | grep ' UP ' | awk '{print $1}')
readonly NET_INTERFACE

IP_ADDRESS=$(ip -o -4 a show "${NET_INTERFACE}" | awk -F '[ /]' '{print $7}')
readonly IP_ADDRESS

DISK="${1}"
readonly DISK

MICROCODE="${2}"
readonly MICROCODE

DE="${3}"
readonly DE

GPU="${4}"
readonly GPU

HOSTNAME="${5}"
readonly HOSTNAME

USERNAME="${6}"
readonly USERNAME

USER_PASSWORD="${7}"
readonly USER_PASSWORD

ROOT_PASSWORD="${8}"
readonly ROOT_PASSWORD

PARTITION_TABLE="${9}"
readonly PARTITION_TABLE

ROOT_SIZE="${10}"
readonly ROOT_SIZE

VCONSOLE=$(
  cat << EOF
KEYMAP=us
FONT=drdos8x16
EOF
)
readonly VCONSOLE

ENVIRONMENT=$(
  cat << EOF
GTK_IM_MODULE='fcitx5'
QT_IM_MODULE='fcitx5'
XMODIFIERS='@im=fcitx5'

LIBVA_DRIVER_NAME='nvidia'
VDPAU_DRIVER='nvidia'
EOF
)
readonly ENVIRONMENT

LOADER_CONF=$(
  cat << EOF
default      arch.conf
timeout      10
console-mode max
editor       no
EOF
)
readonly LOADER_CONF

HOSTS=$(
  cat << EOF
127.0.0.1       localhost
::1             localhost
${IP_ADDRESS}   ${HOSTNAME}.home    ${HOSTNAME}
EOF
)
readonly HOSTS

WIRED=$(
  cat << EOF
[Match]
Name=${NET_INTERFACE}

[Network]
DHCP=yes
DNS=192.168.1.202
EOF
)
readonly WIRED

check_variables() {
  if [[ "${MICROCODE}" != 'intel' ]] && [[ "${MICROCODE}" != 'amd' ]]; then
    echo 'microcode error'
    exit 1
  elif [[ "${DE}" != 'i3' ]] && [[ "${DE}" != 'xfce' ]] && [[ "${DE}" != 'gnome' ]] && [[ "${DE}" != 'kde' ]]; then
    echo 'de error'
    exit 1
  elif [[ "${GPU}" != 'nvidia' ]] && [[ "${GPU}" != 'amd' ]] && [[ "${GPU}" != 'intel' ]]; then
    echo 'gpu error'
    exit 1
  elif [[ "${PARTITION_TABLE}" != 'yes' ]] && [[ "${PARTITION_TABLE}" != 'exclude-efi' ]] && [[ "${PARTITION_TABLE}" != 'root-only' ]] && [[ "${PARTITION_TABLE}" != 'skip' ]]; then
    echo 'partition table error'
    exit 1
  fi
}

selection_arguments() {
  # intel-ucode or amd-ucode
  if [[ "${MICROCODE}" == 'intel' ]]; then
    packagelist="${packagelist} intel-ucode"
  elif [[ "${MICROCODE}" == 'amd' ]]; then
    packagelist="${packagelist} amd-ucode"
  fi

  # DE
  if [[ "${DE}" == 'i3' ]]; then
    packagelist="${packagelist} \
      i3-wm \
      i3lock \
      rofi \
      polybar \
      xautolock \
      polkit \
      scrot \
      lxappearance-gtk3 \
      feh \
      picom \
      dunst \
      gnome-keyring \
      qt5ct \
      kvantum \
      arc-gtk-theme \
      papirus-icon-theme \
      pavucontrol \
      alacritty \
      kitty \
      wezterm \
      tmux \
      ttf-font-awesome \
      ranger"
  elif [[ "${DE}" == 'xfce' ]]; then
    packagelist="${packagelist} \
      xfce4 \
      xfce4-goodies \
      gnome-keyring \
      gvfs \
      qt5ct \
      kvantum \
      blueman \
      papirus-icon-theme \
      arc-gtk-theme \
      lightdm \
      lightdm-gtk-greeter \
      lightdm-gtk-greeter-settings"
  elif [[ "${DE}" == 'gnome' ]]; then
    packagelist="${packagelist} \
      gnome-control-center \
      gnome-shell \
      gnome-tweaks \
      gnome-themes-extra \
      gnome-terminal \
      gnome-keyring \
      gnome-backgrounds \
      gnome-calculator \
      gedit \
      mutter \
      file-roller \
      nautilus \
      gdm \
      gvfs \
      dconf-editor \
      eog \
      networkmanager \
      gnome-shell-extension-appindicator"
  elif [[ "${DE}" == 'kde' ]]; then
    packagelist="${packagelist} \
      plasma-meta \
      packagekit-qt5 \
      dolphin \
      konsole \
      gwenview \
      spectacle \
      kate"
  fi

  if [[ "${GPU}" == 'nvidia' ]]; then
    packagelist="${packagelist} nvidia-dkms nvidia-settings"
  elif [[ "${GPU}" == 'amd' ]]; then
    packagelist="${packagelist} xf86-video-amdgpu libva-mesa-driver mesa-vdpau"
  fi
}

time_setting() {
  timedatectl set-ntp true
}

partitioning() {
  if [[ "${PARTITION_TABLE}" == 'yes' ]]; then
    sgdisk -Z "${DISK}"
    sgdisk -n 0::+512M -t 0:ef00 -c '0:EFI system partition' "${DISK}"
    sgdisk -n "0::+${ROOT_SIZE}G" -t 0:8300 -c '0:Linux filesystem' "${DISK}"
    sgdisk -n 0:: -t 0:8300 -c '0:Linux filesystem' "${DISK}"

    # format
    mkfs.fat -F 32 "${DISK}1"
    mkfs.ext4 "${DISK}2"
    mkfs.ext4 "${DISK}3"
  elif [[ "${PARTITION_TABLE}" == 'exclude-efi' ]]; then
    sgdisk -d 3 "${DISK}"
    sgdisk -d 2 "${DISK}"
    sgdisk -n "0::+${ROOT_SIZE}G" -t 0:8300 -c '0:EFI system partition' "${DISK}"
    sgdisk -n 0:: -t 0:8300 -c '0:Linux filesystem' "${DISK}"

    # format
    mkfs.ext4 "${DISK}2"
    mkfs.ext4 "${DISK}3"
  elif [[ "${PARTITION_TABLE}" == 'root-only' ]]; then
    # format
    mkfs.ext4 "${DISK}2"
  elif [[ "${PARTITION_TABLE}" == 'skip' ]]; then
    echo 'Skip partitioning'

    # format
    mkfs.ext4 "${DISK}2"
    mkfs.ext4 "${DISK}3"
  fi

  # mount
  mount "${DISK}2" /mnt
  mount -m -o fmask=0077,dmask=0077 "${DISK}1" /mnt/boot
  mount -m "${DISK}3" /mnt/home
}

installation() {
  reflector --country Japan --age 24 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
  pacstrap -K /mnt ${packagelist}
  genfstab -t PARTUUID /mnt >> /mnt/etc/fstab
}

configuration() {
  arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
  arch-chroot /mnt hwclock --systohc --utc
  arch-chroot /mnt sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
  arch-chroot /mnt sed -i 's/#ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/' /etc/locale.gen
  arch-chroot /mnt sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
  arch-chroot /mnt locale-gen
  echo 'LANG=en_US.UTF-8' > /mnt/etc/locale.conf
  echo "${VCONSOLE}" >> /mnt/etc/vconsole.conf
  echo "${HOSTNAME}" > /mnt/etc/hostname
  arch-chroot /mnt sh -c "echo '%wheel ALL=(ALL:ALL) ALL' | EDITOR='tee -a' visudo"
}

networking() {
  echo "${HOSTS}" >> /mnt/etc/hosts

  if [[ "${DE}" == 'i3' ]] || [[ "${DE}" == 'xfce' ]]; then
    ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
    echo "${WIRED}" > /mnt/etc/systemd/network/20-wired.network
  else
    ln -sf /run/NetworkManager/no-stub-resolv.conf /mnt/etc/resolv.conf
  fi
}

create_user() {
  echo "root:${ROOT_PASSWORD}" | arch-chroot /mnt chpasswd
  arch-chroot /mnt useradd -m -G wheel -s /bin/bash "${USERNAME}"
  echo "${USERNAME}:${USER_PASSWORD}" | arch-chroot /mnt chpasswd
}

add_to_group() {
  arch-chroot /mnt gpasswd -a "${USERNAME}" docker
  arch-chroot /mnt gpasswd -a "${USERNAME}" vboxusers
}

replacement() {
  arch-chroot /mnt sed -i 's/^#NTP=/NTP=ntp.nict.jp/' /etc/systemd/timesyncd.conf
  arch-chroot /mnt sed -i 's/^#FallbackNTP=/FallbackNTP=ntp1.jst.mfeed.ad.jp ntp2.jst.mfeed.ad.jp ntp3.jst.mfeed.ad.jp/' /etc/systemd/timesyncd.conf
  arch-chroot /mnt sed -i 's/^#DefaultTimeoutStopSec=90s/DefaultTimeoutStopSec=10s/' /etc/systemd/system.conf
  arch-chroot /mnt sed -i 's/^#HandlePowerKey=poweroff/HandlePowerKey=ignore/' /etc/systemd/logind.conf
  arch-chroot /mnt sed -i 's/-march=x86-64 -mtune=generic/-march=native/' /etc/makepkg.conf
  arch-chroot /mnt sed -i 's/^#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(($(nproc)+1))"/' /etc/makepkg.conf
  arch-chroot /mnt sed -i 's/^#BUILDDIR/BUILDDIR/' /etc/makepkg.conf
  arch-chroot /mnt sed -i 's/^COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z --threads=0 -)/' /etc/makepkg.conf
  arch-chroot /mnt sed -i 's/^COMPRESSZST=(zstd -c -z -q -)/COMPRESSZST=(zstd -c -z -q --threads=0 -)/' /etc/makepkg.conf
  arch-chroot /mnt sed -i 's/^COMPRESSGZ=(gzip -c -f -n)/COMPRESSGZ=(pigz -c -f -n)/' /etc/makepkg.conf
  arch-chroot /mnt sed -i 's/^COMPRESSBZ2=(bzip2 -c -f)/COMPRESSBZ2=(lbzip2 -c -f)/' /etc/makepkg.conf
  arch-chroot /mnt sed -i 's/^#Color/Color/' /etc/pacman.conf
  arch-chroot /mnt sed -i 's/^# --country France,Germany/--country Japan/' /etc/xdg/reflector/reflector.conf
  arch-chroot /mnt sed -i 's/^--latest 5/# --latest 5/' /etc/xdg/reflector/reflector.conf
  arch-chroot /mnt sed -i 's/^--sort age/--sort rate/' /etc/xdg/reflector/reflector.conf
  echo -e '\n--age 24' /mnt/etc/xdg/reflector/reflector.conf
  echo "${ENVIRONMENT}" >> /mnt/etc/environment
  arch-chroot /mnt pacman -Syy
}

boot_loader() {
  arch-chroot /mnt bootctl install

  root_partuuid=$(blkid -s PARTUUID -o value "${DISK}2")
  vmlinuz=$(find /boot/*vmlinuz* | awk -F '/' '{print $3}')
  ucode=$(find /boot/*ucode* | awk -F '/' '{print $3}')
  initramfs=$(find /boot/*initramfs* | tail -n 1 | awk -F '/' '{print $3}')
  initramfs_fallback=$(find /boot/*initramfs* | head -n 1)

  nvidia_conf=$(
    cat << EOF
title    Arch Linux
linux    /${vmlinuz}
initrd   /${ucode}
initrd   /${initramfs}
options  root=PARTUUID=${root_partuuid} rw loglevel=3 panic=180 i915.modeset=0 nouveau.modeset=0 nvidia_drm.modeset=1
EOF
  )
  nvidia_fallback_conf=$(
    cat << EOF
title    Arch Linux (Fallback)
linux    /${vmlinuz}
initrd   /${ucode}
initrd   /${initramfs_fallback}
options  root=PARTUUID=${root_partuuid} rw debug panic=180 i915.modeset=0 nouveau.modeset=0 nvidia_drm.modeset=1
EOF
  )
  amd_conf=$(
    cat << EOF
title    Arch Linux
linux    /${vmlinuz}
initrd   /${ucode}
initrd   /${initramfs}
options  root=PARTUUID=${root_partuuid} rw loglevel=3 panic=180
EOF
  )
  amd_fallback_conf=$(
    cat << EOF
title    Arch Linux (Fallback)
linux    /${vmlinuz}
initrd   /${ucode}
initrd   /${initramfs_fallback}
options  root=PARTUUID=${root_partuuid} rw debug panic=180 i915.modeset=0
EOF
  )
  INTEL_CONF=$(
    cat << EOF
title    Arch Linux
linux    /${vmlinuz}
initrd   /${ucode}
initrd   /${initramfs}
options  root=PARTUUID=${root_partuuid} rw loglevel=3 panic=180
EOF
  )
  local -r INTEL_CONF
  INTEL_FALLBACK_CONF=$(
    cat << EOF
title    Arch Linux (Fallback)
linux    /${vmlinuz}
initrd   /${ucode}
initrd   /${initramfs_fallback}
options  root=PARTUUID=${root_partuuid} rw debug panic=180
EOF
  )
  local -r INTEL_FALLBACK_CONF

  echo "${LOADER_CONF}" > /mnt/boot/loader/loader.conf
  if [[ "${GPU}" == 'nvidia' ]]; then
    echo "${nvidia_conf}" > /mnt/boot/loader/entries/arch.conf
    echo "${nvidia_fallback_conf}" > /mnt/boot/loader/entries/arch_fallback.conf
  elif [[ "${GPU}" == 'amd' ]]; then
    echo "${amd_conf}" > /mnt/boot/loader/entries/arch.conf
    echo "${amd_fallback_conf}" > /mnt/boot/loader/entries/arch_fallback.conf
  elif [[ "${GPU}" == 'intel' ]]; then
    echo "${INTEL_CONF}" > /mnt/boot/loader/entries/arch.conf
    echo "${INTEL_FALLBACK_CONF}" > /mnt/boot/loader/entries/arch_fallback.conf
  fi
}

enable_services() {
  arch-chroot /mnt systemctl enable iptables.service
  arch-chroot /mnt systemctl enable docker.service
  arch-chroot /mnt systemctl enable fstrim.timer
  arch-chroot /mnt systemctl enable reflector.timer
  arch-chroot /mnt systemctl enable systemd-boot-update.service
  if [[ "${DE}" == 'i3' ]] || [[ "${DE}" == 'xfce' ]]; then
    arch-chroot /mnt systemctl enable systemd-networkd.service
    arch-chroot /mnt systemctl enable systemd-resolved.service
  fi
  if [[ "${DE}" == 'xfce' ]]; then
    arch-chroot /mnt systemctl enable lightdm.service
  elif [[ "${DE}" == 'gnome' ]]; then
    arch-chroot /mnt systemctl enable gdm.service
    arch-chroot /mnt systemctl enable NetworkManager.service
  elif [[ "${DE}" == 'kde' ]]; then
    arch-chroot /mnt systemctl enable sddm.service
    arch-chroot /mnt systemctl enable NetworkManager.service
  fi
}

main() {
  check_variables
  selection_arguments
  time_setting
  partitioning
  installation
  configuration
  networking
  create_user
  add_to_group
  replacement
  boot_loader
  enable_services
}

main "$@"
