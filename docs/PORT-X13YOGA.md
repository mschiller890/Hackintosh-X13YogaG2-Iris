# Port: Lenovo ThinkPad X13 Yoga Gen 2 (20W8, i5-1135G7)

This branch (`x13-yoga-gen2`) ports the EFI from the Dell XPS 13 Plus 9320 (Raptor Lake-P, spoofed
to Tiger Lake) to a **ThinkPad X13 Yoga Gen 2** — **real Tiger Lake**, which is what Apple's driver
was written for. The port was prepared from a Linux enumeration of the machine (ACPI tables,
input devices, PCI/USB) and has **not yet been tested on hardware**; treat everything below as the
bring-up plan and report what actually happens.

## Why this is the natural target

The XPS has an i7-1360P (Raptor Lake-P, GPU `8086:A7A0`) and spoofs it to Tiger Lake (`9A49`) so
Apple's TGL driver (GPUDriversIntel 16.0.32, written for Macs that never shipped) attaches. The
X13 Yoga's i5-1135G7 **is** that GPU — `8086:9A49`, no spoof. The hard part of this project
(the Metal driver patches, libxedrv, the shader compiler) is GPU-specific, not laptop-specific,
so it all applies unchanged. NootedGreen attaches through Lilu (`IOResources`) and its kernel
patches target device `0x9A49` natively.

## Detected hardware (from Fedora, Oct 2026)

| Area | Device | macOS expectation |
|---|---|---|
| CPU | i5-1135G7 (Tiger Lake-LP, 4P+8T, model 140) | ✅ XCPM via plugin-type (SSDT-PLUG-ALT); not hybrid, so **XE-PM/`-ngreenpm` does not apply** |
| GPU | Iris Xe `8086:9A49` (native, no spoof) | ✅ Apple TGL driver, NootedGreen TGL tiers |
| Panel | 1920×1200 IPS touch | ✅ standard eDP, no OLED/AUX brightness work needed |
| Touchpad | ELAN0674 (`04F3:3193`) on **I2C0**, GPIO pin **0x15** @ `\_SB.GPI0` | ✅ VoodooI2C + VoodooI2CHID, GPIO interrupts (stock firmware `_CRS` already returns GpioInt under the XOSI Windows spoof) |
| Touchscreen + pen | Wacom WACF2208 (`056A:5286`) on **I2C1**, GPIO pin **0x0A** | ✅ touch via VoodooI2CHID · ⚠️ AES pen experimental |
| Keyboard / TrackPoint | PS/2 (AT keyboard + Elan TrackPoint) | ✅ VoodooPS2Controller |
| Audio | Realtek **ALC285** on legacy HDA (`HDAS`, `00:1f.3`), SOF firmware under Linux | ✅ **AppleALC** (new in this branch) — layout-id needs testing, see below |
| Wi-Fi / BT | Intel **AX201** (same card as the XPS) | ✅ AirportItlwm + IntelBluetoothFirmware, unchanged |
| NVMe | Samsung PM981a (MZVLB512) | ✅ NVMeFix; PM981a is known to be slow at writes under macOS |
| Camera | Chicony `04f2:b6f8` (Intel IPU6) | ❌ same IPU6 dead-end as the XPS |
| Fingerprint | Synaptics `06cb:00f9` (USB) | ❌ no macOS driver (the XPS Goodix sudo trick does not apply) |
| YICHIP `3151:3020` | BT remote dongle | n/a (USB accessory) |
| EC | `\_SB.PC00.LPCB.EC`, **already named `EC`** | ✅ SMCBatteryManager talks to it directly; the fake `SSDT-EC` had to be **removed** (path collision) |

## What changed vs the XPS config

| Change | Why |
|---|---|
| **Removed `SSDT-EC.aml`** | The ThinkPad EC is already named `EC` at exactly the path the fake one used (`\_SB.PC00.LPCB.EC`); loading both is an `AE_ALREADY_EXISTS` collision. The real EC is also what SMCBatteryManager needs. |
| **Removed `SSDT-XPS-I2C.aml` + its 6 renames** | XPS-only. The ThinkPad I2C controllers already declare `_ADR` (0x00150000/1), and TPD0/TPL1's stock `_CRS` returns I2C+GpioInt resources once SSDT-XOSI makes the firmware believe it runs on Windows (`OSYS ≥ 0x07DC`); the pin numbers are filled in by the firmware's own `_INI`. |
| **Removed the `XPS: Scope RHUB.HS08` patch** | Dell USB mapping quirk. |
| **Added `HDAS → HDEF` ACPI rename** | The ThinkPad's audio controller is named `HDAS`; AppleALC expects `HDEF`. |
| **Added `AppleALC.kext` 1.9.8** | The XPS uses the repo's own AudShim/SOF stack for its SoundWire RT1316 amps; the ThinkPad's ALC285 is plain HDA, the standard AppleALC case. |
| **boot-args: `ngreen-dmc=adlp` → `ngreen-dmc=tgl`** | DMC firmware choice. `adlp` was for the Raptor Lake display engine; on real TGL hardware the source's `tgl` branch (TGL DMC v2.12) is correct. |
| **boot-args: removed `ngreenpm=22`** | XE-PM fixes XCPM on *hybrid* ADL/RPL CPUs (78.7 MHz HWP units, EPP clipping, missing C8/C10). Tiger Lake is a normal 4-core CPU; stock XCPM behaviour applies. Also its byte-level patch was only verified for the hybrid path on 26.7.1 25G241. |
| **boot-args: removed `ngreenblmax=17777`** | XPS OLED panel backlight maximum. The Yoga's IPS panel uses the standard range. |
| **`CpuTopologyRebuild` disabled** | It groups hybrid P/E cores; the i5-1135G7 is a plain 4C8T CPU. |
| **`CustomSMBIOSGuid = false`** | The quirk is Dell-specific. |
| Everything else kept | `ig-platform-id 0000499A` + `device-id 9A49` now inject the *real* identity; `-ngreentglwithgfx` still forces the TGL patch tiers in this fork (see boot-arg note below); SSDT-GPI0 works because GPI0 is at the same path (`\_SB.GPI0`) on both machines. |

