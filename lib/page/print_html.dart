import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_starpos_printer/flutter_blue_plus.dart';
import 'package:starpos_printer_helper/page/bottom_sheet.dart';
import 'package:webcontent_converter/webcontent_converter.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PrintHtmlPage extends StatefulWidget {
  const PrintHtmlPage({super.key});

  @override
  State<PrintHtmlPage> createState() => _PrintHtmlPageState();
}

class _PrintHtmlPageState extends State<PrintHtmlPage> {
  PrinterController printerController = PrinterController();

  WebViewController? _controller;

  BluetoothDevice? printer;

  final String path = 'assets/html/base_print_bill.html';

  bool isLoading = true;

  final urlController = TextEditingController();

  String htmlContent = '';

  var bytes = Uint8List(0);

  Future<void> initHTML() async {
    htmlContent = await rootBundle.loadString(path, cache: false);

    bytes = await WebcontentConverter.contentToImage(
      content: htmlContent,
      duration: 5000,
      scale: 1,
    );

    setState(() {
      _controller?.loadHtmlString(htmlContent);
    });
  }

  void initPage() {
    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(
            PlatformWebViewControllerCreationParams());

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      );
    _controller = controller;
  }

  @override
  void initState() {
    initHTML();

    initPage();

    super.initState();

    initStarPOSPrinter();
  }

  Future<void> initStarPOSPrinter() async {
    await printerController.initBluetoothPrinter(
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
    if (bytes.isNotEmpty) {
      print('--> bytes size ${bytes.length}');
      // printer?.printRasterBitmap(bytes);
      // printer?.printNextLine(2);

      bytes = await WebcontentConverter.contentToImage(
        content: htmlContent,
        duration: 5000,
        scale: 1,
      );

      showModalBottomSheet(
          context: context,
          builder: (context) => BottomSheetBill(
                data: bytes,
                printer: printer!,
              ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Print HTML'),
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
            child: WebViewWidget(controller: _controller!),
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
