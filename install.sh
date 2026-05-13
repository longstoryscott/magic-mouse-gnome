#!/bin/bash
#
# Magic Mouse GNOME - Installation Script
#
# Usage: ./install.sh (do NOT run with sudo)
#

set -e

INSTALL_DIR="/opt/magic-mouse-gnome"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_SERVICE_DIR="$HOME/.config/systemd/user"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Magic Mouse GNOME Installer"
echo "============================"
echo

# Check NOT running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Error: Do not run this script with sudo${NC}"
    echo "Run it as your normal user: ./install.sh"
    exit 1
fi

# Check dependencies
echo "Checking dependencies..."

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 is required${NC}"
    exit 1
fi

# Check for key simulation backend (ydotool preferred, wtype as fallback)
HAS_YDOTOOL=false
HAS_WTYPE=false

if command -v ydotool &> /dev/null; then
    HAS_YDOTOOL=true
fi

if command -v wtype &> /dev/null; then
    HAS_WTYPE=true
fi

if [[ "$HAS_YDOTOOL" == false ]] && [[ "$HAS_WTYPE" == false ]]; then
    echo -e "${RED}Error: Neither ydotool nor wtype found${NC}"
    echo "Install one of:"
    echo "  ydotool (recommended for GNOME/KDE): sudo pacman -S ydotool"
    echo "  wtype (for Hyprland/Sway):           sudo pacman -S wtype"
    exit 1
fi

if [[ "$HAS_YDOTOOL" == true ]]; then
    echo -e "${GREEN}  ydotool found (recommended backend)${NC}"
    # Check ydotoold daemon
    if ! systemctl --user is-active --quiet ydotoold 2>/dev/null; then
        echo -e "${YELLOW}  Warning: ydotoold daemon is not running${NC}"
        echo -e "${YELLOW}  Start with: systemctl --user enable --now ydotoold${NC}"
    fi
else
    echo -e "${GREEN}  wtype found (fallback backend)${NC}"
fi

if ! command -v bluetoothctl &> /dev/null; then
    echo -e "${RED}Error: bluetoothctl is required${NC}"
    exit 1
fi

echo -e "${GREEN}Dependencies OK${NC}"
echo

# Find Magic Mouse
echo "Looking for Magic Mouse..."
MAGIC_MOUSE_MAC=$(bluetoothctl devices 2>/dev/null | grep -i "magic\|mouse" | grep -i "004C\|apple" | awk '{print $2}' | head -1)

if [[ -z "$MAGIC_MOUSE_MAC" ]]; then
    MAGIC_MOUSE_MAC=$(bluetoothctl devices Connected 2>/dev/null | grep -i mouse | awk '{print $2}' | head -1)
fi

if [[ -z "$MAGIC_MOUSE_MAC" ]]; then
    echo -e "${YELLOW}Warning: Magic Mouse not found in paired devices${NC}"
    echo "Make sure your Magic Mouse is paired via Bluetooth."
    echo "Continuing installation anyway..."
else
    echo -e "${GREEN}Found Magic Mouse: $MAGIC_MOUSE_MAC${NC}"
fi

echo

# Install files (requires sudo)
echo "Installing driver to $INSTALL_DIR (requires sudo)..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp "$SCRIPT_DIR/magic_mouse_gestures.py" "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR/magic_mouse_gestures.py"

# Install udev rules
echo "Installing udev rules..."
sudo cp "$SCRIPT_DIR/udev/99-magic-mouse.rules" /etc/udev/rules.d/
sudo udevadm control --reload-rules

# Install modprobe config (for scroll optimization)
echo "Installing modprobe config (scroll settings)..."
sudo cp "$SCRIPT_DIR/modprobe/hid-magicmouse.conf" /etc/modprobe.d/

# Reload hid_magicmouse module if loaded
if lsmod | grep -q hid_magicmouse; then
    echo "Reloading hid_magicmouse module..."
    sudo modprobe -r hid_magicmouse 2>/dev/null || true
    sudo modprobe hid_magicmouse 2>/dev/null || true
fi

echo -e "${GREEN}System files installed${NC}"
echo

# Disconnect Magic Mouse to trigger udev rules on reconnect
if [[ -n "$MAGIC_MOUSE_MAC" ]]; then
    echo "Disconnecting Magic Mouse to apply udev rules..."
    bluetoothctl disconnect "$MAGIC_MOUSE_MAC" 2>/dev/null || true
    sleep 2

    echo "Reconnecting Magic Mouse..."
    bluetoothctl connect "$MAGIC_MOUSE_MAC" 2>/dev/null || true
    sleep 3

    echo -e "${GREEN}Magic Mouse reconnected${NC}"
fi

echo

# Install systemd user service
echo "Installing systemd user service..."
mkdir -p "$USER_SERVICE_DIR"
cp "$SCRIPT_DIR/systemd/magic-mouse-gnome.service" "$USER_SERVICE_DIR/"

# Enable and start the service
echo "Enabling and starting service..."
systemctl --user daemon-reload
systemctl --user enable magic-mouse-gnome
systemctl --user restart magic-mouse-gnome

sleep 2

# Verify installation
echo
echo "Verifying installation..."
echo

# Check service status
if systemctl --user is-active --quiet magic-mouse-gnome; then
    echo -e "${GREEN}✓ Service is running${NC}"
else
    echo -e "${RED}✗ Service is not running${NC}"
    echo "Check logs with: journalctl --user -u magic-mouse-gnome"
fi

# Check hidraw permissions
HIDRAW_OK=false
for hidraw in /dev/hidraw*; do
    if [[ -r "$hidraw" ]]; then
        UEVENT="/sys/class/hidraw/$(basename $hidraw)/device/uevent"
        if [[ -f "$UEVENT" ]] && grep -qi "004C" "$UEVENT" && grep -qi "0269" "$UEVENT"; then
            PERMS=$(stat -c "%a" "$hidraw")
            if [[ "$PERMS" == "666" ]]; then
                echo -e "${GREEN}✓ Device permissions OK ($hidraw)${NC}"
                HIDRAW_OK=true
            else
                echo -e "${YELLOW}! Device found but permissions not set ($hidraw: $PERMS)${NC}"
                echo "  Try reconnecting the Magic Mouse"
            fi
        fi
    fi
done

if [[ "$HIDRAW_OK" == false ]] && [[ -n "$MAGIC_MOUSE_MAC" ]]; then
    echo -e "${YELLOW}! Magic Mouse hidraw device not found with correct permissions${NC}"
    echo "  This may resolve after reconnecting the mouse"
fi

echo
echo "============================"
echo -e "${GREEN}Installation complete!${NC}"
echo
echo "Test by swiping horizontally on your Magic Mouse in a browser."
echo
echo "Useful commands:"
echo "  Status:  systemctl --user status magic-mouse-gnome"
echo "  Logs:    journalctl --user -u magic-mouse-gnome -f"
echo "  Restart: systemctl --user restart magic-mouse-gnome"
echo
