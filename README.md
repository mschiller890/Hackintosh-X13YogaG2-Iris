# Iris Xe acceleration on macOS Tahoe — Lenovo ThinkPad X13 Yoga Gen 2

Hardware-accelerated graphics (**Metal, Core Animation, Liquid Glass**) for the **Intel Iris Xe of the i5-1135G7 (Tiger Lake-LP, 8086:9A49)** on **macOS Tahoe 26.7.1**, in an OpenCore hackintosh.

This fork is derived from the upstream project, which ran Apple's unreleased Tiger Lake driver on a newer, *spoofed* GPU (Raptor Lake-P). The ThinkPad X13 Yoga Gen 2 is different: its i5-1135G7 **is** the GPU Apple's driver was written for — real Tiger Lake, `8086:9A49`, no spoof, no hybrid-CPU work. The hard part of the stack (the Metal driver patches, `libxedrv`, the shader compiler, the kernel patches) is GPU-specific and applies unchanged; what this fork changes is the laptop layer: ACPI, audio (AppleALC instead of the upstream SOF speaker stack), input and power management.

> ⚠️ **Status: prepared, not yet booted on hardware.** This fork has not been tested on a real ThinkPad yet. Everything below is the bring-up plan and expected behaviour; treat it as unverified until someone reports a successful boot. See [docs/STATUS.md](docs/STATUS.md).

## Hardware

| Area | Device |
|---|---|
| Machine | Lenovo ThinkPad X13 Yoga Gen 2 (20W8), convertible |
| CPU | Intel Core i5-1135G7 (Tiger Lake-LP, 4C/8T, no E-cores) |
| GPU | Intel Iris Xe, `8086:9A49` (native, no spoof) |
| Panel | 1920×1200 IPS, touch, convertible |
| Touchpad | ELAN0674 (`04F3:3193`) on I2C0, GPIO pin 0x15 |
| Touchscreen + pen | Wacom WACF2208 (`056A:5286`) on I2C1, GPIO pin 0x0A |
| Keyboard / TrackPoint | PS/2 (AT keyboard + Elan TrackPoint) |
| Audio | Realtek ALC285 on legacy HDA (`HDAS`) |
| Wi-Fi / BT | Intel AX201 |
| NVMe | Samsung PM981a |
| Camera | Chicony (Intel IPU6) — no macOS driver |
| Fingerprint | Synaptics `06cb:00f9` (USB) — no macOS driver |
| EC | `\_SB.PC00.LPCB.EC`, already named `EC` |

## Expected support (untested)

| Area | Status |
|---|---|
| Metal desktop, Liquid Glass, WindowServer | expected ✅ (same GPU as the upstream stack) |
| CPU | ✅ XCPM works as-is on Tiger Lake (no hybrid-CPU fixes needed) |
| Touchpad / touchscreen / keyboard | expected ✅ via VoodooI2C (GPIO interrupts under the XOSI Windows spoof) |
| Audio | ⚠️ AppleALC with an `alcid=` layout to be determined (candidates: 17, 99, 11, 21, 29, 66, 14, 15) |
| Wi-Fi, Bluetooth | expected ✅ (AirportItlwm + IntelBluetoothFirmware, unchanged) |
| Battery | expected ✅ (real EC, SMCBatteryManager) |
| Vulkan (MoltenVK) | expected ✅ (same accelerated Metal driver) |
| OpenGL | ⚠️ software renderer only (same as upstream; experiment prepared in [docs/OPENGL.md](docs/OPENGL.md)) |
| System sleep | ❌ experimental only (Modern Standby firmware; S3 selectable in BIOS for testing) |
| Camera, fingerprint | ❌ not working (same as upstream) |

## Already installed? Update

If the stack already runs on your machine, update it like this (latest changes in [CHANGELOG.md](CHANGELOG.md)):

1. **Back up the EFI you boot from** (a copy of the `EFI` folder or a second bootable USB EFI).
2. In your clone:
   ```sh
   git pull
   zsh install.sh          # rebuilds and reinstalls NootedGreen, the Metal driver, libxedrv and the shader compiler
   ```
3. Copy the new `build/NootedGreen.kext` over `EFI/OC/Kexts/NootedGreen.kext` on the EFI you boot from.
4. Reboot and check: `kmutil showloaded | grep NootedGreen`.

Don't run `make-efi.sh` again to update: it generates **new** serial numbers (SMBIOS), which signs you out of
iCloud/iMessage. Keep your EFI and only replace the kext.

## Other hardware

This repository targets only the ThinkPad X13 Yoga Gen 2. The user-space part of the stack is GPU-specific and would
work on any Tiger Lake (or newer, spoofed) laptop, but you would need your own EFI (ACPI, USB map, input devices).
The full manual procedure is in [docs/INSTALL.md](docs/INSTALL.md).

## How it works (one paragraph)

The EFI presents the GPU as Tiger Lake (`device-id 9A49`); on this machine that is its real identity. Apple's TGL
kexts load from `/Library/Extensions`, and **NootedGreen** patches them in memory: display engine 13 quirks, the
GuC-less host scheduler, broken resolve paths, IOSurface layout changes in Tahoe, GPU frequency, and more
([docs/KERNEL-PATCHES.md](docs/KERNEL-PATCHES.md)). In user space, the TGL **Metal driver** is binary-patched and gets
an adapter library (`libxedrv`) that converts Tahoe's private Metal structures to the old layout and works around
hardware limits. The TGL **shader compiler** (IGC gen12lp, LLVM 3902) runs inside Tahoe's compiler service (LLVM 32023)
through an API adapter and an LLVM bridge ([docs/METAL.md](docs/METAL.md)).

## Repository layout

