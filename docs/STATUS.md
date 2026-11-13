# Hardware status

Results are for the ThinkPad X13 Yoga Gen 2 (20W8), i5-1135G7, Iris Xe 8086:9A49.

| Area | Result |
|---|---|
| Sequoia online Recovery | Reached Recovery from the Toshiba using the Kingston EFI baseline. A complete installation is still unverified. |
| Sequoia Wi-Fi (Intel AX201) | Unavailable on the first boot with a Tahoe-only driver. The Sequoia AirportItlwm build was added to the test USB and still needs a retest. |
| Tahoe online Recovery | Repeatedly stopped at `EXITBS:START`, including after successful kernel prelinking. |
| Kingston offline installer | Booted into the installer, which reported that its installer was damaged. |
| Trackpad (ELAN0674) | User confirmed working in Tahoe Recovery after adding the Tiger Lake-LP I2C PCI match (A0E8–A0EB) to VoodooI2C. Polling is enabled on PCI 00:15.0. Gestures and installed-system operation still need testing. |
| Touchscreen (WACF2208) | Still unverified after the trackpad fix. The Tiger Lake VoodooGPIO source patch remains unverified in the deployed binary. |
| Onboard audio (Realtek ALC285) | Reported inoperative on Tahoe. AppleALC needs an AppleHDA restoration path on Tahoe. Codec routing still needs testing. |
| Graphics | Tahoe NootedGreen and Sequoia WhateverXe acceleration remain unverified on this machine. |
| Sleep, external displays, camera, fingerprint, Bluetooth | No confirmed results in this test run. |

See the [installation guide](INSTALL.md) for the USB workflow and [changelog](../CHANGELOG.md) for earlier experiments.
