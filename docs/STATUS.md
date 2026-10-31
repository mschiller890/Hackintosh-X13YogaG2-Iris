# Status (October 2026, macOS Tahoe 26.7.1 25G241)

> **This fork has not yet been booted on hardware.** Everything below is the expected behaviour derived from the
> upstream stack and the ThinkPad's hardware map. Report what actually happens so this document can be corrected.

## Target machine

Lenovo ThinkPad X13 Yoga Gen 2 (20W8), i5-1135G7 (Tiger Lake-LP, 4C/8T, native `8086:9A49`), 1920×1200 IPS touch
panel, ALC285 audio, ELAN0674 touchpad, Wacom touchscreen/pen, AX201 Wi-Fi/BT, Samsung PM981a NVMe.

## Expected to work (inherited from the upstream stack)

These parts of the stack are GPU-specific or generic and should behave as on the upstream machine:

- Metal desktop: WindowServer, Dock, Finder, Liquid Glass materials, Mission Control, animations at 60 Hz.
- GPU at ~1300 MHz under load (XE-GTFREQ requests 1500 MHz = RP0; `GT_PERF_LIMIT_REASONS` shows the PL4/IccMax package limit holding it at ~1300), RC6 when idle.
- HEIC/YUV images, wallpapers (PLANES2). App icons, thumbnails and image layers (libxedrv).
- Video: YouTube in Chrome with GPU acceleration (software decode on the CPU), including 4K. Screen recording works. Safari works once an audio output exists.
- Brightness through `xe-brilho` (XeShim).
- All 4 cores / 8 threads (Tiger Lake is not hybrid; stock XCPM applies — no E-core fix needed).
- Fast shutdown/restart (XE-IDLEBOUND), trackpad and touchscreen on interrupts, multitouch gestures.
- Native Wi-Fi (AirportItlwm-Tahoe, macOS Wi-Fi menu; no HeliPort). Bluetooth as before.
- Clean boot screen (sharp logo, no garbage flash) and lid close → display off (`xe-lid`).
- Touchpad click-vibration strength (`xe-haptic`, `xe-hapticbar` menu-bar slider) — if the clickpad has a haptic motor.
- Power button locks the screen (`xe-pblock`) — untested on this machine.
- Vulkan 1.4 through MoltenVK on the accelerated Metal driver.
- `xe-temp` menu-bar CPU temperature (may need SMCProcessor instead of XE-PM sensors).

## Not yet verified on this machine

- **Audio (ALC285)**: AppleALC layout-id needs testing; candidates 17, 99, 11, 21, 29, 66, 14, 15.
- **Touchpad/keyboard**: expected to work via VoodooI2C GPIO interrupts, but the ThinkPad's firmware resources and
  pin numbers (0x15) come from the XOSI Windows spoof; verify on first boot.
- **Touchscreen + pen**: multi-touch should work via VoodooI2CHID; the AES pen is experimental.
- **Battery**: SMCBatteryManager talks to the real EC; verify the percentage shows.
- **USB**: generic UTBDefault map covers bring-up; build a real map later.
- **Sleep**: only after everything else, with S3 selected in BIOS; expect to iterate.
- **Brightness keys**: may work through BrightnessKeys.kext; if not, `xe-brilho daemon` (used on the upstream machine
  for an upstream firmware quirk) may help — unknown on Lenovo.
- **Display sleep / lid**: as on the upstream stack (backlight off only; eDP link not retrained).
- **`-ngreentglwithgfx`**: also enables upstream panel TCON DPCD patches inside NootedGreen; on the Yoga they should
  simply not match its panel, but if the internal panel misbehaves, drop the arg and check whether the TGL tiers still
  engage on native `9A49`.

## Known gaps (same as upstream)

- System sleep: S0 deep idle can be entered (experimental), but lid/power-button wake and relighting the panel (eDP
  retraining) do not work yet; work paused. Hibernation and an injected `_S3` were prepared but not tried.
- AirDrop, AWDL and Continuity features that need Apple Wi-Fi.
- An on-demand touchpad pulse (Force Touch feedback): the haptic module only fires on physical clicks.
- Camera (OV01A10 + Intel VSC + IPU6): no driver work started.
- Safari hardware video decode: needs the VA plugin in `/System/Library/Extensions` (a sealed-volume root patch,
  prepared but not applied).
- OpenGL: software renderer only (macOS Tahoe ships no Tiger Lake OpenGL driver). Experiment prepared in
  [OPENGL.md](OPENGL.md).
- Fingerprint: Synaptics `06cb:00f9` USB reader has no macOS driver (the upstream Goodix sudo trick does not apply).
- Camera (Chicony, Intel IPU6): no macOS driver.
- FairPlay / Apple Music with `-ngreengva`: hardware key exchange expects Tiger Lake ME; plays without the boot-arg.

## Differences from the upstream machine

This fork targets a real Tiger Lake CPU, so the hybrid-CPU work does not apply:

- No `ngreenpm` / XE-PM (hybrid-only; Tiger Lake uses stock XCPM).
- No `ngreenblmax` (upstream OLED backlight maximum; the Yoga's IPS panel uses the standard range).
- `ngreen-dmc=adlp` → `ngreen-dmc=tgl` (TGL DMC v2.12).
- `CpuTopologyRebuild` disabled (not a hybrid CPU).
- `CustomSMBIOSGuid = false` (upstream-specific quirk).
- `SSDT-EC` removed (the firmware EC is already named `EC` at the same path — battery works natively).
- `SSDT-XPS-I2C` and its renames removed (ThinkPad I2C0/I2C1 already have `_ADR`; touchpad ELAN0674 on I2C0 pin
  0x15, Wacom WACF2208 touchscreen on I2C1 pin 0x0A, both at `\_SB.GPI0` — same path as upstream, so `SSDT-GPI0`
  is unchanged).
- `HDAS → HDEF` rename + **AppleALC 1.9.8** added (ALC285 on HDA; upstream uses its own SOF/AudShim speaker stack).
- Audio candidates and a layout-id test replace the upstream AudShim bring-up.
- `xe-temp` may need SMCProcessor instead of XE-PM's `debug.xepm.sensors`.

## iServices

iMessage/FaceTime/iCloud readiness depends on your own SMBIOS: generate your own with `make-efi.sh` and never reuse
someone else's. en0 should be the built-in Wi-Fi port. `amfi_get_out_of_my_way=1` can still affect camera/mic
permission prompts.

## Provenance

The GPU-stack knowledge in this repository (patch catalogs, experiment logs, Metal notes) was developed on the
upstream project's hardware and applies unchanged to this machine's GPU. See [HISTORY.md](HISTORY.md) and
[EXPERIMENTS.md](EXPERIMENTS.md) for the full record; upstream git history is available in the source repository.