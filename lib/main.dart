import "dart:convert";
import "dart:io";

import "package:args/args.dart";
import 'package:http/http.dart' as http;

// ANSI colors
const green = '\x1B[32m';
const blue = '\x1B[34m';
const red = '\x1B[31m';
const reset = '\x1B[0m';

const String systemdFile = """
[Unit]
Description=ydotool

[Service]
Type=simple
ExecStart=/usr/local/bin/penoval-usi702-eraser-fix

[Install]
WantedBy=multi-user.target
""";

Future<void> installYdotool(bool installToSystem) async {
  print(
      "${red}Error: ydotool or ydotoold not found in PATH or in pwd.${reset}");
  print(
      "${green}Attempt to download latest ydotool from https://github.com/nyxnor/ydotool ?${reset}");
  if (installToSystem) {
    print(
        "${green}You may want to install ydotool directly to your system with your package manager "
        "(apt, dnf, pacman, rpm-ostree, etc.)${reset}");
  }
  // print without newline
  stdout.write("${blue}Press enter to continue or CTRL+C to cancel.${reset}");
  stdin.readLineSync();

  // Download latest ydotool from releases
  var responseMain = await http.get(Uri.parse(
      "https://github.com/ReimuNotMoe/ydotool/releases/latest/download/ydotool-release-ubuntu-latest"));
  var responseDaemon = await http.get(Uri.parse(
      "https://github.com/ReimuNotMoe/ydotool/releases/latest/download/ydotoold-release-ubuntu-latest"));
  if (responseMain.statusCode == 200 && responseDaemon.statusCode == 200) {
    await File(installToSystem ? "/usr/local/bin/ydotool" : "ydotool")
        .writeAsBytes(responseMain.bodyBytes);
    await File(installToSystem ? "/usr/local/bin/ydotoold" : "ydotoold")
        .writeAsBytes(responseDaemon.bodyBytes);
    print(
        "Files downloaded to ${installToSystem ? "/usr/local/bin" : "current directory"}");
  } else {
    print("Failed to download main binary: ${responseMain.statusCode}");
    print("Failed to download daemon binary: ${responseDaemon.statusCode}");
  }
  // allow execution
  print("Setting executable permissions...");
  await Process.run("chmod", ["+x", "ydotool"]);
  await Process.run("chmod", ["+x", "ydotoold"]);
}

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag("install-as-systemd",
        defaultsTo: false, help: "Install tool on your system");

  // Check if ydotool is installed
  final result = await Process.run('which', ["ydotoold", "ydotool"]);

  if (parser.parse(arguments)["install-as-systemd"]) {
    print("Installing tool to /usr/local/bin and activating systemd service");
    // Prompt to download ydotool if not installed
    if (result.exitCode != 0) {
      await installYdotool(true);
    }

    // Copy dart binary to /usr/local/bin
    await File("penoval-usi702-eraser-fix").copy("/usr/local/bin/penoval-usi702-eraser-fix");

    // Create systemd file, enable and start service
    await File("/etc/systemd/system/penoval-usi702-eraser-fix.service").writeAsString(systemdFile);
    await Process.run("systemctl", ["daemon-reload"]);
    await Process.run("systemctl", ["enable", "--now","penoval-usi702-eraser-fix.service"]);
  }

  // Fallback to pwd binaries
  if (result.exitCode != 0 &&
      (!File("ydotool").existsSync() || !File("ydotoold").existsSync())) {
    await installYdotool(false);
  }

  // Determine which device to use by querying libinput's device list
  ProcessResult libinputResult =
      await Process.run("libinput", ["list-devices"]);

  // Go through all devices and save all that have "tablet" capabilities
  List<Map<String, String>> tabletDevices = [];
  for (String device in libinputResult.stdout.toString().trim().split("\n\n")) {
    final List<String> attributes = device.split("\n");
    final String name = attributes.firstWhere(
        (line) => line.startsWith("Device:"),
        orElse: () => "No device name");
    final String eventName = attributes.firstWhere(
        (line) => line.startsWith("Kernel:"),
        orElse: () => "No event name");

    try {
      if (attributes
          .firstWhere((line) => line.startsWith("Capabilities:"))
          .contains("tablet")) {
        print("Found tablet capable device: $name");
        tabletDevices.add({
          "name": name.split("Device:")[1].trim(),
          "eventName": eventName.split("Kernel:")[1].trim()
        });
      }
    } catch (e) {
      print("${red}Error: $e ${reset}");
      print("Skipping device: $name");
      continue;
    }
  }

  Map<String, String> selectedDevice = {};
  if (tabletDevices.isEmpty) {
    print("${red}No tablet capable devices found. Exiting...${reset}");
    exit(0);
  } else if (tabletDevices.length > 1) {
    print("${blue}Found multiple tablet capable devices.${reset}");
    for (int i = 0; i < tabletDevices.length; i++) {
      print(
          "[$i] ${tabletDevices[i]["name"]} (${tabletDevices[i]["eventName"]})");
    }
    while (true) {
      // write without newline
      stdout.write(
          "${green}Please select one from [0-${tabletDevices.length - 1}]:${reset} ");
      try {
        final int selection = int.parse(stdin.readLineSync()!);
        print("${blue}Selected: ${tabletDevices[selection]["name"]}${reset}");
        selectedDevice = tabletDevices[selection];
        break;
      } catch (e) {
        print("${red}Invalid input. Try again.${reset}");
        continue;
      }
    }
  } else {
    selectedDevice = tabletDevices.first;
    print("${blue}Selected: ${selectedDevice["name"]}${reset}");
  }

  // Start ydotoold process
  Process ydotooldProcess = await Process.start("/usr/local/bin/ydotoold", []);
  ydotooldProcess.exitCode.then((code) {
    print("${red}ydotoold exited with code $code. Stopping monitor...${reset}");
    exit(1);
  });

  // Start libinput monitor process
  Process process = await Process.start(
      "libinput", ["debug-events", "--device=${selectedDevice["eventName"]!}"]);

  // Listen to the stdout stream of the process
  bool enabledShortcut = false;
  process.stdout
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .listen((value) async {
    final outputLine = value.trim();

    if (outputLine.contains("TABLET_TOOL_AXIS")) {
      // extract pressure
      final String pressure =
          outputLine.split("pressure:").last.trim().replaceAll("*", "");
      // eraser is almost always 1.00
      if (pressure == "1.00" && !enabledShortcut) {
        // Press ctrl+space
        print("${green}Enabling shortcut${reset}");
        enabledShortcut = true;
        await Process.run(
            "/usr/local/bin/ydotool", ["key", "29:1", "57:1", "57:0", "29:0"]);
      }
    }

    // Only disable if shortcut was enabled before
    if (enabledShortcut &&
        outputLine.contains("TABLET_TOOL_TIP") &&
        outputLine.endsWith("up")) {
      // Press ctrl+space
      print("${green}Disabling shortcut${reset}");
      enabledShortcut = false;
      await Process.run(
          "/usr/local/bin/ydotool", ["key", "29:1", "57:1", "57:0", "29:0"]);
    }
  });

  process.exitCode.then((code) {
    print("${red}Process exited with code $code. Stopping monitor...${reset}");
    exit(1);
  });
}