import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starpos_printer/flutter_blue_plus.dart';

class BottomSheetBill extends StatefulWidget {
  const BottomSheetBill({
    super.key,
    required this.data,
    required this.printer,
  });
  final Uint8List data;

  final BluetoothDevice printer;

  @override
  State<BottomSheetBill> createState() => _BottomSheetBillState();
}

class _BottomSheetBillState extends State<BottomSheetBill> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Column(children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.all(8),
            child: Image.memory(widget.data),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ButtonStyle(
                backgroundColor:
                    MaterialStateColor.resolveWith((states) => Colors.red)),
            onPressed: () {
              // Navigator.pop(context);
              // widget.printer.printBitmapMode(1);
              widget.printer.printRasterBitmap(widget.data, 0);
              widget.printer.printNextLine(1);
            },
            child: Text(
              'PRINT',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }
}
