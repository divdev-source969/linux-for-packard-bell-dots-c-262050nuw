#!/bin/bash
# ============================================================
#  DOT-OS WSL One-Shot Builder — Packard Bell Dot 262050NUW
#  v4 — liquid-glass dock desktop + DOT Store + Calamares installer
#  Paste this WHOLE thing into the Ubuntu (WSL) terminal.
# ============================================================
set -e
export DEBIAN_FRONTEND=noninteractive

sudo apt update && sudo apt install -y live-build debootstrap xorriso isolinux

cd ~
rm -rf dot-os-build
lb config \
    --distribution bookworm \
    --architectures i386 \
    --binary-images iso-hybrid \
    --debian-installer live \
    --archive-areas "main contrib non-free non-free-firmware" \
    --bootappend-live "boot=live components quiet splash"

cat > config/package-lists/desktop.list.chroot <<'PKGS'
linux-image-686
live-boot
systemd-sysv
xorg
xserver-xorg-video-intel
xserver-xorg-input-synaptics
icewm
lightdm
network-manager
network-manager-gnome
firmware-atheros
firmware-brcm80211
firmware-realtek
firmware-iwlwifi
firmware-misc-nonfree
wireless-tools
wpasupplicant
alsa-utils
pulseaudio
pavucontrol
ntfs-3g
firefox-esr
mousepad
pcmanfm
lxterminal
htop
gparted
synaptic
fonts-dejavu
# --- liquid-glass desktop (Sway) ---
sway
swaybg
waybar
wofi
foot
fonts-font-awesome
fonts-noto-color-emoji
xdg-user-dirs
swayidle
# --- 2GB RAM safety net ---
earlyoom
# --- installer ---
calamares
calamares-settings-debian
PKGS

mkdir -p config/hooks/normal

# --- hook: Dot model base setup ---
cat > config/hooks/normal/050-dot-model-setup.hook.chroot <<'HOOK'
#!/bin/sh
apt-get install -y zram-tools
printf 'ALGO=lz4\nPERCENT=50\nPRIORITY=100\n' >> /etc/default/zramswap
mkdir -p /etc/X11/xorg.conf.d
printf 'Section "Device"\n    Identifier  "Intel GMA 3150"\n    Driver      "intel"\n    Option      "AccelMethod"  "uxa"\n    Option      "TearFree"     "true"\nEndSection\n' > /etc/X11/xorg.conf.d/20-intel-dot.conf
systemctl mask bluetooth cups-browsed 2>/dev/null || true
HOOK
chmod +x config/hooks/normal/050-dot-model-setup.hook.chroot

# --- hook: liquid-glass look + DOT Store ---
cat > config/hooks/normal/060-liquid-glass.hook.chroot <<'HOOK'
#!/bin/sh
mkdir -p /etc/skel/.config/sway /etc/skel/.config/waybar /etc/skel/.config/wofi /etc/skel/.config/foot

# ===== SWAY: Hyprland binds + glass aesthetics =====
cat > /etc/skel/.config/sway/config <<'SWAY'
set $mod Mod4
set $term foot
set $menu wofi --show drun
set $store dot-store

exec waybar
exec swaybg -c "#11111b"

default_border pixel 2
default_floating_border pixel 2
gaps inner 10
gaps outer 6
font pango:DejaVu Sans 10

client.focused          #89b4fa     #1e1e2e     #cdd6f4     #f5e0dc     #89b4fa
client.unfocused        #45475a     #1e1e2e     #bac2de     #45475a     #45475a
client.urgent           #f38ba8     #1e1e2e     #11111b     #f38ba8     #f38ba8

bindsym $mod+Return exec $term
bindsym $mod+Q kill
bindsym $mod+D exec $menu
bindsym $mod+S exec $store
bindsym $mod+M exec swaymsg exit
bindsym $mod+F fullscreen toggle
bindsym $mod+V floating toggle
bindsym $mod+Left focus left
bindsym $mod+Right focus right
bindsym $mod+Up focus up
bindsym $mod+Down focus down
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Right move right
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Down move down
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5

input * {
    xkb_layout us
    tap enabled
    natural_scroll enabled
}

