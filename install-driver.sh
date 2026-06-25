#!/bin/bash

# HP Printer Driver Installer for macOS Sequoia, Tahoe and later.
#
# Modes:
#   default       Install the usable CUPS driver files on modern macOS.
#   --build-pkg   Build HewlettPackardPrinterDrivers-fixed.pkg for older flows.
#   --setup-p1102 Add/update a connected HP LaserJet P1102 queue.
#
# The modern install path intentionally avoids the package payload entries under
# /System, which are blocked by modern macOS system volume protections.

set -euo pipefail

APPLE_DRIVER_PAGE="https://support.apple.com/en-us/106385"
APPLE_DRIVER_DMG="https://updates.cdn-apple.com/2021/macos/071-46903-20211101-0BD2764A-901C-41BA-9573-C17B8FDC4D90/HewlettPackardPrinterDrivers.dmg"

BUILD_PKG=0
INSTALL_DRIVERS=0
INSTALL_EXPLICIT=0
NO_INSTALL=0
SETUP_P1102=0
PRINTER_NAME="HP_LaserJet_P1102"
WORK_DIR=""

print_green() {
    printf "\033[0;32m%s\033[0m\n" "$1"
}

print_yellow() {
    printf "\033[0;33m%s\033[0m\n" "$1"
}

print_red() {
    printf "\033[0;31m%s\033[0m\n" "$1" >&2
}

usage() {
    cat <<EOF
Usage: ./install-driver.sh [options]

Options:
  --install             Install compatible driver files into /Library/Printers (default)
  --no-install          Do not install driver files; useful with --build-pkg
  --build-pkg           Build HewlettPackardPrinterDrivers-fixed.pkg
  --setup-p1102         Add/update a connected HP LaserJet P1102 queue
  --printer-name NAME   Queue name for --setup-p1102 (default: HP_LaserJet_P1102)
  --help                Show this help

Put this script next to HewlettPackardPrinterDrivers.pkg, or run it from an
already-expanded package directory containing Distribution.

Official Apple driver page:
  $APPLE_DRIVER_PAGE

Direct Apple DMG:
  $APPLE_DRIVER_DMG
EOF
}

cleanup() {
    if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

run_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

fail() {
    print_red "Error: $1"
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --install)
            INSTALL_DRIVERS=1
            INSTALL_EXPLICIT=1
            ;;
        --no-install)
            INSTALL_DRIVERS=0
            NO_INSTALL=1
            ;;
        --build-pkg)
            BUILD_PKG=1
            ;;
        --setup-p1102)
            SETUP_P1102=1
            ;;
        --printer-name)
            shift
            [ "$#" -gt 0 ] || fail "--printer-name requires a value."
            PRINTER_NAME="$1"
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            ;;
    esac
    shift
done

if [ "$INSTALL_EXPLICIT" -eq 0 ] && [ "$NO_INSTALL" -eq 0 ]; then
    if [ "$BUILD_PKG" -eq 0 ] || [ "$SETUP_P1102" -eq 1 ]; then
        INSTALL_DRIVERS=1
    fi
fi

WORK_DIR="$(mktemp -d /tmp/hp-printer-fix.XXXXXX)"
EXPANDED_DIR="$WORK_DIR/expanded"
PAYLOAD_DIR="$WORK_DIR/payload"

expand_source_package() {
    if [ -f "HewlettPackardPrinterDrivers.pkg" ]; then
        print_green "Expanding HewlettPackardPrinterDrivers.pkg..."
        pkgutil --expand "HewlettPackardPrinterDrivers.pkg" "$EXPANDED_DIR"
    elif [ -f "Distribution" ]; then
        print_green "Using already-expanded package in current directory..."
        mkdir -p "$EXPANDED_DIR"
        ditto "." "$EXPANDED_DIR"
    else
        print_red "HewlettPackardPrinterDrivers.pkg or expanded package not found."
        print_yellow "Download the Apple HP 5.1.1 driver DMG, open it, and copy HewlettPackardPrinterDrivers.pkg next to this script."
        print_yellow "Apple page: $APPLE_DRIVER_PAGE"
        exit 1
    fi

    [ -f "$EXPANDED_DIR/Distribution" ] || fail "Distribution file not found."
}

patch_distribution_checks() {
    local distribution="$EXPANDED_DIR/Distribution"

    print_green "Patching installer Distribution checks..."

    # Older HP packages block macOS versions above 15.0. Newer Apple packages
    # also contain volume/install checks for pre-Big Sur systems. Make both
    # styles non-blocking so --build-pkg remains useful where package install is
    # still possible.
    /usr/bin/perl -0pi -e "s/system\\.version\\.ProductVersion, '15\\.0'/system.version.ProductVersion, '27.0'/g" "$distribution"
    /usr/bin/perl -0pi -e 's/(function installationCheck\(\)\s*\{)(?!\s*\/\/ hp-printer-fix)/$1\n            \/\/ hp-printer-fix: allow modern macOS.\n            return true;/s' "$distribution"
    /usr/bin/perl -0pi -e 's/(function volumeCheck\(\)\s*\{)(?!\s*\/\/ hp-printer-fix)/$1\n            \/\/ hp-printer-fix: allow modern macOS.\n            return true;/s' "$distribution"
}

build_fixed_package() {
    print_green "Creating HewlettPackardPrinterDrivers-fixed.pkg..."
    pkgutil --flatten "$EXPANDED_DIR" "HewlettPackardPrinterDrivers-fixed.pkg"
    [ -f "HewlettPackardPrinterDrivers-fixed.pkg" ] || fail "Failed to create fixed package."
    print_green "Created: HewlettPackardPrinterDrivers-fixed.pkg"
    print_yellow "Note: on macOS 11 and later, installing this full package can still fail because it contains protected /System payload paths."
}

