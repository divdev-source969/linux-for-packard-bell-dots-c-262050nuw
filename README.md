# DOT-OS — Linux for Packard Bell Dot (262050NUW family)

Custom lightweight **32-bit** Linux live ISO, built with Debian live-build,
targeted at the Packard Bell Dot netbook (Atom N450/N570, Intel GMA 3150,
2 GB RAM, spinning HDD).

## What's inside

- **Liquid-glass desktop** — Sway (Wayland) with a centered translucent dock,
  Hyprland-style Super-key binds, Catppuccin theme
  - `Super+Enter` terminal (foot)   - `Super+D` app launcher (wofi)
  - `Super+S` **DOT Store**         - `Super+Q` close window
- **DOT Store** — lightweight one-click software center + Synaptic for the
  full 50,000+ package repo
- **2 GB RAM tuned** — zram swap (lz4), earlyoom, capped journald logs,
  apt background timers disabled
- **HDD tuned** — minimal writes, no boot-time disk thrash

## Why no "ported Windows 7 drivers"?

Windows .sys/.inf drivers cannot run on Linux (different kernel ABI — no
translation layer exists, and decompiling them is legally prohibited).
This build ships the native Linux drivers for every chip in this machine —
most written by the chip vendors themselves (Intel `i915`, Atheros `ath9k`):

| Component         | Linux equivalent (included)        |
|-------------------|------------------------------------|
| GMA 3150 graphics | xserver-xorg-video-intel + config  |
| Wi-Fi (both)      | ath9k / brcmsmac + firmware packs  |
| Touchpad          | xserver-xorg-input-synaptics       |
| Sound             | snd-hda-intel (in kernel)          |
| Webcam            | uvcvideo (in kernel)               |

## Build it

**On Windows (one click):** double-click `compile.bat`
(requires the Ubuntu app from the Microsoft Store / WSL2)

**Anywhere else:**
```bash
chmod +x wsl-dot-os-builder.sh && ./wsl-dot-os-builder.sh
```
Output: `dot-os-build/live-image-i386.hybrid.iso`

## After booting the Dot

Run:  sudo dot-detect
It prints your exact hardware and which drivers loaded. If a line is
empty, copy the output into an AI chat for a fix.
