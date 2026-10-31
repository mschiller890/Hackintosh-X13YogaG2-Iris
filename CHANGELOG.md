# Changelog

This changelog covers **this fork** (Lenovo ThinkPad X13 Yoga Gen 2). Status values:
**confirmed** (works on hardware), **testing** (built and installed, being evaluated), **reverted**, **superseded**
(replaced by a later entry).

The full history of the GPU stack this fork is built on lives in the upstream project's git history and in this
repository's [docs/HISTORY.md](docs/HISTORY.md) (how it was done, phase by phase) and [docs/EXPERIMENTS.md](docs/EXPERIMENTS.md)
(what failed and why). The patch-level reference is [docs/CATALOG.md](docs/CATALOG.md); what works and known problems
are in [docs/STATUS.md](docs/STATUS.md).

## Unreleased

| Date | Change | Status |
|---|---|---|
| 2026-10-31 | **Branch `x13-yoga-gen2`: initial port to the Lenovo ThinkPad X13 Yoga Gen 2** (i5-1135G7, *native* TGL `8086:9A49`, 1920×1200 IPS touch, ALC285, AX201, ELAN0674 touchpad + Wacom touchscreen/pen). Real Tiger Lake means no `9A49` spoof and no hybrid-CPU work: `ngreenpm` and `ngreenblmax` dropped, `ngreen-dmc=adlp`→`tgl`, `CpuTopologyRebuild` and upstream-specific quirks off. ACPI: `SSDT-EC` removed (the firmware EC is already named `EC` at the same path — battery works natively), `SSDT-XPS-I2C` and its renames removed (ThinkPad I2C0/I2C1 already have `_ADR` and TPD0/TPL1 return GpioInt resources under the XOSI Windows spoof; touchpad ELAN0674 on I2C0 pin 0x15, Wacom WACF2208 touchscreen on I2C1 pin 0x0A, both at `\_SB.GPI0` — same path as upstream, `SSDT-GPI0` unchanged), `HDAS→HDEF` rename + **AppleALC 1.9.8** added (audio needs an `alcid=` layout test, candidates in the doc). BIOS, install and bring-up checklist: [README](README.md) and [docs/INSTALL.md](docs/INSTALL.md) | testing (not yet booted on hardware) |
| 2026-10-31 | **OpenGL activation experiment prepared** ([docs/OPENGL.md](docs/OPENGL.md)): `install-macos.sh` has been installing Apple's unreleased **TGL OpenGL driver** (`AppleIntelTGLGraphicsGLDriver.bundle`, same 16.0.32 package as the working Metal driver) into `/Library/Extensions` all along — nothing patches or wires it, so CGL falls back to the Apple Software Renderer (#21). The plan: P1 discovery → P2 wire-up (identity/`IOGLBundle*` property; suspect the `com.xxxxx` bundle-ID rename) → P3 Tahoe compat patches (`patch-gl.py`, same discipline as `patch-mtl17.py`) → P4 validation (`cgl-probe` exit 0 → GLView → GLFW/Minecraft). New read-only diagnostics: **`macos/gl-probe.sh`** (bundle/personality dump, accelerator properties, `OpenGL.framework` selection strings, DYLD load trace) and **`macos/cgl-probe.c`** (accelerated/legacy/software pixel-format matrix + renderer strings, exit 0/1/2 as regression metric). Fallbacks documented: Zink bridge over the confirmed MoltenVK path, accelerated-bit spoof for launchability, MC's Vulkan backend crash as a parallel route. Runs on this machine (same GPU and driver package as the upstream reference) | testing (probe ready, not yet run on hardware) |

## Before this fork

This fork's first commit is based on the upstream snapshot at `6f03560` (xe-toque tile mode). The entire GPU acceleration
stack — NootedGreen kernel patches, the MTL17 Metal driver, `libxedrv`, the shader compiler, the VA plugin, the
user-space tools — was developed there. Every entry dated 2026-10-20 through 2026-10-27 in the upstream project's
changelog applies to this fork unchanged (they are GPU-stack fixes, not laptop-specific), and the provenance of each is
preserved in [docs/HISTORY.md](docs/HISTORY.md) and [docs/EXPERIMENTS.md](docs/EXPERIMENTS.md). The upstream repository
is [JulioNectar/Hackintosh-XPS13Plus-IrisXe-Tahoe](https://github.com/JulioNectar/Hackintosh-XPS13Plus-IrisXe-Tahoe);
its git history is the authoritative source for those entries. Issues and PRs cited in the docs (e.g. #21, #3, #16)
point there.