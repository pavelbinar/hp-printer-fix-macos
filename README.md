# HP Printer Fix for macOS

Fix HP printer driver installation on macOS Sequoia, Tahoe and later. The official HP drivers fail to install on newer macOS versions due to an OS version check in the installer package. This fix bypasses that check — no driver files are modified, only the installer's version restriction.

## Supported Printer Models

The `HewlettPackardPrinterDrivers.pkg` contains drivers for many HP models. This fix has been confirmed to work with:

- HP LaserJet P1102 / Pro P1102 / Pro P1102w
- HP LaserJet Pro M1136
- HP LaserJet M12 / M12W / M13 series
- HP LaserJet P1007
- HP LaserJet 4000N

It should also work with other HP LaserJet and OfficeJet models that use the same `HewlettPackardPrinterDrivers.pkg` installer.

> If this fix works for your printer model, please [open an issue](../../issues) to let us know so we can add it to the list!

## Automated Installation (Recommended)

1. Download the official [HP Mac Printer Driver](https://support.hp.com/us-en/drivers/closure/hp-laserjet-pro-p1102-drucker/model/4110303)
2. Extract the `HewlettPackardPrinterDrivers.pkg` file from the `.dmg` file
3. Download [`install-driver.sh`](install-driver.sh) and place it in the same directory as the `.pkg` file (or in an already-expanded package directory containing `Distribution`)
4. Run:
   ```bash
   chmod +x install-driver.sh
   ./install-driver.sh
   ```
5. Double-click the generated `HewlettPackardPrinterDrivers-fixed.pkg` to install

## Manual Installation

1. Download the official [HP Mac Printer Driver](https://support.hp.com/us-en/drivers/closure/hp-laserjet-pro-p1102-drucker/model/4110303)
2. Extract the `HewlettPackardPrinterDrivers.pkg` file from the `.dmg` file
3. From a terminal, navigate to the folder where you extracted the `.pkg` file and run:
   ```bash
   pkgutil --expand HewlettPackardPrinterDrivers.pkg drivers
   ```
4. Open `drivers/Distribution` with any text editor
5. Change `system.version.ProductVersion, '15.0'` to `system.version.ProductVersion, '27.0'`
6. Save the file, then run:
   ```bash
   pkgutil --flatten drivers HewlettPackardPrinterDrivers-fixed.pkg
   ```
7. Clean up: delete the `drivers` folder and the original `.dmg` & `.pkg` files
8. Double-click `HewlettPackardPrinterDrivers-fixed.pkg` to install

## How It Works

The official HP driver installer checks the macOS version before installation and refuses to run on versions it doesn't recognize. This fix simply raises that version ceiling. No actual driver files are modified — only the installer's `Distribution` file is changed.

This means the fix will likely work with future macOS releases too, by adjusting the version number accordingly.

## Disclaimer

This is an unofficial workaround and not officially supported by HP. Use at your own risk.

## Credits

- Based on [this blog post](https://blog.kartones.net/post/macos-sequoia-hp-laserjet-p1102-drivers/) by Kartones.
- macOS Tahoe support and already-expanded package support by [@3l500nfy](https://github.com/3l500nfy) ([original fork](https://github.com/3l500nfy/hp-laserjet-p1102-drivers-for-macos-tahoe)).
