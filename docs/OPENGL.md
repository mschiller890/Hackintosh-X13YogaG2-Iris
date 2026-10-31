# OpenGL activation experiment: Apple's Tiger Lake GLDriver

**Status: prepared, not yet started** (needs a running macOS install). Goal: accelerated OpenGL on
this stack by activating the Tiger Lake OpenGL driver Apple shipped — currently installed but inert.
Context and the original failure: [#21](https://github.com/JulioNectar/Hackintosh-XPS13Plus-IrisXe-Tahoe/issues/21).

## What exists today

| Piece | State |
|---|---|
| Metal (MTL17) driver | ✅ patched (`macos/patch-mtl17.py`) + libxedrv, works |
| VA decoder (`VADriver`) | ✅ activated by `macos/vadriver/build-vadriver.sh` + `-ngreengva` |
| Shader compiler (`xe.bundle`) | ✅ built/redirected by `build-shader-compiler.sh` (`plugin-old-patches.json` rewrites its resource paths — the exact technique a GL driver may need too) |
| **OpenGL (`AppleIntelTGLGraphicsGLDriver.bundle`)** | ⚠️ **installed by `macos/install-macos.sh` line 24–26 into `/Library/Extensions`, then never touched**: not patched, not wired to CGL, not in any build step. CGL falls back to the Apple Software Renderer (#21: `CGLChoosePixelFormat(accelerated, 3.2 core) → 0 formats`, GLFW "Failed to find a suitable pixel format"). |

The GL driver comes from the **same Apple GPUDriversIntel 16.0.32 package** as the Metal driver —
written by Apple for unreleased Tiger Lake Macs, i.e. for exactly this GPU (`0x9A49`). Unlike the
ICL/KBL GL drivers that Tahoe ships in the system set, this one needs no cross-generation hardware
port; the problem is expected to be *wiring*, not *hardware correctness*.

Precedent: the VA driver sat in the same package and took the same journey (installed → patched →
activated with a boot-arg → works). Nobody has tried it for GL yet.

## Hypotheses (why CGL ignores it)

- **H1 — identity mismatch.** The accelerator kexts run under *renamed* bundle IDs
  (`com.xxxxx.driver.AppleIntelTGLGraphics`, see `install-macos.sh` line 5 and `kextG11FBT` in
  `kern_gen11.cpp`). If OpenGL derives/looks up the GL bundle from the accelerator's identity, the
  rename breaks the match, or a property the accelerator should advertise (`IOGLBundle*`-style) is
  missing because Apple's prototype glue lived outside what we ship.
- **H2 — search path.** CGL may only scan the system GPU bundle locations; ours is in
  `/Library/Extensions`. (Writable firmlink precedent: `/System/Library/Caches/xe.bundle`.)
- **H3 — interface drift.** GLDriver 16.0.32 vs Tahoe's CGL needs compat patches — the "GL17"
  equivalent of `patch-mtl17.py`, plus device/GUChip checks of its own.

## Phases

### P1 — discovery (read-only, one session)

On the installed macOS, from this repo:

```sh
zsh macos/gl-probe.sh        # writes gl-probe-report.txt; paste the result back
```

It gathers: kext state, every `*GLDriver*` bundle and its matching personalities, whether the
accelerator service advertises a GL-bundle property, **the selection strings inside
`OpenGL.framework` itself** (they reveal the lookup rule and path), and the `cgl-probe` baseline
(the #21 repro: accelerated / legacy-accelerated / software pixel format counts, renderer strings,
and which dylibs CGL loads during context creation).

Decision after P1:

- If a `DYLD_PRINT_LIBRARIES` line shows `AppleIntelTGLGraphicsGLDriver` *loading* but failing →
  straight to **P3** (Tahoe compat patches; the load failure text is the patch target).
- If it never loads → **P2**.
- If OpenGL.framework strings show a hard-coded system path → H2; plan a firmlink/move.

### P2 — wire-up

Make CGL find the bundle, smallest intervention first:

1. Re-check the accelerator's Info.plist personalities (`/Library/Extensions/AppleIntelTGLGraphics.kext`)
   for any GL-related key Apple's stock personality had that ours doesn't (compare against the
   unmodified 16.0.32 copy in NootedGreen's `sle_Internal/le`).
2. Add the missing personality/property (Info.plist edit on our copy — same layer where
   `IOPCIPrimaryMatch` is already patched to `0x9a498086`).
3. If the lookup runs from the kernel side: add an `IOGLBundle*` property injection in NootedGreen
   (it already patches the TGL kexts in memory — this is one more property write).

### P3 — patch GLDriver like the MTL driver

New `macos/patch-gl.py` + `macos/gl-patches.json`, same discipline as `patch-mtl17.py`:
byte-verified edits against the stock 16.0.32 binary, install to `/Library/Extensions`, rerun
`cgl-probe`. Include the `plugin-old-patches.json`-style path redirect if the GL driver references
shader-compiler resources that live elsewhere on Tahoe. Iterate on the CGL error / load failure
text from P1 — it names the failing check.

### P4 — validation

| Milestone | Test |
|---|---|
| 1 | `cgl-probe` exit 0: accelerated 3.2 core format available, context creates |
| 2 | Renderer string names the GPU (not "Apple Software Renderer"), sane limits (texture units ≠ 0) |
| 3 | GLView (as in #21) reports non-empty `PixelFormats` and real VRAM/clock |
| 4 | GLFW app runs: Prism Launcher + Minecraft through the OpenGL backend |
| 5 | Stability: a shader-heavy app for 30 min (GPU hangs/KP watch — same risk profile as the rest of this stack) |

## Fallbacks (if activation dead-ends)

1. **Zink bridge** — Mesa GL over Vulkan → MoltenVK → the accelerated Metal driver (Vulkan is
   *confirmed working*, #21). Needs a native Mesa build plus an NSGL window bridge
   (PojavLauncher-style). Heavy, but every layer under it is proven.
2. **Accelerated-bit spoof** — patch CGL to satisfy accelerated pixel-format requests with the
   software renderer: Minecraft/GLFW *launch* instead of erroring, still slow. Possible through the
   existing DYLDPatches/libxedrv interposition infra.
3. **Minecraft on Vulkan** — #21 notes MC 26.2's Vulkan backend crashes on this stack; debugging
   that crash is a parallel path that needs no GL at all.

## Notes

- Runs on **this machine** (ThinkPad X13 Yoga Gen 2, native Tiger Lake `8086:9A49`) — same GPU and the same driver
  package as the upstream reference machine, so this experiment carries over unchanged.
- Keep `cgl-probe` exit codes as the regression metric across attempts (0/1/2).
- Do not install GL patches system-wide before `cgl-probe` passes them on a copy.
