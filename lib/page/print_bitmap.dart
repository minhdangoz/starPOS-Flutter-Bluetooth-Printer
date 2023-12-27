import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_starpos_printer/flutter_blue_plus.dart';
import 'package:starpos_printer_helper/printer_controller.dart';

class PrintBitmapPage extends StatefulWidget {
  const PrintBitmapPage({super.key});

  @override
  State<PrintBitmapPage> createState() => _PrintBitmapPageState();
}

class _PrintBitmapPageState extends State<PrintBitmapPage> {
  PrinterController controller = PrinterController();

  BluetoothDevice? printer;

  final String imagePath = 'assets/images/bill2.png';

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

  Future<void> startPrinting() async {
    final ByteData byte = await rootBundle.load(imagePath);
    final List<int> bytes = byte.buffer.asUint8List();
    final data = Uint8List.fromList(bytes);

    printer?.sendData(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Print bitmap'),
      ),
      body: Column(
        children: [
          ListTile(
            title: Row(
              children: [
                Text('Align'),
                Spacer(),
                Text('Left'),
              ],
            ),
          ),
          ListTile(
            title: Row(
              children: [
                Text('Print method'),
                Spacer(),
                Text('Raster bitmap'),
              ],
            ),
          ),

          // textbox

          Expanded(
            child: Container(
              color: Colors.black12,
              width: double.infinity,
              height: double.infinity,
              margin: EdgeInsets.all(16),
              child: Image.asset(
                imagePath,
                fit: BoxFit.fitHeight,
              ),
            ),
          ),

          Container(
            margin: EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // start printing

                  // final List<int> utf8Bytes = utf8.encode(textController.text);

                  // printer?.sendData(Uint8List.fromList(utf8Bytes));
                  // printer?.sendData(ESCUtil.nextLine(3));

                  startPrinting();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  textStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(
                  'PRINT',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
