#!/bin/bash
# ============================================================
#  DOT-OS Builder — Packard Bell Dot (model C/PAV80 family)
#  Custom lightweight 32-bit Linux ISO
#  Host: Debian/Ubuntu/MX Linux (64-bit host OK), ~10GB free, internet
#  Run:  chmod +x build-dot-os.sh && ./build-dot-os.sh
# ============================================================
set -e

echo "[1/5] Installing live-build tools..."
sudo apt update
sudo apt install -y live-build debootstrap xorriso isolinux

echo "[2/5] Creating build config (32-bit / i386)..."
mkdir -p dot-os-build && cd dot-os-build
lb config \
    --distribution bookworm \
    --architectures i386 \
    --binary-images iso-hybrid \
    --debian-installer live \
    --archive-areas "main contrib non-free non-free-firmware" \
    --bootappend-live "boot=live components quiet splash"

echo "[3/5] Writing DOT-SPECIFIC package list..."
cat > config/package-lists/desktop.list.chroot <<'PKGS'
# --- core ---
linux-image-686
live-boot
systemd-sysv
# --- X + EXACT Dot graphics (GMA 3150) + touchpad ---
xorg
xserver-xorg-video-intel
xserver-xorg-input-synaptics
icewm
lightdm
# --- networking + BOTH Wi-Fi chip variants shipped in Dots ---
network-manager
network-manager-gnome
firmware-atheros
firmware-brcm80211
firmware-realtek
firmware-iwlwifi
wireless-tools
wpasupplicant
ethtool
# --- sound (Intel HDA in the Dot) ---
alsa-utils
pulseaudio
pavucontrol
# --- storage: card reader + NTFS for old Windows drives ---
ntfs-3g
udisks2
# --- apps ---
firefox-esr
mousepad
pcmanfm
lxterminal
htop
# --- maintenance ---
gparted
synaptic
fonts-dejavu
PKGS

echo "[4/5] Adding Dot-model first-boot + RAM hooks..."
mkdir -p config/hooks/normal

cat > config/hooks/normal/050-dot-model-setup.hook.chroot <<'HOOK'
#!/bin/sh
# --- zram for 2GB RAM ---
apt-get install -y zram-tools
cat >> /etc/default/zramswap <<'EOF'
ALGO=lz4
PERCENT=50
PRIORITY=100
EOF

# --- Intel GMA 3150 tweaks (Atom N450/N570): fixes common
#     screen-tearing and boot-to-black issues on the Dot ---
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/20-intel-dot.conf <<'EOF'
Section "Device"
    Identifier  "Intel GMA 3150"
    Driver      "intel"
    Option      "AccelMethod"  "uxa"
    Option      "TearFree"     "true"
EndSection
EOF

# --- Save ~50MB RAM: disable unused services on 2GB machines ---
for svc in bluetooth cups-browsed; do
    systemctl mask $svc 2>/dev/null || true
done
HOOK
chmod +x config/hooks/normal/050-dot-model-setup.hook.chroot

# --- first-boot script: detects YOUR Dot's exact chips and
#     tells you if a driver is missing (run: sudo dot-detect) ---
cat > config/includes.chroot/usr/local/bin/dot-detect <<'DETECT'
#!/bin/sh
echo "=== PACKARD BELL DOT HARDWARE REPORT ==="
echo "--- CPU ---"; grep "model name" /proc/cpuinfo | head -1
echo "--- Video ---"; lspci -nn | grep -i vga
echo "--- Wi-Fi ---"; lspci -nn | grep -i network; lsusb | grep -i net
echo "--- Loaded drivers ---"; lsmod | grep -Ei "i915|ath9k|brcmsmac|snd_hda" 
echo "--- Test Wi-Fi ---"; nmcli device wifi list 2>/dev/null | head -5
echo "======================================="
echo "If Wi-Fi or video line is EMPTY above,"
echo "copy this output to the AI chat for a fix."
DETECT
chmod +x config/includes.chroot/usr/local/bin/dot-detect 2>/dev/null || \
    (mkdir -p config/includes.chroot/usr/local/bin && \
     cp /dev/null config/includes.chroot/usr/local/bin/dot-detect)

echo "[5/5] Building ISO (30-90 min)..."
sudo lb build

echo ""
echo "DONE -> $(pwd)/live-image-i386.hybrid.iso"
echo "Flash: dd if=live-image-i386.hybrid.iso of=/dev/sdX bs=4M status=progress"
echo "On the Dot, run: sudo dot-detect   (shows if all drivers loaded)"