include /etc/sway/config.d/*
SWAY

# ===== WAYBAR as a centered liquid-glass dock =====
cat > /etc/skel/.config/waybar/config <<'BAR'
{
  "layer": "top",
  "position": "bottom",
  "height": 46,
  "width": 620,
  "margin-bottom": 12,
  "modules-left": ["custom/launcher"],
  "modules-center": ["wlr/taskbar"],
  "modules-right": ["network", "pulseaudio", "battery", "clock"],
  "custom/launcher": { "format": " <span size='large'>\uf313</span> ", "tooltip": false, "on-click": "wofi --show drun" },
  "wlr/taskbar": { "format": "{icon}", "icon-size": 28, "tooltip": false, "on-click": "activate", "on-click-middle": "close" },
  "network": { "format-wifi": "\uf1eb  {essid}", "format-ethernet": "\uf796  {ipaddr}", "format-disconnected": "\uf071  off", "tooltip": false },
  "pulseaudio": { "format": "{icon}  {volume}%", "format-muted": "\uf6a9", "format-icons": ["\uf026","\uf027","\uf028"], "tooltip": false, "on-click": "pavucontrol" },
  "battery": { "format": "{icon}  {capacity}%", "format-icons": ["\uf244","\uf243","\uf242","\uf241","\uf240"], "states": { "warning": 25, "critical": 12 }, "tooltip": false },
  "clock": { "format": "\uf017  {:%H:%M}", "tooltip-format": "{:%A %d %B %Y}", "on-click": "dot-store" }
}
BAR

cat > /etc/skel/.config/waybar/style.css <<'CSS'
* { font-family: "DejaVu Sans", "Font Awesome 6 Free"; font-size: 13px; min-height: 0; }
window#waybar {
  background: rgba(30, 30, 46, 0.55);
  color: #cdd6f4;
  border-radius: 22px;
  border: 1.5px solid rgba(137, 180, 250, 0.45);
  box-shadow: 0 0 18px rgba(137, 180, 250, 0.25);
  margin-bottom: 12px;
}
#custom-launcher { color: #89b4fa; padding: 0 10px; font-size: 18px; }
#taskbar button.active, #wlr-taskbar button.active {
  background: rgba(137, 180, 250, 0.30);
  border-radius: 14px;
}
#taskbar button, #wlr-taskbar button { padding: 0 8px; border-radius: 14px; }
#network, #pulseaudio, #battery, #clock { padding: 0 9px; }
#battery.warning { color: #f9e2af; }
#battery.critical { color: #f38ba8; }
CSS

# ===== WOFI: glass launcher =====
cat > /etc/skel/.config/wofi/style.css <<'CSS'
window {
  background: rgba(30, 30, 46, 0.75);
  color: #cdd6f4;
  border: 1.5px solid rgba(137, 180, 250, 0.45);
  border-radius: 16px;
}
#input { background: rgba(49, 50, 68, 0.85); color: #cdd6f4; border-radius: 10px; margin: 10px; }
#entry:selected { background: rgba(137, 180, 250, 0.85); color: #1e1e2e; }
CSS

# ===== FOOT: glassy translucent terminal =====
cat > /etc/skel/.config/foot/foot.ini <<'FOOT'
[main]
font=DejaVu Sans Mono:size=11
pad=12x12
[colors]
alpha=0.85
background=1e1e2e
text=cdd6f4
FOOT

# ===== DOT STORE: lightweight app store =====
cat > /usr/local/bin/dot-store <<'STORE'
#!/bin/bash
ITEMS="
Internet | Firefox (installed) | echo already-installed
Internet | Chromium browser | sudo apt-get install -y chromium
Internet | Thunderbird mail | sudo apt-get install -y thunderbird
Internet | Transmission torrent | sudo apt-get install -y transmission-gtk
Internet | FileZilla FTP | sudo apt-get install -y filezilla
Media | VLC media player | sudo apt-get install -y vlc
Media | Audacity audio editor | sudo apt-get install -y audacity
Media | OBS Studio | sudo apt-get install -y obs-studio
Media | GIMP image editor | sudo apt-get install -y gimp
Media | Inkscape vector art | sudo apt-get install -y inkscape
Media | Spotify (web wrapper) | sudo apt-get install -y nuvolaplayer3
Office | LibreOffice suite | sudo apt-get install -y libreoffice
Office | Okular PDF reader | sudo apt-get install -y okular
Office | Xournal++ notes | sudo apt-get install -y xournalpp
Dev | VS Code (OSS: VSCodium) | sudo apt-get install -y codium
Dev | Geany IDE | sudo apt-get install -y geany
Dev | Python 3 + pip | sudo apt-get install -y python3-pip
Dev | Git | sudo apt-get install -y git
Dev | Neovim | sudo apt-get install -y neovim
Games | SuperTux | sudo apt-get install -y supertux
Games | SuperTuxKart | sudo apt-get install -y supertuxkart
Games | RetroArch emulator | sudo apt-get install -y retroarch
Games | Minecraft (install script) | echo install prism-launcher from flathub - see README
Tools | htop | sudo apt-get install -y htop
Tools | GParted | sudo apt-get install -y gparted
Tools | Neofetch | sudo apt-get install -y neofetch
Tools | Timeshift backup | sudo apt-get install -y timeshift
System | Update everything | sudo apt-get update && sudo apt-get upgrade -y
System | Open Synaptic (FULL store) | synaptic
"
CHOICE=$(echo "$ITEMS" | grep -v '^$' | wofi --dmenu --prompt "DOT Store  (Super+S)" --width 520 --height 500 2>/dev/null)
[ -z "$CHOICE" ] && exit 0
echo "$CHOICE" | awk -F'|' '{print $3}' | bash
STORE
chmod +x /usr/local/bin/dot-store

# make sway the default session
mkdir -p /etc/lightdm/lightdm.conf.d
printf '[Seat:*]\nuser-session=sway\n' > /etc/lightdm/lightdm.conf.d/50-dot-default.conf
HOOK
chmod +x config/hooks/normal/060-liquid-glass.hook.chroot

# --- hook: 2GB RAM + HDD smoothing ---
cat > config/hooks/normal/070-smooth-2gb.hook.chroot <<'HOOK'
#!/bin/sh
systemctl enable earlyoom
printf 'vm.swappiness=100\nvm.vfs_cache_pressure=50\n' >> /etc/sysctl.d/99-dot.conf
mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nSystemMaxUse=64M\nRuntimeMaxUse=32M\n' > /etc/systemd/journald.conf.d/99-dot.conf
systemctl mask apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
HOOK
chmod +x config/hooks/normal/070-smooth-2gb.hook.chroot

# --- installer command + app launcher ---
mkdir -p config/includes.chroot/usr/local/bin config/includes.chroot/usr/share/applications
cat > config/includes.chroot/usr/local/bin/installDotos <<'INSTALL'
#!/bin/bash
set -e
if ! command -v calamares >/dev/null 2>&1; then
    echo "Calamares is not installed in this live system."
    echo "Install it with: sudo apt-get update && sudo apt-get install -y calamares calamares-settings-debian"
    exit 1
fi
exec sudo /usr/bin/calamares --disable-update-check
INSTALL
chmod +x config/includes.chroot/usr/local/bin/installDotos

cat > config/includes.chroot/usr/share/applications/installDotos.desktop <<'DESKTOP'
[Desktop Entry]
Name=Install DOT-OS
Comment=Launch the Calamares installer
Exec=/usr/local/bin/installDotos
Terminal=false
Type=Application
Categories=System;Settings;
Icon=drive-harddisk
DESKTOP

# --- dot-detect tool ---
mkdir -p config/includes.chroot/usr/local/bin
cat > config/includes.chroot/usr/local/bin/dot-detect <<'DETECT'
#!/bin/sh
echo "=== PACKARD BELL DOT HARDWARE REPORT ==="
grep "model name" /proc/cpuinfo | head -1
lspci -nn | grep -i vga
lspci -nn | grep -i network
lsmod | grep -Ei "i915|ath9k|brcmsmac|snd_hda"
nmcli device wifi list 2>/dev/null | head -5
echo "=== paste this output into the AI chat if lines are empty ==="
DETECT
chmod +x config/includes.chroot/usr/local/bin/dot-detect

echo ">>> Building ISO (30-90 min) - keep this window open..."
sudo lb build

ISO=~/dot-os-build/live-image-i386.hybrid.iso
WINUSER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r' || echo "")
DEST="/mnt/c/Users/$WINUSER/Desktop"
if [ -d "$DEST" ]; then
    cp "$ISO" "$DEST/DOT-OS-i386.iso"
    echo ">>> DONE! ISO on your Windows Desktop: DOT-OS-i386.iso"
else
    echo ">>> DONE! ISO at: $ISO"
fi
echo ">>> Boot the Dot, press Super+D for apps, Super+S for the DOT Store, or run installDotos to install the system."
