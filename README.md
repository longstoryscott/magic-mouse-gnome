# Magic Mouse GNOME

Enable macOS-style swipe gestures on Apple Magic Mouse 2 for Linux/Wayland, with first-class support for GNOME and KDE Plasma.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Python](https://img.shields.io/badge/python-3.8+-green.svg)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Wayland-lightgrey.svg)

## Why This Exists

The Magic Mouse 2 has a touch-sensitive surface, but Linux only exposes basic mouse functionality by default. This driver reads raw HID touch data directly from the device to detect touch positions and translate horizontal swipes into keyboard shortcuts.

The original [magic-mouse-gestures](https://github.com/brenoperucchi/magic-mouse-gestures) project used `wtype` for key simulation, which fails on GNOME with:

```
Compositor does not support the virtual keyboard protocol
```

This project solves that by using **ydotool** (via the Linux uinput framework) as the primary backend, with `wtype` as a fallback for compositors that support it (Hyprland, Sway, etc.).

## Features

- **Horizontal swipe gestures** for browser back/forward navigation
- **ydotool backend** — works on GNOME, KDE Plasma, and any Wayland compositor
- **wtype fallback** — automatic detection for compositors that support the virtual keyboard protocol
- Lightweight Python daemon with minimal dependencies
- Automatic device detection and reconnection
- Configurable via environment variables

## How It Works

| Gesture | Action |
|---------|--------|
| Swipe → (right) | Workspace back (Ctrl+Super+Left) |
| Swipe ← (left) | Workspace forward (Ctrl+Super+Right) |

### Key Simulation Backends

The driver automatically detects and selects the best available backend:

| Backend | How It Works | Works On |
|---------|-------------|----------|
| **ydotool** (preferred) | Linux uinput virtual device | GNOME, KDE Plasma, Hyprland, Sway, X11, any |
| **wtype** (fallback) | Wayland virtual keyboard protocol | Hyprland, Sway (not GNOME) |

Force a specific backend with the `GESTURE_BACKEND` environment variable:
```bash
GESTURE_BACKEND=ydotool python3 magic_mouse_gestures.py
GESTURE_BACKEND=wtype python3 magic_mouse_gestures.py
```

## Requirements

- Linux with kernel 5.15+ (built-in Magic Mouse 2 support)
- **Wayland session** (GNOME, KDE Plasma, Hyprland, Sway, etc.)
- Python 3.8+
- **ydotool** (preferred) or **wtype** (fallback)

### Supported Desktops

| Desktop | Backend | Notes |
|---------|---------|-------|
| **GNOME** | ydotool | wtype does not work on GNOME |
| **KDE Plasma** | ydotool | Wayland since Plasma 6 |
| **Hyprland** | ydotool or wtype | Both work |
| **Sway** | ydotool or wtype | Both work |

To check if you're running Wayland:
```bash
echo $XDG_SESSION_TYPE
# Should output: wayland
```

## Installation

### Option A: Automatic Installation (Recommended)

```bash
git clone https://github.com/longstoryscott/magic-mouse-gnome.git
cd magic-mouse-gnome
./install.sh
```

The installer will:
- Check dependencies (`python3`, `ydotool` or `wtype`, `bluetoothctl`)
- Install the driver to `/opt/magic-mouse-gnome/`
- Install udev rules for non-root access
- Reconnect Magic Mouse to apply permissions
- Install and enable the systemd user service
- Verify everything is working

**Note:** Do NOT run with `sudo`. The script requests sudo only when needed.

### Option B: Manual Installation

#### 1. Install dependencies

**Arch Linux:**
```bash
sudo pacman -S python ydotool bluez-utils
```

**Debian/Ubuntu:**
```bash
sudo apt install python3 ydotool bluez
```

**Fedora:**
```bash
sudo dnf install python3 ydotool bluez
```

#### 2. Install ydotool and start the daemon

ydotool requires a persistent daemon (`ydotoold`) that holds a virtual uinput device:

```bash
# Add your user to the input group (required for uinput access)
sudo usermod -aG input $USER

# Start the daemon (you may need to log out/in for the group change to take effect)
systemctl --user enable --now ydotool
```

#### 3. Install driver and udev rules

```bash
git clone https://github.com/longstoryscott/magic-mouse-gnome.git
cd magic-mouse-gnome

# Install driver
sudo mkdir -p /opt/magic-mouse-gnome
sudo cp magic_mouse_gestures.py /opt/magic-mouse-gnome/
sudo chmod +x /opt/magic-mouse-gnome/magic_mouse_gestures.py

# Install udev rules
sudo cp udev/99-magic-mouse.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

#### 4. Reconnect Magic Mouse

Disconnect and reconnect via Bluetooth to apply permissions:

```bash
bluetoothctl disconnect <MAC_ADDRESS>
bluetoothctl connect <MAC_ADDRESS>
```

#### 5. Install and enable the service

```bash
mkdir -p ~/.config/systemd/user
cp systemd/magic-mouse-gnome.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now magic-mouse-gnome
```

Verify it's running:

```bash
systemctl --user status magic-mouse-gnome
```

## Uninstall

```bash
cd magic-mouse-gnome
./uninstall.sh
```

This stops the service, removes all installed files, and restores default permissions.

## Configuration

All thresholds can be configured via environment variables (no need to edit code):

| Variable | Default | Description |
|----------|---------|-------------|
| `GESTURE_BACKEND` | auto | Force backend: `ydotool` or `wtype` (default: auto-detect) |
| `SWIPE_THRESHOLD` | 200 | Minimum horizontal movement (pixels) |
| `SWIPE_VERTICAL_MAX` | 150 | Maximum vertical movement (pixels) |
| `SWIPE_TIME_MAX` | 0.5 | Maximum swipe duration (seconds) |
| `SWIPE_VELOCITY_MIN` | 200 | Minimum swipe velocity (pixels/second) |
| `SCROLL_COOLDOWN` | 0.25 | Cooldown after scroll before allowing swipe (seconds) |
| `MIN_FINGERS` | 1 | Minimum fingers for swipe gesture |
| `MAX_FINGERS` | 2 | Maximum fingers (ignore if more) |
| `DEBUG` | false | Enable debug output (1, true, yes) |

### Example: Custom configuration

```bash
SWIPE_THRESHOLD=150 SWIPE_VELOCITY_MIN=150 python3 /opt/magic-mouse-gnome/magic_mouse_gestures.py
```

### Persistent configuration (systemd)

```bash
systemctl --user edit magic-mouse-gnome
```

Add:
```ini
[Service]
Environment="SWIPE_THRESHOLD=150"
Environment="SWIPE_VELOCITY_MIN=150"
```

Then restart:
```bash
systemctl --user restart magic-mouse-gnome
```

## Debugging

### Step 1: Stop the systemd service

```bash
systemctl --user stop magic-mouse-gnome
```

### Step 2: Run manually with debug enabled

```bash
DEBUG=1 python3 /opt/magic-mouse-gnome/magic_mouse_gestures.py
```

Or from the project directory:
```bash
DEBUG=1 python3 magic_mouse_gestures.py
```

### Step 3: Save debug output to a file

```bash
DEBUG=1 python3 /opt/magic-mouse-gnome/magic_mouse_gestures.py 2>&1 | tee ~/magic-mouse.log
```

### Step 4: Restart the service when done

```bash
systemctl --user start magic-mouse-gnome
```

### View service logs

```bash
journalctl --user -u magic-mouse-gnome -f
```

## Troubleshooting

### Device not found

Make sure your Magic Mouse 2 is connected via Bluetooth:

```bash
bluetoothctl devices
```

### Permission denied

Either run with `sudo` or install the udev rules (see installation).

### Gestures not working

1. Check if the service is running:
   ```bash
   systemctl --user status magic-mouse-gnome
   ```

2. View logs:
   ```bash
   journalctl --user -u magic-mouse-gnome -f
   ```

3. Run with debug to see touch data:
   ```bash
   systemctl --user stop magic-mouse-gnome
   DEBUG=1 python3 /opt/magic-mouse-gnome/magic_mouse_gestures.py
   ```

### ydotool: "ydotoold daemon is not running"

```bash
systemctl --user enable --now ydotool
```

You may also need to add your user to the `input` group:
```bash
sudo usermod -aG input $USER
```

Then log out and back in (or reboot) for the group change to take effect.

### wtype: "Compositor does not support the virtual keyboard protocol"

This is expected on GNOME. Use ydotool instead:

```bash
sudo apt install ydotool  # Debian/Ubuntu
sudo pacman -S ydotool    # Arch
sudo dnf install ydotool  # Fedora

systemctl --user enable --now ydotool
```

### Verify udev rules

After reconnecting the Magic Mouse, check permissions:

```bash
ls -la /dev/hidraw*
```

The Magic Mouse device should show `crw-rw-rw-` permissions.

## Technical Details

### HID Data Structure

The Magic Mouse 2 sends touch data in the following format:

- **Header (14 bytes):** Mouse movement and button states
- **Touch data (8 bytes per finger):**
  - Bytes 0-1: X position (12-bit)
  - Bytes 1-2: Y position (12-bit)
  - Bytes 3-4: Touch ellipse dimensions
  - Bytes 5-6: Touch ID and orientation
  - Byte 7: Touch state (1-4 = contact, 5-7 = lift)

### Coordinate Parsing

Coordinates are 12-bit values (0-4095) parsed as:

```python
x = tdata[0] | ((tdata[1] & 0x0F) << 8)
y = (tdata[2] << 4) | (tdata[1] >> 4)
```

### Why ydotool Over wtype?

`wtype` uses the Wayland virtual keyboard protocol, which GNOME's Mutter compositor explicitly does not support. `ydotool` uses the Linux `uinput` kernel module to create a virtual input device, which works at a lower level and is accepted by all compositors, including GNOME.

### Why not libinput?

The Linux kernel's `hid-magicmouse` driver converts touch data into scroll events only. It doesn't expose raw multitouch data to libinput, which is why `libinput-gestures` doesn't work with Magic Mouse.

This driver bypasses that limitation by reading directly from the HID raw interface.

### Kernel Module: hid_magicmouse

The `hid_magicmouse` kernel module handles **scroll functionality**. Our driver handles **swipe gestures**. Both work together.

**Check if module is loaded:**
```bash
lsmod | grep hid_magicmouse
```

**Force load the module:**
```bash
sudo modprobe hid_magicmouse
```

### Scroll Configuration

The installer copies `modprobe/hid-magicmouse.conf` to `/etc/modprobe.d/` with optimized scroll settings:

```
options hid_magicmouse scroll_acceleration=1 scroll_speed=32 emulate_3button=0
```

| Option | Default | Description |
|--------|---------|-------------|
| `scroll_acceleration` | 1 | Enable scroll acceleration |
| `scroll_speed` | 32 | Scroll speed multiplier |
| `emulate_3button` | 0 | Emulate middle button with 3-finger click |
| `emulate_scroll_wheel` | 1 | Enable scroll wheel emulation |

**Apply changes manually:**
```bash
sudo modprobe -r hid_magicmouse && sudo modprobe hid_magicmouse
```

Then reconnect the Magic Mouse via Bluetooth.

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- **[magic-mouse-gestures](https://github.com/brenoperucchi/magic-mouse-gestures)** by Breno Perucchi — This project started as a fork, extending the original HID parsing and gesture detection to support ydotool for GNOME compatibility. The touch parsing, gesture detection, and device handling code is directly derived from that project.
- Apple Magic Mouse 2 HID documentation from the Linux kernel source
- **[ydotool](https://github.com/ReimuNotMoe/ydotool)** — Generic Linux command-line automation tool using uinput
- The GNOME and Wayland communities
