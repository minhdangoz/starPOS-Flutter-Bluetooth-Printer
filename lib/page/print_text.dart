import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_starpos_printer/flutter_blue_plus.dart';
import 'package:starpos_printer_helper/printer_controller.dart';

class PrintTextPage extends StatefulWidget {
  const PrintTextPage({super.key});

  @override
  State<PrintTextPage> createState() => _PrintTextPageState();
}

class _PrintTextPageState extends State<PrintTextPage> {
  PrinterController controller = PrinterController();

  BluetoothDevice? printer;

  TextEditingController textController = TextEditingController();

  @override
  void initState() {
    super.initState();

    initStarPOSPrinter();

    textController.text =
        "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged.";
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Print text'),
      ),
      body: Column(
        children: [
          ListTile(
            title: Row(
              children: [
                Text('Charset'),
                Spacer(),
                Text('UTF-8'),
              ],
            ),
          ),
          ListTile(
            title: Row(
              children: [
                Text('Text size'),
                Spacer(),
                Text('Default'),
              ],
            ),
          ),

          // textbox

          Expanded(
            child: SizedBox(
              width: double.infinity, // <-- TextField width
              // height: 240, // <-- TextField height
              child: Container(
                margin: EdgeInsets.all(16),
                child: TextField(
                  controller: textController,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                      filled: true,
                      hintText: 'Enter a message',
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                      )),
                ),
              ),
            ),
          ),

          Spacer(),

          Container(
            margin: EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // start printing

                  final List<int> utf8Bytes = utf8.encode(textController.text);

                  // Uint8List bytes = Uint8List.fromList(test.codeUnits);

                  printer?.sendData(Uint8List.fromList(utf8Bytes));
                  printer?.sendData(ESCUtil.nextLine(3));
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