```
EFI/                     OpenCore EFI for the X13 Yoga Gen 2 (serials removed — generate your own)
  OC/config.plist        accelerated config
  OC/config-install.plist  safe config for installing macOS (NootedGreen off, verbose)
src/NootedGreen/         the modified NootedGreen source (Lilu plugin)
build-nootedgreen.sh     builds src/NootedGreen with only the Command Line Tools
src/HookCase/            NootedGreen's modified HookCase (MIT) — the TGL kexts depend on it
build-hookcase.sh        builds src/HookCase (required; installed to /Library/Extensions by macos/install-macos.sh)
patches/                 diff of this fork against upstream NootedGreen 95f8189
macos/                   user-space stack: Metal driver patcher, libxedrv, shader compiler, VA (video) plugin patcher, installer
tools/                   xe-res (resolution/DPI), xe-brilho (brightness), xe-perfil (color profile), xe-toque (touchscreen gestures),
                         XeShim + xectl (register access), diagnostics/ (the test programs used to find bugs),
                         audio/ (AppleALC is used for this machine; AudShim/XeSpeakers are upstream-only),
                         sleep/ (pmset + lid agent), xe-haptic + xe-hapticbar (touchpad vibration),
                         fingerprint/ (unsupported on this machine), xe-pblock/ (power button locks the screen),
                         xe-temp/ (menu-bar CPU temperature)
docs/                    install guide, patch catalogs, status, debugging notes
```

Documentation: [INSTALL](docs/INSTALL.md) · [STATUS](docs/STATUS.md) · [KERNEL-PATCHES](docs/KERNEL-PATCHES.md) ·
[METAL](docs/METAL.md) · [DEBUGGING](docs/DEBUGGING.md) · [HISTORY](docs/HISTORY.md) (how it was done, phase by phase) ·
[EXPERIMENTS](docs/EXPERIMENTS.md) (what failed and why) · [CATALOG](docs/CATALOG.md) (full patch and tool reference) ·
[OPENGL](docs/OPENGL.md) (OpenGL activation experiment).

## Quick start (ThinkPad X13 Yoga Gen 2)

**1. Make your EFI** (on any Mac or Linux, with git):

```sh
git clone https://github.com/mschiller890/Hackintosh-X13YogaG2-Iris.git && cd Hackintosh-X13YogaG2-Iris
zsh make-efi.sh        # -> dist/EFI with YOUR OWN serial numbers (never share them)
```

On Linux, download the OpenCore release pinned in `make-efi.sh`, run `macserial.linux -m MacBookPro16,2 -g -n 1`,
and fill `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` in both plists with a plist editor (keep them empty in git).

**2. BIOS** (ThinkPad Setup): Secure Boot off, UEFI-only boot, **Sleep State = "Linux" (S3)**, VT-d left on,
Hyper-Threading and SpeedStep on, CFG Lock left as-is (`AppleXcpmCfgLock` covers it), "OS Optimization" = Other OS if present.

**3. Install macOS Tahoe 26.7.1 (25G241)** booting with `EFI/OC/config-install.plist` renamed to `config.plist`
(acceleration off, verbose, I2C polling). Install to the second disk/partition for dual-boot with Linux. Keep the USB
installer bootable as rollback.

**4. On the new macOS**, with the accelerated `config.plist` back in place:

```sh
xcode-select --install          # Command Line Tools, once
zsh install.sh                  # checks, downloads Apple's driver bundles via NootedGreen, builds, installs
```

Copy the freshly built `build/NootedGreen.kext` to `EFI/OC/Kexts/`, approve the extension if asked, reboot.

`zsh install.sh --check` only runs the checks; `zsh install.sh --uninstall` removes everything.

**5. Audio**: add `alcid=NN` to the boot-args and reboot, trying the candidates in order
(17, 99, 11, 21, 29, 66, 14, 15). Speakers + headphone + internal mic are the pass criteria.

**Updating:** see [Already installed? Update](#already-installed-update).

## Credits

- **Upstream project** by JulioNectar ([Hackintosh-XPS13Plus-IrisXe-Tahoe](https://github.com/JulioNectar/Hackintosh-XPS13Plus-IrisXe-Tahoe)):
  the base of the GPU stack, the Metal driver patches, `libxedrv`, the shader compiler and the kernel patches.
- **NootedGreen** by StezzaPilot ([sgiammori/NootedGreen](https://github.com/sgiammori/NootedGreen)): the base of the kernel plugin and the source of the 16.0.32 driver bundles. Licensed under the *Thou Shalt Not Profit License 1.0*, which also covers the fork in `src/`.
- **WhateverXe** and **OpenCore Legacy Patcher fork** by b00t0x, and jkbuha's WhateverXe work: reference for Gen12 on macOS.
- **BlackHole** by Existential Audio (virtual audio output, GPL-3.0), built by `tools/build-blackhole.sh`.
- **Sound Open Firmware** (Intel SOF firmware and topologies, sof-bin) and the Linux `sound/soc/sof` + SoundWire drivers: the reference for the upstream audio stack (not used on this machine — AppleALC is).
- **laobamac/itlwm** (AirportItlwm-Tahoe, GPL-2.0), shipped in `EFI/OC/Kexts`.
- **IntelIGPU-Tahoe**: reference for running the TGL Metal driver on Tahoe.
- **acidanthera** (OpenCore, Lilu, WhateverGreen, VirtualSMC, MacKernelSDK), **OpenIntelWireless** (itlwm, IntelBluetoothFirmware), **VoodooI2C**, **USBToolBox**.
- Fork for the ThinkPad X13 Yoga Gen 2 by mschiller890.

## License

[Thou Shalt Not Profit License 1.0](LICENSE), the license of NootedGreen, which this project derives from. Third-party
kexts in `EFI/` keep their own licenses, and no Apple binaries are included: see [NOTICE.md](NOTICE.md).