find_payload() {
    if [ -f "$EXPANDED_DIR/HewlettPackardPrinterDrivers.pkg/Payload" ]; then
        printf "%s\n" "$EXPANDED_DIR/HewlettPackardPrinterDrivers.pkg/Payload"
    elif [ -f "$EXPANDED_DIR/Payload" ]; then
        printf "%s\n" "$EXPANDED_DIR/Payload"
    else
        return 1
    fi
}

patch_ppd_text() {
    local file="$1"

    /usr/bin/perl -0pi -e '
        s/\*DefaultInputSlot: Manual/*DefaultInputSlot: Auto/;
        if (!/\*InputSlot Auto\//) {
            s/(\*DefaultInputSlot: Auto\n)/$1*InputSlot Auto\/Printer Default: ""\n/;
        }
        s#(\*InputSlot Manual/[^:]+:\s*)"<</MediaPosition 4>>setpagedevice"#$1""#g;
    ' "$file"
}

patch_compressed_ppd() {
    local ppd_gz="$1"
    local tmp_plain="$WORK_DIR/$(basename "$ppd_gz" .gz)"
    local tmp_gz="$tmp_plain.gz"

    [ -f "$ppd_gz" ] || return 0

    gzip -dc "$ppd_gz" > "$tmp_plain"
    patch_ppd_text "$tmp_plain"
    gzip -c "$tmp_plain" > "$tmp_gz"
    run_root cp "$tmp_gz" "$ppd_gz"
    run_root chown root:wheel "$ppd_gz"
    run_root chmod 644 "$ppd_gz"
}

patch_active_queue_ppd() {
    local queue="$1"
    local ppd="/etc/cups/ppd/$queue.ppd"
    local tmp="$WORK_DIR/$queue.ppd"

    [ -f "$ppd" ] || return 0

    cp "$ppd" "$tmp"
    patch_ppd_text "$tmp"
    run_root cp "$tmp" "$ppd"
    run_root chown root:_lp "$ppd"
    run_root chmod 644 "$ppd"
}

install_driver_files() {
    local payload
    payload="$(find_payload)" || fail "Payload not found in expanded package."

    print_green "Extracting driver payload..."
    mkdir -p "$PAYLOAD_DIR"
    (
        cd "$PAYLOAD_DIR"
        gzip -dc "$payload" | cpio -id
    )

    [ -d "$PAYLOAD_DIR/Library/Printers" ] || fail "Library/Printers not found in payload."

    print_green "Installing CUPS printer drivers into /Library/Printers..."
    run_root ditto "$PAYLOAD_DIR/Library/Printers" "/Library/Printers"

    print_green "Fixing CUPS driver ownership and permissions..."
    if [ -d "/Library/Printers/hp" ]; then
        run_root chown -R root:wheel "/Library/Printers/hp"
        run_root chmod -R go-w "/Library/Printers/hp"
    fi
    if [ -d "/Library/Printers/PPDs/Contents/Resources" ]; then
        find "/Library/Printers/PPDs/Contents/Resources" -maxdepth 1 -name "hp*.ppd.gz" -print0 |
            while IFS= read -r -d '' ppd; do
                run_root chown root:wheel "$ppd"
                run_root chmod 644 "$ppd"
            done
    fi

    print_green "Patching HP P1100/P1560/P1600 PPDs to avoid forced manual feed..."
    patch_compressed_ppd "/Library/Printers/PPDs/Contents/Resources/hp1100.ppd.gz"
    patch_compressed_ppd "/Library/Printers/PPDs/Contents/Resources/hp1100w.ppd.gz"
    patch_compressed_ppd "/Library/Printers/PPDs/Contents/Resources/hp1560.ppd.gz"
    patch_compressed_ppd "/Library/Printers/PPDs/Contents/Resources/hp1600dn.ppd.gz"

    print_green "Driver files installed."
}

find_p1102_uri() {
    lpinfo -v 2>/dev/null | awk '
        /^direct usb:\/\// && ($0 ~ /P1102/ || $0 ~ /HP%20LaserJet%20Professional%20P1102/) {
            print $2
            exit
        }
    '
}

setup_p1102_queue() {
    local uri
    uri="$(find_p1102_uri)"

    if [ -z "$uri" ]; then
        print_yellow "No connected HP LaserJet P1102 USB device found. Skipping queue setup."
        print_yellow "Connect the printer, then rerun: ./install-driver.sh --setup-p1102"
        return 0
    fi

    print_green "Adding/updating CUPS queue $PRINTER_NAME..."
    lpadmin \
        -p "$PRINTER_NAME" \
        -E \
        -v "$uri" \
        -m "Library/Printers/PPDs/Contents/Resources/hp1100.ppd.gz" \
        -D "HP LaserJet Professional P1102" \
        -L "USB"

    patch_active_queue_ppd "$PRINTER_NAME"

    lpadmin -p "$PRINTER_NAME" -o InputSlot=Auto -o PageSize=A4 -o media=A4
    cupsenable "$PRINTER_NAME"
    cupsaccept "$PRINTER_NAME"
    lpoptions -d "$PRINTER_NAME" >/dev/null

    print_green "Queue ready: $PRINTER_NAME"
    print_yellow "If HP LaserJet Professional Utility crashes, ignore it; printing uses the CUPS filter, not that old utility app."
}

expand_source_package
patch_distribution_checks

if [ "$BUILD_PKG" -eq 1 ]; then
    build_fixed_package
fi

if [ "$INSTALL_DRIVERS" -eq 1 ]; then
    install_driver_files
fi

if [ "$SETUP_P1102" -eq 1 ]; then
    setup_p1102_queue
fi

print_green "Done."
