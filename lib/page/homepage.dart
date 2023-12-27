import 'package:flutter/material.dart';
import 'package:flutter_starpos_printer/flutter_blue_plus.dart';
import 'package:starpos_printer_helper/page/print_bitmap.dart';
import 'package:starpos_printer_helper/page/print_text.dart';
import 'package:starpos_printer_helper/printer_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PrinterController controller = PrinterController();

  BluetoothDevice? printer;

  @override
  void initState() {
    super.initState();

    initStarPOSPrinter();
  }

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

  @override
  Widget build(BuildContext context) {
    // temp

    return Scaffold(
      appBar: AppBar(
        title: Text('starPOS Printer'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListTile(
              title: Row(
                children: [
                  Text('Bluetooth state'),
                  Spacer(),
                  Text(printer != null && printer!.isConnected
                      ? 'Connected'
                      : 'Not found'),
                ],
              ),
            ),
            ListTile(
              title: Row(
                children: [
                  Text('Printer name'),
                  Spacer(),
                  Text(printer != null ? printer!.platformName : ''),
                ],
              ),
            ),
            ListTile(
              title: Row(
                children: [
                  Text('Printer mac address'),
                  Spacer(),
                  Text(printer != null ? printer!.remoteId.str : ''),
                ],
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              decoration: BoxDecoration(),
              child: Column(
                children: [
                  // text
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PrintTextPage()),
                        );
                      },
                      child: Text('Print text'),
                    ),
                  ),

                  // bitmap
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PrintBitmapPage()),
                        );
                      },
                      child: Text('Print bitmap'),
                    ),
                  ),

                  // html
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PrintBitmapPage()),
                        );
                      },
                      child: Text('Print HTML'),
                    ),
                  ),

                  // Print QRCode
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PrintBitmapPage()),
                        );
                      },
                      child: Text('Print QR Code'),
                    ),
                  ),

                  // Print QRCode
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PrintBitmapPage()),
                        );
                      },
                      child: Text('Print Bar Code'),
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PrintBitmapPage()),
                        );
                      },
                      child: Text('Print Table'),
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PrintBitmapPage()),
                        );
                      },
                      child: Text('Print Black'),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
