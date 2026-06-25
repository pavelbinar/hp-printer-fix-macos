# HP Printer Fix for macOS

Install legacy HP printer drivers on macOS Sequoia, Tahoe and later.

This project started as a package-version-check bypass. Modern macOS versions need one extra step: the old HP package also tries to install files under protected `/System` paths, so the full package installer can fail even after the version check is patched. The command-line script now installs the usable CUPS driver files directly into `/Library/Printers`, fixes their permissions, and patches the HP P1100-series PPD so it does not force manual feed.

## Supported Printer Models

The `HewlettPackardPrinterDrivers.pkg` package contains drivers for many HP models. This fix has been confirmed to work with:

- HP LaserJet P1102 / Pro P1102 / Pro P1102w
- HP LaserJet P1108
- HP LaserJet Pro M1136
- HP LaserJet M12 / M12W / M13 series
- HP LaserJet P1007
- HP LaserJet 4000N

It should also work with other HP LaserJet and OfficeJet models included in the same Apple/HP driver package, but the automatic queue setup is currently specific to the HP LaserJet P1102 USB model.

## Download the HP Driver Package

Prefer Apple's download:

- [HP 5.1.1 Printer Software Update - Apple Support](https://support.apple.com/en-us/106385)
- Direct Apple DMG: `https://updates.cdn-apple.com/2021/macos/071-46903-20211101-0BD2764A-901C-41BA-9573-C17B8FDC4D90/HewlettPackardPrinterDrivers.dmg`

Apple marks the package as compatible with macOS 10.14 and not compatible with macOS 12 or newer. That warning is expected; this project works around the old installer limitations.

If Apple's download is unavailable in your browser, third-party mirrors such as [MacUpdate](https://apple-hp-printer-drivers.macupdate.com/) may host the same `HewlettPackardPrinterDrivers.dmg`, but prefer Apple when possible.

## Recommended Installation

1. Download the Apple HP driver `.dmg`.
2. Open the `.dmg`.
3. Copy `HewlettPackardPrinterDrivers.pkg` next to `install-driver.sh`.
4. Connect and power on the printer.
5. Run:

   ```bash
   chmod +x install-driver.sh
   ./install-driver.sh --setup-p1102
   ```

The script will:

- expand `HewlettPackardPrinterDrivers.pkg`
- install the compatible CUPS driver files into `/Library/Printers`
- skip protected `/System` package payload paths
- fix ownership/permissions so CUPS accepts the legacy filters
- patch P1100/P1560/P1600 PPDs to use automatic paper source instead of forced manual feed
- add/update a connected HP LaserJet P1102 USB queue as `HP_LaserJet_P1102`
- set A4 and the P1102 as the default printer

You may be prompted for an administrator password because `/Library/Printers` and CUPS queue setup are system-level changes.

## Other Script Modes

Install driver files without adding a printer queue:

```bash
./install-driver.sh
```

Build a patched package for older workflows:

```bash
./install-driver.sh --build-pkg --no-install
```

Use a custom queue name:

```bash
./install-driver.sh --setup-p1102 --printer-name My_HP_P1102
```

## Web Tool

The browser tool at [berot3.github.io/hp-printer-fix-macos](https://berot3.github.io/hp-printer-fix-macos/) can still patch the package version check without uploading files anywhere.

For macOS Big Sur and later, especially Tahoe, prefer the command-line script. A fixed full package can still fail because the original payload contains protected `/System` paths.

## Known Notes

- The old `HP LaserJet Professional Utility.app` may crash on modern macOS/Rosetta. Printing does not depend on that app.
- The HP filters are Intel `x86_64` binaries. On Apple Silicon Macs, Rosetta must be installed.
- CUPS may warn that printer drivers are deprecated. That is expected for legacy PPD/filter drivers.

## How It Works

For modern macOS, the script extracts the HP package payload and installs only the printer driver files that still belong under `/Library/Printers`. It avoids blocked `/System` payload entries, fixes file ownership, and patches the P1100-series PPD:

- adds `InputSlot Auto/Printer Default`
- makes `Auto` the default paper source
- removes the `MediaPosition 4` command from manual feed so P1102 devices without a Go button do not get stuck waiting for manual feed

For older workflows, `--build-pkg` still patches the installer's `Distribution` checks and creates `HewlettPackardPrinterDrivers-fixed.pkg`.

## Disclaimer

This is an unofficial workaround and not officially supported by HP or Apple. Use at your own risk.

## Credits

- Based on [this blog post](https://blog.kartones.net/post/macos-sequoia-hp-laserjet-p1102-drivers/) by Kartones.
- macOS Tahoe support and already-expanded package support by [@3l500nfy](https://github.com/3l500nfy) ([original fork](https://github.com/3l500nfy/hp-laserjet-p1102-drivers-for-macos-tahoe)).