## BIOS settings (ThinkPad Setup)

- **Secure Boot**: off · **UEFI-only boot** (CSM off)
- **Sleep State** (Config → Power): set to **"Linux"** (S3) — the default "Windows" is
  Modern Standby, which macOS cannot use. Sleep itself is experimental in this project (see
  [STATUS](STATUS.md)); this just makes S3 *possible* to test.
- **VT-d**: leave on (the config keeps `DisableIoMapper=false`, like the XPS)
- **Hyper-Threading / SpeedStep**: on. CFG Lock: leave as-is — `AppleXcpmCfgLock=true` covers a
  locked MSR 0xE2 either way.
- "OS Optimization / Other OS": set to **Other OS** if your BIOS has it.

## Installing (dual-boot with Linux)

1. Generate **your own SMBIOS** — never reuse serials. On macOS run `zsh make-efi.sh`; on Linux:
   download the OpenCore release pinned in `make-efi.sh`, run `macserial.linux -m MacBookPro16,2 -g -n 1`,
   and fill `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` in both plists with any plist editor
   (keep them **empty in git** — that is why the committed configs have blanks).
2. Put the `EFI` folder on a FAT32 USB ESP. For the **installer**, rename
   `EFI/OC/config-install.plist` → `config.plist` (NootedGreen off, verbose, I2C polling).
3. Build the macOS installer per [INSTALL.md](INSTALL.md); install to the second disk/partition.
   Keep the USB installer bootable — it is your rollback.
4. After install: restore the accelerated `config.plist`, boot, then run the repo's `install.sh`
   and `macos/install-macos.sh` on the macOS side exactly as [INSTALL.md](INSTALL.md) says
   (they install the GPU bundles, HookCase and the user-space stack into `/Library/Extensions`).
   `install.sh` rebuilds NootedGreen from `src/` — the prebuilt kext in this EFI already matches,
   but rebuilding keeps you on the documented update path.

## Bring-up checklist (in order)

1. **Boot to desktop.** Apple logo from the first frame (`gfxrst=1`, `Resolution=Max`).
   If the screen stays black after the picker, see the debug notes in [DEBUGGING](DEBUGGING.md).
2. **GPU**: `kmutil showloaded | grep NootedGreen`, `ioreg -rc IntelAccelerator`. Desktop/Dock/Liquid
   Glass should be GPU-composited. OpenGL is software-only on this stack (same as the XPS, #21).
3. **Trackpad/keyboard**: if the trackpad is dead or lags, the GPIO path failed — try adding
   `-vi2c-force-polling` to `boot-args` as a diagnostic (the install config uses it already).
4. **Touchscreen**: multi-touch should just work through VoodooI2CHID; the pen is experimental
   (VoodooI2C HID digitizer support). `tools/xe-toque` (scroll, gestures, pen modes) can be
   installed per [INSTALL](INSTALL.md#touchscreen-extras-xe-toque) once touch works.
5. **Audio**: add `alcid=NN` to `boot-args` and reboot per candidate. ALC285 layouts to try, in
   order: **17, 99, 11, 21, 29, 66, 14, 15** (11 is the documented X1 Carbon 6 layout; 17/99 are
   the common ThinkPad ALC285 picks). Speakers + headphone + internal mic are the pass criteria.
   HDMI audio comes along with the GPU (`hda-gfx=onboard-1` is already set).
6. **Brightness**: F5/F6 should work through BrightnessKeys.kext; if not, `tools/xe-brilho daemon`
   (used on the XPS for the same Dell firmware quirk) may help — unknown on Lenovo.
7. **Battery**: menu-bar percentage via SMCBatteryManager (possible on the real `EC`).
8. **USB**: UTBDefault's generic map covers bring-up; build a real map later with USBToolBox's
   Windows tool or macOS USBMap, then drop `UTBDefault.kext`.
9. **Sleep**: only after everything else, with S3 selected in BIOS; expect to iterate (see STATUS).

## Known gaps

- **Sleep** — paused upstream, same caveat here (display sleep and lid-off work via `tools/sleep`).
- **Camera** (IPU6) and **fingerprint** — not working, same as the XPS.
- **FairPlay / Safari GPU decode** caveats — identical to the XPS (`-ngreengva` note in the README).
- **`xe-temp`** needs XE-PM's `debug.xepm.sensors`, which is tied to the (not-applicable) `-ngreenpm`
  work; package temperature on this machine may need SMCProcessor instead.
- **`-ngreentglwithgfx`** also enables the XPS panel's TCON DPCD patches inside NootedGreen; on
  the Yoga they should simply not match its panel, but if the internal panel misbehaves, drop the
  arg and check whether the TGL tiers still engage on native `9A49` (they may not be needed at all).

## Rollback

The Linux disk is untouched by any of this. Boot the X13 from the USB installer (or its EFI entry)
to go back to macOS, or pick Fedora in the OpenCore picker / BIOS boot menu. To return this repo
branch to XPS state: `git checkout main`.
