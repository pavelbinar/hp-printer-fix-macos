#!/bin/bash

# HP LaserJet P1102 Driver Installer for macOS Sequoia
# Based on: https://blog.kartones.net/post/macos-sequoia-hp-laserjet-p1102-drivers/

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

# Check if HewlettPackardPrinterDrivers.pkg exists in the current directory
if [ ! -f "HewlettPackardPrinterDrivers.pkg" ]; then
    print_red "Error: HewlettPackardPrinterDrivers.pkg not found in the current directory."
    print_yellow "Please extract the .pkg file from the HP driver .dmg file first."
    exit 1
fi

# Create a temporary directory for the expanded package
print_green "Expanding the HP driver package..."
pkgutil --expand HewlettPackardPrinterDrivers.pkg drivers

# Check if the Distribution file exists
if [ ! -f "drivers/Distribution" ]; then
    print_red "Error: Distribution file not found in the expanded package."
    exit 1
fi

# Modify the Distribution file to bypass the macOS version check
print_green "Modifying the Distribution file to support macOS Sequoia..."
sed -i '' "s/system.version.ProductVersion, '15.0'/system.version.ProductVersion, '16.0'/g" drivers/Distribution

# Check if the modification was successful
if grep -q "system.version.ProductVersion, '16.0'" drivers/Distribution; then
    print_green "Distribution file successfully modified."
else
    print_red "Error: Failed to modify the Distribution file."
    exit 1
fi

# Create the modified package
print_green "Creating the modified package for macOS Sequoia..."
pkgutil --flatten drivers HewlettPackardPrinterDrivers-sequoia.pkg

# Check if the new package was created
if [ ! -f "HewlettPackardPrinterDrivers-sequoia.pkg" ]; then
    print_red "Error: Failed to create the modified package."
    exit 1
fi

# Clean up
print_green "Cleaning up temporary files..."
rm -rf drivers

print_green "✅ Installation package successfully created!"
print_green "The modified driver package is: HewlettPackardPrinterDrivers-sequoia.pkg"
print_yellow "You can now install the driver by double-clicking on HewlettPackardPrinterDrivers-sequoia.pkg"

exit 0
