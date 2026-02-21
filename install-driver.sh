#!/bin/bash

# HP Printer Driver Installer for macOS Sequoia, Tahoe and later
# Based on: https://blog.kartones.net/post/macos-sequoia-hp-laserjet-p1102-drivers/
# Modifies the Distribution file to bypass the macOS version check (blocks versions > 15.0)

# Print colored output
print_green() {
    echo -e "\033[0;32m$1\033[0m"
}

print_yellow() {
    echo -e "\033[0;33m$1\033[0m"
}

print_red() {
    echo -e "\033[0;31m$1\033[0m"
}

# Determine source: .pkg file or already-expanded package
DRIVERS_DIR=""
CLEANUP_AFTER=0

if [ -f "HewlettPackardPrinterDrivers.pkg" ]; then
    print_green "Expanding the HP driver package..."
    pkgutil --expand HewlettPackardPrinterDrivers.pkg drivers
    DRIVERS_DIR="drivers"
    CLEANUP_AFTER=1
elif [ -f "Distribution" ]; then
    print_green "Using already-expanded package in current directory..."
    DRIVERS_DIR="."
else
    print_red "Error: HewlettPackardPrinterDrivers.pkg or expanded package not found."
    print_yellow "Please extract the .pkg from the HP driver .dmg, or run this script from the expanded package directory."
    exit 1
fi

# Check if the Distribution file exists
if [ ! -f "$DRIVERS_DIR/Distribution" ]; then
    print_red "Error: Distribution file not found."
    exit 1
fi

# Modify the Distribution file to bypass the macOS version check
# The installer blocks versions > 15.0; we change to 27.0 to cover Sequoia, Tahoe and beyond
print_green "Modifying the Distribution file to bypass macOS version check..."
sed -i '' "s/system.version.ProductVersion, '15.0'/system.version.ProductVersion, '27.0'/g" "$DRIVERS_DIR/Distribution"

# Check if the modification was successful
if grep -q "system.version.ProductVersion, '27.0'" "$DRIVERS_DIR/Distribution"; then
    print_green "Distribution file successfully modified."
else
    print_red "Error: Failed to modify the Distribution file."
    exit 1
fi

# Create the modified package
print_green "Creating the modified package..."
pkgutil --flatten "$DRIVERS_DIR" HewlettPackardPrinterDrivers-fixed.pkg

# Check if the new package was created
if [ ! -f "HewlettPackardPrinterDrivers-fixed.pkg" ]; then
    print_red "Error: Failed to create the modified package."
    exit 1
fi

# Clean up temporary directory (only if we expanded from .pkg)
if [ "$CLEANUP_AFTER" -eq 1 ]; then
    print_green "Cleaning up temporary files..."
    rm -rf drivers
fi

print_green "Installation package successfully created!"
print_green "The modified driver package is: HewlettPackardPrinterDrivers-fixed.pkg"
print_yellow "You can now install the driver by double-clicking on HewlettPackardPrinterDrivers-fixed.pkg"

exit 0
