# Installation guide

> Target: **Lenovo ThinkPad X13 Yoga Gen 2** (i5-1135G7, Tiger Lake-LP, Iris Xe `8086:9A49`), **macOS Tahoe 26.7.1 (25G241)**.
> This fork has not yet been tested on hardware — treat the steps as the bring-up plan and report what actually happens.
> The short path is `zsh make-efi.sh` (EFI with your own serials) and, after installing macOS,
> `zsh install.sh`. This guide is the manual procedure behind those scripts.

## 0. What you need

- A USB drive (16 GB+) for OpenCore and the installer, or a second disk (dual-boot with Linux).
- Another Mac (or the laptop itself, from Windows/Linux) to create the installer.
- The `sle_Internal/le` and `sle_Internal/sle` folders of [NootedGreen](https://github.com/sgiammori/NootedGreen)
  (Apple's 16.0.32 Tiger Lake driver bundles) at commit `95f81898be65cb9f7b3d370ca78054be4cc8a62d`. `install.sh`
  clones it into `build/deps/NootedGreen` by itself. Keep this repository and NootedGreen on an APFS/HFS disk, not on
  FAT/exFAT (see step 5).

## 1. BIOS (ThinkPad Setup)

- **Secure Boot**: off
- **UEFI-only boot** (CSM off)
- **Sleep State** (Config → Power): set to **"Linux"** (S3). The default "Windows" is Modern Standby, which macOS
  cannot use. Sleep itself is experimental in this project (see [STATUS](STATUS.md)); this just makes S3 possible to test.
- **VT-d**: leave on (the config keeps `DisableIoMapper=false`)
- **Hyper-Threading / SpeedStep**: on. CFG Lock: leave as-is — `AppleXcpmCfgLock=true` covers a locked MSR 0xE2 either way.
- "OS Optimization / Other OS": set to **Other OS** if your BIOS has it.
- Storage in AHCI/NVMe mode, not RAID/VMD.

Change one setting at a time and keep a way to boot back.

## 2. EFI

1. Copy `EFI/` from this repository.
2. Generate an SMBIOS for **MacBookPro16,2** (e.g. with GenSMBIOS) and fill `PlatformInfo > Generic`
   (SystemSerialNumber, MLB, SystemUUID, ROM) in **both** `config.plist` and `config-install.plist`.
   On Linux: download the OpenCore release pinned in `make-efi.sh`, run `macserial.linux -m MacBookPro16,2 -g -n 1`,
   and fill the fields with any plist editor (keep them empty in git).
3. `HfsPlus.efi` is bundled in `EFI/OC/Drivers` (from acidanthera/OcBinaryData, the EFI driver used for HFS+ installer
   media and gibMacOS/OC recovery boots) and enabled in both configs. Update it only if OpenCore asks for a newer one.
4. USB ports are mapped generically (`UTBDefault.kext`); build a real map later with USBToolBox's Windows tool or macOS USBMap,
   then drop `UTBDefault.kext`.
5. Input devices run on GPIO/APIC interrupts through VoodooI2C + `SSDT-XOSI` (the firmware's own `_CRS` returns I2C +
   GpioInt resources once it believes it runs Windows). Rebuild VoodooGPIO with `zsh build-voodoogpio.sh` so it has
   Tiger Lake-LP support.

## 3. Install macOS (dual-boot with Linux)

1. Make a Tahoe 26.7.1 installer: `softwareupdate --fetch-full-installer --full-installer-version 26.7.1`, or
   download `InstallAssistant.pkg` with gibMacOS, then use `createinstallmedia`.
2. Boot OpenCore with **`config-install.plist` renamed to `config.plist`**. It disables NootedGreen and boots verbose.
   The installer runs on the firmware framebuffer, without acceleration.
3. Install to the second disk/partition, finish Setup Assistant, then install the Command Line Tools: `xcode-select --install`.
4. Keep the USB installer bootable — it is your rollback.

## 4. Kernel side

```sh
zsh build-nootedgreen.sh                 # -> build/NootedGreen.kext
zsh build-hookcase.sh                    # -> build/HookCase.kext (installed by step 5)
```

`HookCase.kext` is required: Apple's TGL kexts link against `org.smichaud.HookCase`, and without it kmutil refuses
to register them. It goes to `/Library/Extensions` (step 5), not to the EFI.

Put `build/NootedGreen.kext` in `EFI/OC/Kexts/` and switch back to the accelerated `config.plist` (keep the boot-args
from the repository).

**Own config.plist or reused NVRAM:** OpenCore only writes `NVRAM > Add > boot-args` if the variable is also listed
under `NVRAM > Delete` for the same GUID (`7C436110-AB2A-4BBB-A880-FE41995C9F82`); otherwise the OpenCore log shows
`ignored, exists` and the old boot-args stay. The repository's configs already list it. Without it the Xe boot-args
are missing and the boot stops right after the accelerator starts (`didn't find dpmicro`, no panic).

## 5. User-space side

Keep the repository and the NootedGreen download on an APFS disk (your home folder), not on a FAT/exFAT USB
stick: macOS stores metadata there in `._` files, which break the bundle copies and code signing.

```sh
git clone https://github.com/sgiammori/NootedGreen.git ~/NootedGreen
git -C ~/NootedGreen checkout 95f81898be65cb9f7b3d370ca78054be4cc8a62d
zsh macos/build-all.sh ~/NootedGreen/sle_Internal/sle
sudo zsh macos/install-macos.sh ~/NootedGreen/sle_Internal/sle ~/NootedGreen/sle_Internal/le
```

`zsh install.sh --build-only` does the clone, checkout and builds automatically (into `build/deps/NootedGreen`).

Approve the extension in **System Settings › Privacy & Security** if asked, and reboot.

## 6. After the first accelerated boot

- Build the two command-line tools into `tools/build/`:
  ```sh
  mkdir -p tools/build
  clang -O2 -o tools/build/xe-res tools/xe-res.c -framework CoreGraphics -framework CoreFoundation
  clang -O2 -fobjc-arc -DXECTL_NO_MAIN -o tools/build/xe-brilho tools/xe-brilho.m tools/xectl.c -framework AppKit -framework IOKit
  ```
- Brightness: build `tools/XeShim` (`zsh tools/build-kext.sh XeShim`), load it, then `tools/build/xe-brilho 70`.
  The sun keys may need `xe-brilho daemon` (see STATUS).
- Touchscreen trail (optional): `zsh tools/build-xe-toque.sh`, then `open tools/xe-toque.app` and allow it in
  Privacy & Security › Input Monitoring. Only touches on the screen draw; the trackpad is ignored.
- Check: `system_profiler SPDisplaysDataType` shows **Metal Support** and the chipset model you set.
- Wi-Fi, lid/sleep setup and CPU temperatures: see the sections below.

## 7. Moving OpenCore to the internal disk

1. `sudo diskutil mount disk0s1` (check the identifier with `diskutil list`) and copy `EFI/`.
2. In the ThinkPad BIOS (F1) › Boot: **Add Boot Option** → the internal disk →
   `\EFI\BOOT\BOOTx64.efi`, and move it to the top.

## Updating an existing install

Fixes land in the repository as they are confirmed (see [CHANGELOG.md](../CHANGELOG.md)). To update a working setup:

1. **Back up the EFI you boot from** (copy the whole `EFI` folder somewhere, or keep a second bootable USB EFI), so a
   kext that does not boot can be undone.
2. Update and rebuild, from your clone (on an APFS disk):
   ```sh
   cd ~/your-clone
   git pull
   zsh install.sh                # rebuilds and reinstalls NootedGreen, the Metal driver, libxedrv and the shader compiler
   ```
   This replaces the user-space files in `/Library/GPUBundles` and `/Library/Extensions` (they take effect for apps
   started afterwards, and for WindowServer after the reboot).
   If you update by hand instead, rebuild the Metal bundle with `zsh macos/build-all.sh <sle/>` (it builds libxedrv
   and runs `patch-mtl17.py`) and reinstall it with `sudo zsh macos/install-macos.sh <sle/> <le/>` (step 5). A
   `git pull` alone changes nothing on the system.
3. Copy the new `build/NootedGreen.kext` over `EFI/OC/Kexts/NootedGreen.kext` on the EFI you boot from. Only
   compare `config.plist` with the repository's if the CHANGELOG entry says boot-args or kexts changed; keep your
   own serials. Do not run `make-efi.sh` again: it generates new SMBIOS serials (iCloud/iMessage sign-out).
4. Reboot, then check that the new kext is loaded: `kmutil showloaded | grep NootedGreen` and
   `system_profiler SPDisplaysDataType | grep Metal`.
5. Optional parts are updated separately with their own scripts: fingerprint (not supported on this machine), etc.

If the new kext does not boot, boot the backup EFI and put the old `NootedGreen.kext` back. A single fix can also be
turned off with its boot-arg (listed in the CHANGELOG entry and in [KERNEL-PATCHES.md](KERNEL-PATCHES.md)).

## Recovery

- `config-install.plist` (NootedGreen off) is only safe **before** the TGL files are installed, or after
  `zsh install.sh --uninstall`. It still spoofs the GPU as 9A49, and once `install-macos.sh` has set the TGL
  accelerator's `IOPCIPrimaryMatch` to `0x9a498086`, Apple's stock TGL driver binds 9A49 without NootedGreen's patches
  and panics or stalls (stock 16.0.32 only accepts 9A40/9A48). For an unaccelerated fallback after installing, also
  remove the `device-id` / `AAPL,ig-platform-id` spoof from that config, or uninstall first.
- Each patch can be turned off with its boot-arg ([KERNEL-PATCHES.md](KERNEL-PATCHES.md)).
- Remove the user-space pieces: delete `/Library/GPUBundles/AppleIntelTGL*`, `/System/Library/Caches/xe.bundle`
  and the TGL kexts in `/Library/Extensions`, then run `sudo kmutil load -z` again.

## Audio (AppleALC)

This machine uses the standard HDA path, not the upstream SOF/AudShim stack. `AppleALC.kext` is already in
`EFI/OC/Kexts/` and the `HDAS → HDEF` rename is in the ACPI config.

Add `alcid=NN` to the boot-args and reboot, trying these candidates in order:
**17, 99, 11, 21, 29, 66, 14, 15** (11 is the documented X1 Carbon 6 layout; 17/99 are common ThinkPad ALC285 picks).
Pass criteria: speakers + headphone + internal mic. HDMI audio comes along with the GPU
(`hda-gfx=onboard-1` is already set).

## Wi-Fi (AirportItlwm)

The shipped `config.plist` loads **AirportItlwm-Tahoe 2.4.0-alpha** (laobamac fork of itlwm, commit 738d4c6) and keeps
`itlwm.kext` disabled. AirportItlwm uses Tahoe's own IO80211Family/IOSkywalkFamily, so no root patch is needed, and Wi-Fi
appears in the menu bar like on a Mac (HeliPort is not needed; remove its login item if you had one).
- `MinKernel 25.0.0` / `MaxKernel 25.99.99`: it only loads on Tahoe. Never enable `itlwm.kext` and `AirportItlwm.kext`
  together (the boot halts).
- After the switch macOS may keep an old "Ethernet" service for en0: System Settings › Network › remove it, then "+" →
  Wi-Fi. en0 should be the Wi-Fi port (iMessage/FaceTime expect a built-in en0).
- Optional: boot-arg `itlwm_he=1` turns on Wi-Fi 6 (HE) rates.
- Fallback: `config-install.plist` still uses itlwm (connect with HeliPort). Switch back the same way if a macOS update
  breaks AirportItlwm.
- Not available with this driver: AirDrop/AWDL, WPA3-only networks.

## Hardware video decode (optional)

H.264 and HEVC decode on the GPU for VideoToolbox clients (QuickTime, Photos, video editors). It needs the boot-arg
**`-ngreengva`** and the patched VA plugin, which is not part of `install.sh` and is installed by hand:

```sh
zsh macos/vadriver/build-vadriver.sh ~/NootedGreen/sle_Internal/sle      # -> macos/out/AppleIntelTGLGraphicsVADriver.bundle (no sudo)
sudo rm -rf /Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle
sudo ditto macos/out/AppleIntelTGLGraphicsVADriver.bundle /Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle
killall VTDecoderXPCService     # apps that already opened a decoder need a restart
```

(With `install.sh` the `sle/` folder is `build/deps/NootedGreen/sle_Internal/sle`.) Add `-ngreengva` to the boot-args
and reboot. Without the boot-arg the plugin is not used and decode stays in software.

- **FairPlay does not play with `-ngreengva`**: Apple Music (and probably Apple TV+) fails, the VA plugin logs "ME not
  loaded". Remove the boot-arg if you need that content.
- Safari still decodes on the CPU: its WebKit GPU process may not load plugins from `/Library/GPUBundles`.
- Undo: remove `-ngreengva` and delete `/Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle`.

## Sleep, lid and display sleep

This laptop's firmware is Modern Standby; system sleep is experimental in this project. For now use:

```sh
sudo zsh tools/sleep/10-pmset-safe.sh     # sleep 0, disablesleep 1, hibernatemode 0, display sleep 3 min battery / 10 min AC
zsh tools/sleep/install-xe-lid.sh         # LaunchAgent: lid close -> display off, lid open -> display on (log /tmp/xe-lid.log)
```

The machine stays awake (a few watts) with the lid closed: shut it down for long breaks, and consider
`sudo pmset -b lowpowermode 1` on battery. Undo: `sudo zsh tools/sleep/90-pmset-revert.sh` and
`zsh tools/sleep/install-xe-lid.sh --remove`. On boots where the EC does not report the lid, turn the display
off by hand.

Keep the default display sleep (NootedGreen XE-FBDPMS, backlight off only): with `-ngreenfbdpms` the panel is really
powered down and does not come back on wake (eDP link not retrained).

## Touchpad vibration

The haptic touchpad clicks by itself; macOS can only change how strong the vibration is (HID feature report 0x09,
0–100). On this machine the touchpad is an ELAN0674 clickpad — haptic support is unverified. If it has a haptic motor:
`clang -O2 -o tools/build/xe-haptic tools/xe-haptic.c -framework IOKit -framework CoreFoundation`, then
`xe-haptic list` (read-only dump) or `xe-haptic set 60 100`. The value is lost at reboot. For a persistent setting,
`zsh tools/build-xe-hapticbar.sh` and `open tools/xe-hapticbar.app` (add it to Login Items): a hand icon in the menu bar
with a slider, applied at login and on every change.

## CPU temperatures (xe-temp)

macOS shows no CPU temperature on this machine (SMCProcessor finds nothing). NootedGreen exposes the sensors as
`sysctl debug.xepm.sensors` on every boot, and `tools/xe-temp` shows them: the package temperature in the menu bar and,
in its panel, a 3-minute graph, package/CPU/GPU watts, every P-core and E-core and the battery. No root needed:

```sh
zsh tools/xe-temp/build.sh && cp -R tools/build/xe-temp.app ~/Applications/
open ~/Applications/xe-temp.app
```

Add it in System Settings › General › Login Items to start it at login. On this machine the sensors may instead need
SMCProcessor — report what `sysctl debug.xepm.sensors` returns.

## Fingerprint

The ThinkPad's Synaptics `06cb:00f9` USB fingerprint reader has no macOS driver; the upstream Goodix sudo trick does not
apply. No fingerprint support on this machine.

## Power button locks the screen (optional)

`sh tools/xe-pblock/install.sh` builds `xe-pblock.app`, copies it to `~/Library/Application Support/xe/`, runs two
15-second checks and loads the user LaunchAgent `local.xe.pblock`. Allow **xe-pblock** in Privacy & Security › Input Monitoring when asked. A short
press then locks the screen at once (the same call as Apple menu › Lock Screen); with the screen already locked it does
nothing. No `pmset` change is needed. `sh tools/xe-pblock/probe.sh` shows the events live without locking. Log: `~/Library/Logs/xe-pblock.log`. Undo: `sh tools/xe-pblock/uninstall.sh`
(`--reset-tcc` also removes the permission). Untested on this machine.

## Touchscreen extras (xe-toque)

`zsh tools/build-xe-toque.sh`, copy `tools/xe-toque.app` wherever you keep it (e.g. `~/xe/toque/`), open it and add it
to Login Items. Allow it in Privacy & Security › **Input Monitoring** and › **Accessibility** (Screen Recording only
for the magnifier). The build signs it with a requirement on its bundle id, so later rebuilds keep the grants.
A hand icon in the menu bar holds the toggles (saved in `defaults read local.xe.toque`):

- **One-finger scroll**: drag scrolls with momentum, tap clicks (double-tap works), hold 0.5 s = right click,
  hold then drag = left drag/selection. VoodooI2C's own pointer events for the touch are filtered out (CGEvent field 87 =
  sender registry ID of the touchscreen driver); the trackpad and mouse are never filtered.
- **Window buttons magnet** (on by default): a tap within 36 pt of a window's close / minimize / zoom button, inside the
  window's top 60 pt, presses the nearest of those buttons. With One-finger scroll off, a touch that lands near the
  buttons is held back from macOS and decided on release (a drag there is replayed as a normal drag). It
  (Accessibility AXPress, falling back to a click at its centre) and flashes a blue ring on it. Not applied to taps that
  land on another control (toolbar button, tab, text field…), to full-screen windows, or to the trackpad/mouse. Each
  redirect is logged (`magnet: tap … -> close of …`). Check a point without clicking:
  `xe-toque.app/Contents/MacOS/xe-toque --test-magnet X Y` (global points, top-left origin).
- **Edge swipes**: in from the right edge = Notification Center (presses the menu-bar clock via Accessibility),
  up from the bottom edge = Mission Control.
- Two- and three-finger gestures on the screen already reach macOS as trackpad gestures (VoodooI2C feeds them to an
  emulated Magic Trackpad), so they follow System Settings › Trackpad (four and five fingers are xe-toque's, see below). With **xe-toque handles 2–5 fingers** on,
  xe-toque replaces them: 2 = scroll, 3 sideways = switch Space (ctrl+←/→), 5-finger pinch = Apps.
- **Trail** / **Ripple** visual feedback, **Magnifier** (two-finger hold), **Pen mode** (draw on screen; Esc exits,
  *Clear drawing* wipes it), **Touch mode** (switches to a 1152-pt-wide HiDPI mode with `xe-res` and back
  to the previous mode). It uses `build/xe-res` next to the app (`tools/build/xe-res`, see step 6); if you moved the app,
  point it at the tool with `defaults write local.xe.toque xeRes /path/to/xe-res`.
- **Lasso selection in Finder** (on by default): a one-finger drag that starts on empty space of the desktop or a Finder
  window (icon or list view) draws a free-form lasso instead of the rectangle; on release the icons/rows inside it are
  selected (Accessibility `AXSelectedChildren` / `AXSelectedRows`).
- **Pinch out on a Finder file** (on by default): two fingers on a file, spread = Quick Look, pinch back in = close it.
  Two fingers that move together still scroll.
- **Four fingers on a window** (on by default): move it, spread/pinch to resize it (Accessibility position/size, ~40
  updates per second). Four-finger touches are held back from macOS while you do it, so macOS's own four-finger Show
  Desktop no longer fires. Option: let windows go past the screen edges (on) or keep them on screen.
- **Five fingers**: spread = Show Desktop, pinch = Apps. **Five-finger double tap = tile mode on/off**: the visible
  windows of the built-in screen are kept in a grid (1 full, 2 halves, 3 = one tall + two, 4 quarters, then columns ×
  rows, up to 12) inside the area between the menu bar and the Dock. New windows join, closed/minimized ones leave,
  resizing one moves the shared edge so the neighbours follow, and dropping a window dragged by its title bar onto
  another cell swaps them. A dock that replaces the macOS one (the real Dock hidden) is respected if it publishes its
  frame: distributed notification `local.xe.dock.frame` {x, y, w, h, hidden} and preferences domain `local.xe.dock`,
  key `frame` (Cocoa coordinates); windows then stop 14 pt above it, so their shadows don't fall behind it.
- **Dragging with the desktop shown** (on by default): when Show Desktop is active (windows pushed to the edges), a
  one-finger drag is taken over by xe-toque, and a second finger brings the windows back without dropping what you
  carry, so you can drop a desktop file into a window.
- **Hide the pointer while touching** (on by default): a touch on the screen hides the pointer; the first trackpad or
  mouse move, click, drag or scroll shows it again.
- Log: `~/Library/Logs/xe-toque/xe-toque.log`. Diagnostic: `xe-toque.app/Contents/MacOS/xe-toque --probe-events`.

## Vulkan (MoltenVK, optional)

Vulkan runs on top of the accelerated Metal driver through **MoltenVK** (Khronos/LunarG). Install the official
[Vulkan SDK for macOS](https://vulkan.lunarg.com/sdk/home#mac) (notarized by LunarG; the core component is enough and
it can live in your home folder, e.g. `~/VulkanSDK/<version>`, no sudo). Then:

```sh
source ~/VulkanSDK/<version>/setup-env.sh
export VK_DRIVER_FILES=$VULKAN_SDK/share/vulkan/icd.d/MoltenVK_icd.json   # skip the arm64-only KosmicKrisp ICD
vulkaninfo --summary            # GPU0: Intel(R) TGL, 0x9a49, driverName MoltenVK, Vulkan 1.4
open ~/VulkanSDK/<version>/Applications/vkcube.app
```

Apps and games that bundle MoltenVK need nothing else. There is no geometry shader and no 64-bit float in shaders
(Metal has neither). OpenGL stays software-only (see the README); OpenGL over Vulkan (Mesa Zink) would need a Mesa
build and a window bridge and has not been done.

## OpenGL

OpenGL is software-only on this stack (macOS Tahoe ships no Tiger Lake OpenGL driver). An experiment to activate
Apple's own dormant TGL OpenGL driver — which `install-macos.sh` already installs into `/Library/Extensions` — is
prepared in [OPENGL.md](OPENGL.md), with a ready-to-run read-only probe (`macos/gl-probe.sh` + `macos/cgl-probe.c`).