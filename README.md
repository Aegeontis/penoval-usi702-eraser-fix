# penoval USI702 eraser fix

Workaround to get the eraser to work on the penoval USI702 (and possibly other pens with a similar issue)

## Installation

1. Download
   the [latest binary from releases](https://github.com/Aegeontis/penoval-usi702-eraser-fix/releases/latest/download/penoval-usi702-eraser-fix.zip)
2. Unzip the file: `unzip penoval-usi702-eraser-fix.zip`
3. Run the binary as root: `sudo ./penoval-usi702-eraser-fix`
4. (Optional): Install the binary as a systemd service by running:
   `sudo ./penoval-usi702-eraser-fix --install-as-daemon`

## How this works:

The display perceives both the tip and the tail eraser as the exact same input (as can be seen in libinput).
However, due to the eraser button having a very short travel distance, it almost always has the maximum pressure (1.0).
To achieve maximum pressure with the tip, the pen must be pushed into the screen with significant force.
This tool monitors libinput and when the pressure is 1.0 executes a shortcut with ydotool (Currently ctrl+space, open
an issue if you need something else).

## Building

1. Download and install the [dartsdk](https://dart.dev/get-dart)
2. Clone the repository: `git clone --depth=1 https://github.com/Aegeontis/penoval-usi702-eraser-fix`
3. Change directory: `cd penoval-usi702-eraser-fix`
4. Build the project: `pub get && dart compile exe lib/main.dart -o penoval-usi702-eraser-fix`