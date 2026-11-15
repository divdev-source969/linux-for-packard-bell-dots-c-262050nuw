#!/bin/bash
# ============================================================
#  DOT-OS WSL One-Shot Builder — Packard Bell Dot 262050NUW
#  v4.3 — DOT OS branding (boot splash, boot menu, os-release) + optional AtlasLight .deb
#  (builds Debian bookworm i386 from an Ubuntu/WSL host)
#  Run:  chmod +x wsl-dot-os-builder.sh && ./wsl-dot-os-builder.sh
#  Needs WSL2, and must NOT be run from /mnt/c.
# ============================================================
set -eo pipefail

# --- run as root (so lb config/build share one owner), remember real user ---
if [ "$(id -u)" -ne 0 ]; then exec sudo -E bash "$0" "$@"; fi
REAL_USER="${SUDO_USER:-root}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
BUILD_DIR="$REAL_HOME/dot-os-build"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- host tools: Ubuntu's live-build (3.0~a57) is ancient and can't build Debian ---
apt-get update
apt-get install -y debootstrap xorriso squashfs-tools cpio dosfstools mtools \
    syslinux syslinux-common isolinux git make gettext po4a debian-archive-keyring zstd
if dpkg -s live-build >/dev/null 2>&1; then apt-get purge -y live-build; fi
rm -rf /tmp/live-build-src
git clone --depth 1 https://salsa.debian.org/live-team/live-build.git /tmp/live-build-src
make -C /tmp/live-build-src install
echo ">>> live-build version: $(lb --version)"

# --- fresh build dir (the old script never created/entered it) ---
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

DEB=http://deb.debian.org/debian/
lb config \
    --mode debian \
    --distribution bookworm \
    --architectures i386 \
    --linux-flavours 686-pae \
    --mirror-bootstrap "$DEB" \
    --mirror-chroot "$DEB" \
    --mirror-binary "$DEB" \
    --binary-images iso-hybrid \
    --bootloaders syslinux \
    --debian-installer live \
    --archive-areas "main contrib non-free non-free-firmware" \
    --iso-application "DOT OS" \
    --iso-volume "DOT-OS" \
    --bootappend-live "boot=live components quiet splash hostname=dot-os username=dot"

# --- optional: bake AtlasLight into the ISO if atlaslight_*_i386.deb sits next to this script ---
mkdir -p config/packages.chroot
for d in "$SCRIPT_DIR"/atlaslight_*_i386.deb; do
    if [ -f "$d" ]; then
        cp "$d" config/packages.chroot/
        echo ">>> Including $(basename "$d") in the ISO"
    fi
done

# --- DOT OS boot menu: copy live-build's syslinux templates and rename Debian -> DOT OS ---
# (best effort: if a template folder is missing this just prints a warning)
if [ -d /usr/share/live/build/bootloaders ]; then
    mkdir -p config/bootloaders
    cp -r /usr/share/live/build/bootloaders/. config/bootloaders/
    # text files only: menu titles and labels
    grep -rIl "Debian" config/bootloaders 2>/dev/null | while read -r f; do
        sed -i 's/Debian GNU\/Linux/DOT OS/g; s/Debian Live/DOT OS/g; s/Debian/DOT OS/g' "$f"
    done
    # the stock menu picture carries the Debian logo; drop it for a plain dark menu
    grep -rIl "^menu background" config/bootloaders 2>/dev/null | while read -r f; do
        sed -i '/^menu background/d' "$f"
    done
    echo ">>> Boot menu renamed to DOT OS"
else
    echo "WARNING: live-build bootloader templates not found; boot menu will keep default names"
fi

cat > config/package-lists/desktop.list.chroot <<'PKGS'
live-boot
systemd-sysv
xorg
xwayland
libgl1-mesa-dri
icewm
lightdm
lightdm-gtk-greeter
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
zram-tools
# --- DOT OS boot splash ---
plymouth
PKGS

mkdir -p config/hooks/normal

# --- hook: Dot model base setup ---
# NOTE: No forced Xorg Device section. Different Dot models use different GPUs
# (GMA 3150 -> i915 kernel driver, GMA 3600/Cedarview -> gma500). Xorg's built-in
# "modesetting" driver autodetects both, so we let it choose.
cat > config/hooks/normal/050-dot-model-setup.hook.chroot <<'HOOK'
#!/bin/sh
printf 'ALGO=lz4\nPERCENT=50\nPRIORITY=100\n' >> /etc/default/zramswap
systemctl mask bluetooth cups-browsed 2>/dev/null || true
HOOK
chmod +x config/hooks/normal/050-dot-model-setup.hook.chroot

