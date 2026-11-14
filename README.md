# DOT-OS — Linux for Packard Bell Dot (model 262050NUW family)

Custom lightweight 32-bit Linux live ISO, built with Debian live-build,
targeted at the Packard Bell Dot netbook (Atom N450/N570, Intel GMA 3150,
2 GB RAM, ~8 GB disk).

## Why no "ported Windows 7 drivers"?
Windows .sys/.inf drivers cannot run on Linux (different kernel ABI — no
translation layer exists). This build instead ships the native Linux
drivers for every chip in this machine, preconfigured:

| Component        | Windows 7 driver | Linux equivalent (included)      |
|------------------|------------------|----------------------------------|
| GMA 3150 graphics| Intel .inf       | xserver-xorg-video-intel + config|
| Wi-Fi Atheros    | .sys             | ath9k + firmware-atheros         |
| Wi-Fi Broadcom   | .sys             | brcmsmac + firmware-brcm80211    |
| Touchpad         | Synaptics .inf   | xserver-xorg-input-synaptics     |
| Sound            | Realtek .sys     | snd-hda-intel (in kernel)        |
| Webcam           | .sys             | uvcvideo (in kernel)             |

## Build (on Ubuntu)
    chmod +x build.sh && ./build.sh

Output: `dot-os-build/live-image-i386.hybrid.iso`

## After booting the Dot
Run:  sudo dot-detect
It prints your exact hardware and which drivers loaded. If a line is
empty, copy the output to the AI chat for a fix.
