import 'package:flutter/material.dart';
import 'package:flutter_starpos_printer/flutter_blue_plus.dart';

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
        "Sáng nay (28/12), Thủ tướng Chính phủ Phạm Minh Chính đã dự và chỉ đạo Hội nghị tổng kết công tác năm 2023 và triển khai kế hoạch năm 2024 của ngành giao thông vận tải.";
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

          Container(
            margin: EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // start printing
                  final input = textController.text;

                  print('--> print text content: $input');

                  printer?.printText(input, 'utf-8');
                  printer?.printNextLine(1);
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