# --- hook: liquid-glass look + DOT Store ---
cat > config/hooks/normal/060-liquid-glass.hook.chroot <<'HOOK'
#!/bin/sh
mkdir -p /etc/skel/.config/sway /etc/skel/.config/waybar /etc/skel/.config/wofi /etc/skel/.config/foot

# ===== SWAY: Hyprland-style binds + glass aesthetics =====
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
bindsym $mod+q kill
bindsym $mod+d exec $menu
bindsym $mod+s exec $store
bindsym $mod+Shift+e exec swaymsg exit
bindsym $mod+f fullscreen toggle
bindsym $mod+v floating toggle
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
/* liquid glass: translucent dark glass, rounded, glowing blue rim */
window#waybar {
  background: rgba(30, 30, 46, 0.55);
  color: #cdd6f4;
  border-radius: 22px;
  border: 1.5px solid rgba(137, 180, 250, 0.45);
  box-shadow: 0 0 18px rgba(137, 180, 250, 0.25);
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

# ===== Sway session wrapper: gma500 has no 3D, so allow software rendering =====
cat > /usr/local/bin/sway-dot <<'WRAP'
#!/bin/sh
export WLR_RENDERER_ALLOW_SOFTWARE=1
export WLR_NO_HARDWARE_CURSORS=1
export XDG_CURRENT_DESKTOP=sway
exec sway "$@"
WRAP
chmod +x /usr/local/bin/sway-dot

mkdir -p /usr/share/wayland-sessions
cat > /usr/share/wayland-sessions/sway-dot.desktop <<'DESK'
[Desktop Entry]
Name=DOT Desktop (Sway)
Comment=Liquid-glass dock desktop for the Packard Bell Dot
Exec=/usr/local/bin/sway-dot
Type=Application
DESK

# ===== DOT STORE: lightweight app store =====
cat > /usr/local/bin/dot-store <<'STORE'
#!/bin/bash
# DOT Store - lightweight software center for 2GB machines.
# Runs installs inside a terminal so sudo / progress work.
# NOTE: in the live session, installs live in RAM. Install DOT-OS to disk for big apps.
ITEMS="
Internet | Firefox (installed) | echo already-installed
Internet | Chromium browser | sudo apt-get install -y chromium
Internet | Thunderbird mail | sudo apt-get install -y thunderbird
Internet | Transmission torrent | sudo apt-get install -y transmission-gtk
Internet | FileZilla FTP | sudo apt-get install -y filezilla
Media | VLC media player | sudo apt-get install -y vlc
Media | Audacity audio editor | sudo apt-get install -y audacity
Media | GIMP image editor | sudo apt-get install -y gimp
Media | Inkscape vector art | sudo apt-get install -y inkscape
Office | LibreOffice suite | sudo apt-get install -y libreoffice
Office | Okular PDF reader | sudo apt-get install -y okular
Office | Xournal++ notes | sudo apt-get install -y xournalpp
Dev | Geany IDE | sudo apt-get install -y geany
Dev | Python 3 + pip | sudo apt-get install -y python3-pip
Dev | Git | sudo apt-get install -y git
Dev | Neovim | sudo apt-get install -y neovim
Games | SuperTux | sudo apt-get install -y supertux
Games | SuperTuxKart | sudo apt-get install -y supertuxkart
Games | RetroArch emulator | sudo apt-get install -y retroarch
Tools | htop | sudo apt-get install -y htop
Tools | GParted | sudo apt-get install -y gparted
Tools | Neofetch | sudo apt-get install -y neofetch
Tools | Timeshift backup | sudo apt-get install -y timeshift
System | Update everything | sudo apt-get update && sudo apt-get upgrade -y
System | Open Synaptic (FULL store) | synaptic
"
CHOICE=$(echo "$ITEMS" | grep -v '^$' | wofi --dmenu --prompt "DOT Store  (Super+S)" --width 520 --height 500 2>/dev/null)
[ -z "$CHOICE" ] && exit 0
CMD=$(echo "$CHOICE" | awk -F'|' '{print $3}')
case "$CMD" in
  *synaptic*) sudo synaptic ;;
  *) foot bash -c "$CMD; echo; read -rp 'Done. Press Enter to close.' _" ;;
esac
STORE
chmod +x /usr/local/bin/dot-store

