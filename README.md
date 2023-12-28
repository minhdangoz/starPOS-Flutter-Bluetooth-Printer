# starPOS Bluetooth Printer

<img style="width: 50%" src="/screenshots/main.png">
<img style="width: 50%" src="/screenshots/html.png">
<img style="width: 50%" src="/screenshots/html_print.jpg">

## Getting Started

This project is a starting point for a ESC/POS Printer


## How to install

* Clone this project

* Copy packages/flutter_starpos_printer in to your root project

* Add to project dependencies like this

```yaml
flutter_starpos_printer:
    path: 'packages/flutter_starpos_printer'
```

* Run flutter pub get to install
```cli
flutter pub get
```

## How to connect to starPOS bluetooth printer

* Init and connect printer
``` dart
PrinterController controller = PrinterController();
BluetoothDevice? printer;

Future<void> initStarPOSPrinter() async {
    await controller.initBluetoothPrinter(
      onSuccess: (device) {
        printer = device;
        setState(() {});
      },
      onFailure: (error) {
        print('--> error : ${error}');
      },
    );
  }

```

* Call init in initState

```dart 
@override
  void initState() {
    super.initState();

    initStarPOSPrinter();
  }
```

* Basic command to get Bluetooth printer information

```dart
void check(){
    bool connected = printer.isConnected;
    String printerName = printer.platformName;
    String printerAddress = printer.remoteId.str;
}
```

## COMMANDS

* Print bitmap

```dart

/*
* @params imagePath: /assets/image/test.png
*/
Future<void> startPrinting(String imagePath) async {
    final ByteData byte = await rootBundle.load(imagePath);
    final Uint8List bytes = byte.buffer.asUint8List();
    // printer?.initPrinter(); // optional
    printer?.printRasterBitmap(bytes, 0);
    printer?.printNextLine(3);
}
```

* Check BluetoothDevice for more supported commands

