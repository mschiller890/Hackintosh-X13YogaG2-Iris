# macOS on the ThinkPad X13 Yoga Gen 2

OpenCore EFI and experimental Intel Iris Xe graphics support for the Lenovo ThinkPad X13 Yoga Gen 2 (20W8), with an Intel Core i5-1135G7 and Iris Xe (8086:9A49).

**Start with Sequoia online Recovery.** It reached Recovery on this ThinkPad using the EFI backed up from the Kingston installer. Wi-Fi was unavailable on the first boot. A Sequoia-specific driver was added to the test USB and still needs a hardware retest.

The repository also carries a separate Tahoe graphics stack targeting **26.7.1 (25G241)**. The Tahoe online USB repeatedly stopped at `EXITBS:START`. Treat Tahoe acceleration, WhateverXe on Sequoia, and the Tiger Lake VoodooGPIO patch as experiments on this machine.

## Guides

- [Install macOS](docs/INSTALL.md) for Sequoia Recovery, USB preparation, and the Tahoe graphics setup.
- [Hardware status](docs/STATUS.md) for observed results and open tests.
- [Troubleshooting](docs/DEBUGGING.md) for boot, Wi-Fi, input, and graphics logs.
- [Changelog](CHANGELOG.md) for changes and earlier boot experiments.
- [Graphics internals](docs/METAL.md), [kernel patches](docs/KERNEL-PATCHES.md), and [tool catalog](docs/CATALOG.md) for development.

## Repository layout

| Path | Contents |
|---|---|
| `EFI/` | OpenCore templates and bundled drivers. Personalize the SMBIOS before use. |
| `src/NootedGreen/` and `src/HookCase/` | Kernel components for the Tahoe graphics stack. |
| `macos/` | Tahoe Metal driver adapter, shader compiler, and install scripts. |
| `tools/` | Graphics diagnostics and optional utilities. |

The boot-tested Kingston EFI backup is machine-local under `dist/online-recovery/`. The repo includes a sanitized Sequoia template at `EFI/OC/config-sequoia.plist`, based on that EFI with the Sequoia Wi-Fi driver added. Keep generated EFI backups private because they may contain SMBIOS identifiers.

## Credits and license

The Tahoe graphics work comes from [JulioNectar’s XPS 13 Plus project](https://github.com/JulioNectar/Hackintosh-XPS13Plus-IrisXe-Tahoe) and [NootedGreen](https://github.com/sgiammori/NootedGreen). See [NOTICE](NOTICE.md) for component attribution and [LICENSE](LICENSE) for the fork’s license.