# make the DOT sway session the default; IceWM stays available in the lightdm session menu
mkdir -p /etc/lightdm/lightdm.conf.d
printf '[Seat:*]\nuser-session=sway-dot\n' > /etc/lightdm/lightdm.conf.d/50-dot-default.conf
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

# --- hook: DOT OS branding (boot splash, os-release, login screen) ---
cat > config/hooks/normal/080-dot-branding.hook.chroot <<'HOOK'
#!/bin/sh
# ---- system identity: shows as DOT OS in settings, neofetch, installer, etc. ----
cat > /usr/lib/os-release <<'EOF'
PRETTY_NAME="DOT OS 1.0 (Debian 12 base)"
NAME="DOT OS"
VERSION_ID="1.0"
VERSION="1.0"
VERSION_CODENAME=bookworm
ID=dotos
ID_LIKE=debian
EOF
ln -sf ../usr/lib/os-release /etc/os-release
printf 'DOT OS 1.0 \\n \\l\n\n' > /etc/issue
printf 'DOT OS 1.0\n' > /etc/issue.net
printf '\nWelcome to DOT OS.\n\n' > /etc/motd
echo dot-os > /etc/hostname

# ---- boot splash: replace the Debian logo with a DOT OS splash ----
mkdir -p /usr/share/plymouth/themes/dotos
cat > /usr/share/plymouth/themes/dotos/dotos.plymouth <<'EOF'
[Plymouth Theme]
Name=DOT OS
Description=DOT OS boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/dotos
ScriptFile=/usr/share/plymouth/themes/dotos/dotos.script
EOF
cat > /usr/share/plymouth/themes/dotos/dotos.script <<'EOF'
Window.SetBackgroundTopColor(0.07, 0.07, 0.11);
Window.SetBackgroundBottomColor(0.07, 0.07, 0.11);

title = Image.Text("DOT OS", 0.54, 0.71, 0.98, 1, "Sans Bold 44");
title_sprite = Sprite(title);
title_x = Window.GetX() + Window.GetWidth() / 2 - title.GetWidth() / 2;
title_y = Window.GetY() + Window.GetHeight() / 2 - title.GetHeight() / 2 - 20;
title_sprite.SetX(title_x);
title_sprite.SetY(title_y);

sub = Image.Text("starting...", 0.65, 0.68, 0.78, 1, "Sans 14");
sub_sprite = Sprite(sub);
sub_sprite.SetX(Window.GetX() + Window.GetWidth() / 2 - sub.GetWidth() / 2);
sub_sprite.SetY(title_y + title.GetHeight() + 20);
EOF
plymouth-set-default-theme dotos || true
update-initramfs -u -k all || true

# ---- login screen: plain dark background, no Debian artwork ----
mkdir -p /etc/lightdm
cat > /etc/lightdm/lightdm-gtk-greeter.conf <<'EOF'
[greeter]
background=#11111b
theme-name=Adwaita-dark
font-name=Sans 11
EOF
HOOK
chmod +x config/hooks/normal/080-dot-branding.hook.chroot

# --- dot-detect tool ---
mkdir -p config/includes.chroot/usr/local/bin
cat > config/includes.chroot/usr/local/bin/dot-detect <<'DETECT'
#!/bin/sh
echo "=== PACKARD BELL DOT HARDWARE REPORT ==="
grep "model name" /proc/cpuinfo | head -1
lspci -nn | grep -i vga
lspci -nn | grep -i network
lsmod | grep -Ei "i915|gma500|psb|ath9k|brcmsmac|snd_hda"
nmcli device wifi list 2>/dev/null | head -5
echo "=== paste this output into the AI chat if lines are empty ==="
DETECT
chmod +x config/includes.chroot/usr/local/bin/dot-detect

echo ">>> Building ISO (30-90 min) - keep this window open..."
lb build 2>&1 | tee "$BUILD_DIR/build.log"

ISO="$BUILD_DIR/live-image-i386.hybrid.iso"
chown "$REAL_USER":"$REAL_USER" "$ISO" 2>/dev/null || true
WINUSER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r' || echo "")
DEST="/mnt/c/Users/$WINUSER/Desktop"
if [ -n "$WINUSER" ] && [ -d "$DEST" ]; then
    cp "$ISO" "$DEST/DOT-OS-i386.iso"
    echo ">>> DONE! ISO on your Windows Desktop: DOT-OS-i386.iso"
else
    echo ">>> DONE! ISO at: $ISO"
fi
echo ">>> Boot the Dot, press Super+D for apps, Super+S for the DOT Store."
