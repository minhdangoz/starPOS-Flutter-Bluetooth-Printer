import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_starpos_printer/flutter_blue_plus.dart';

class PrinterController {
  late BluetoothDevice device;

  String test =
      "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged.";

  Future<void> testCommands() async {
    // device.sendData(ESCUtil.initPrinter());
    // device.sendData(ESCUtil.setLineSpace(24));
    // device.sendData(ESCUtil.boldOnB68());
    // device.sendData(ESCUtil.underlineWithOneDotWidthOn());
    // device.sendData(ESCUtil.setDefaultLineSpace());
    // device.sendData(ESCUtil.alignLeft());
    // device.sendData(ESCUtil.singleByte());

    // List<int> list = utf8.encode(test);

    final List<int> utf8Bytes = utf8.encode(test);

    // Uint8List bytes = Uint8List.fromList(test.codeUnits);

    device.sendData(Uint8List.fromList(utf8Bytes));
    device.sendData(ESCUtil.nextLine(3));
  }

  Future<void> printBitmap() async {}

  BluetoothDevice getBluetoothDevice() {
    return device;
  }

  Future<void> initBluetoothPrinter({
    Function(BluetoothDevice)? onSuccess,
    Function(String)? onFailure,
  }) async {
    FlutterBluePlus.setLogLevel(LogLevel.info, color: true);

    // first, check if bluetooth is supported by your hardware
    // Note: The platform is initialized on the first call to any FlutterBluePlus method.
    if (await FlutterBluePlus.isSupported == false) {
      print('--> Bluetooth not supported by this device');

      if (onFailure != null) {
        onFailure('Bluetooth not supported by this device');
      }

      return;
    }

    // handle bluetooth on & off
    // note: if you have permissions issues you will get stuck at BluetoothAdapterState.unauthorized
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) async {
      print('--> bluetooth adapter state = ${state}');
      if (state == BluetoothAdapterState.on) {
        // usually start scanning, connecting, etc

        final List<BluetoothDevice> devs = await FlutterBluePlus.bondedDevices;

        print('--> devs size = ${devs.length}');

        for (var d in devs) {
          print('--> name: ${d.advName}');
          print('--> id: ${d.remoteId.str}');
          print('--> platformName: ${d.platformName}');

          await d.connect(); // Must connect *our* app to the device

          device = d;

          if (onSuccess != null) {
            onSuccess(device);
          }

          // device.sendData(ESCUtil.nextLine(1));
        }
      } else {
        // show an error to the user, etc
        if (onFailure != null) {
          onFailure('Something went wrong');
        }
      }
    });

    // turn on bluetooth ourself if we can
    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }
  }
}
