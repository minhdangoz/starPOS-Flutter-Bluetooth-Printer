part of flutter_blue_plus;

class ESCUtil {
  static final int ESC = 0x1B;
  static final int FS = 0x1C;
  static final int GS = 0x1D;
  static final int DLE = 0x10;
  static final int EOT = 0x04;
  static final int ENQ = 0x05;
  static final int SP = 0x20;
  static final int HT = 0x09;
  static final int LF = 0x0A;
  static final int CR = 0x0D;
  static final int FF = 0x0C;
  static final int CAN = 0x18;

  static Uint8List initPrinter() {
    return Uint8List.fromList([ESC, 0x40]);
  }

  static Uint8List setPrinterDarkness(int value) {
    return Uint8List.fromList([
      GS,
      40,
      69,
      4,
      0,
      5,
      5,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
  }

  // static Uint8List getPrintQRCode(String code, int moduleSize, int errorLevel) {
  //   var buffer = ByteBuffer(2048);
  //   buffer.writeUint8(setQRCodeSize(moduleSize));
  //   buffer.add(setQRCodeErrorLevel(errorLevel));
  //   buffer.add(getQCodeBytes(code));
  //   buffer.add(getBytesForPrintQRCode(true));
  //   return buffer.toUint8List();
  // }

  // static Uint8List getPrintDoubleQRCode(
  //     String code1, String code2, int moduleSize, int errorLevel) {

  //   var buffer = ByteBuffer();
  //   buffer.add(setQRCodeSize(moduleSize));
  //   buffer.add(setQRCodeErrorLevel(errorLevel));
  //   buffer.add(getQCodeBytes(code1));
  //   buffer.add(getBytesForPrintQRCode(false));
  //   buffer.add(getQCodeBytes(code2));
  //   buffer.add(Uint8List.fromList([0x1B, 0x5C, 0x18, 0x00]));
  //   buffer.add(getBytesForPrintQRCode(true));
  //   return buffer.toUint8List();
  // }

  // static Uint8List getPrintQRCode2(String data, int size) {
  //   var bytes1 = Uint8List.fromList([GS, 0x76, 0x30, 0x00]);
  //   var bytes2 = BytesUtil.getZXingQRCode(data, size);
  //   return BytesUtil.byteMerger(bytes1, bytes2);
  // }

  static Uint8List setQRCodeSize(int moduleSize) {
    Uint8List dtmp = Uint8List(8);
    dtmp[0] = GS;
    dtmp[1] = 0x28;
    dtmp[2] = 0x6B;
    dtmp[3] = 0x03;
    dtmp[4] = 0x00;
    dtmp[5] = 0x31;
    dtmp[6] = 0x43;
    dtmp[7] = moduleSize;
    return dtmp;
  }

  static Uint8List setQRCodeErrorLevel(int errorLevel) {
    Uint8List dtmp = Uint8List(8);
    dtmp[0] = GS;
    dtmp[1] = 0x28;
    dtmp[2] = 0x6B;
    dtmp[3] = 0x03;
    dtmp[4] = 0x00;
    dtmp[5] = 0x31;
    dtmp[6] = 0x45;
    dtmp[7] = (48 + errorLevel);
    return dtmp;
  }

  static Uint8List getBytesForPrintQRCode(bool single) {
    Uint8List dtmp;
    if (single) {
      dtmp = Uint8List(9);
      dtmp[8] = 0x0A;
    } else {
      dtmp = Uint8List(8);
    }
    dtmp[0] = 0x1D;
    dtmp[1] = 0x28;
    dtmp[2] = 0x6B;
    dtmp[3] = 0x03;
    dtmp[4] = 0x00;
    dtmp[5] = 0x31;
    dtmp[6] = 0x51;
    dtmp[7] = 0x30;
    return dtmp;
  }

  static Uint8List getQCodeBytes(String code) {
    ByteData buffer = ByteData(7095);
    int len = code.length + 3;
    if (len > 7092) len = 7092;
    buffer.setUint8(0, 0x1D);
    buffer.setUint8(1, 0x28);
    buffer.setUint8(2, 0x6B);
    buffer.setUint8(3, len);
    buffer.setUint8(4, len >> 8);
    buffer.setUint8(5, 0x31);
    buffer.setUint8(6, 0x50);
    buffer.setUint8(7, 0x30);
    for (int i = 0; i < code.length && i < len - 3; i++) {
      buffer.setUint8(8 + i, code.codeUnitAt(i));
    }
    return buffer.buffer.asUint8List();
  }

  // static Uint8List getPrintBarCode(
  //     String data, int symbology, int height, int width, int textPosition) {
  //   if (symbology < 0 || symbology > 10) {
  //     return Uint8List.fromList([LF]);
  //   }

  //   if (width < 2 || width > 6) {
  //     width = 2;
  //   }

  //   if (textPosition < 0 || textPosition > 3) {
  //     textPosition = 0;
  //   }

  //   if (height < 1 || height > 255) {
  //     height = 162;
  //   }

  //   var buffer = BytesBuffer();
  //   buffer.add(Uint8List.fromList([
  //     0x1D,
  //     0x66,
  //     0x01,
  //     0x1D,
  //     0x48,
  //     textPosition,
  //     0x1D,
  //     0x77,
  //     width,
  //     0x1D,
  //     0x68,
  //     height,
  //     0x0A
  //   ]));

  //   Uint8List barcode;
  //   if (symbology == 10) {
  //     barcode = BytesUtil.getBytesFromDecString(data);
  //   } else {
  //     barcode = Uint8List.fromList(data.codeUnits);
  //   }

  //   if (symbology > 7) {
  //     buffer.add(Uint8List.fromList([
  //       0x1D,
  //       0x6B,
  //       0x49,
  //       (barcode.length + 2),
  //       0x7B,
  //       (0x41 + symbology - 8)
  //     ]));
  //   } else {
  //     buffer.add(Uint8List.fromList([
  //       0x1D,
  //       0x6B,
  //       (symbology + 0x41),
  //       barcode.length
  //     ]));
  //   }
  //   buffer.add(barcode);

  //   return buffer.toBytes();
  // }

  static Uint8List printBitmap(Uint8List bitmap) {
    print("--> printBitmap");
    var bytes1 = Uint8List.fromList([GS, 0x76, 0x30, 0x00]);
    return BytesUtil.byteMerger(bytes1, bitmap);
  }

  static Uint8List printRasterBitmap(Uint8List bitmap, int mode) {
    print("--> printRasterBitmap mode = $mode");
    var bytes1 = Uint8List.fromList([GS, 0x76, 0x30, mode]);
    return BytesUtil.byteMerger(bytes1, bitmap);
  }

  static Uint8List printBitmapMode(int width) {
    var widthLSB = width & 0xFF;
    var widthMSB = (width >> 8) & 0xFF;
    return Uint8List.fromList([ESC, 42, 33, widthLSB, widthMSB]);
  }

  static Uint8List printBitmapBytes(Uint8List bytes) {
    print("--> printBitmapBytes");
    var bytes1 = Uint8List.fromList([GS, 0x76, 0x30, 0x00]);
    return BytesUtil.byteMerger(bytes1, bytes);
  }

  static Uint8List selectBitmap(Uint8List bitmap, int mode) {
    print("--> selectBitmap mode = $mode");
    return BytesUtil.byteMerger(
        BytesUtil.byteMerger(Uint8List.fromList([ESC, 0x33, 0x00]),
            BytesUtil.getBytesFromBitMapMode(bitmap, mode)),
        Uint8List.fromList([0x0A, 0x1B, 0x32]));
  }

  static Uint8List nextLine(int lineNum) {
    var result = Uint8List(lineNum);
    for (var i = 0; i < lineNum; i++) {
      result[i] = LF;
    }
    return result;
  }

  static Uint8List setDefaultLineSpace() {
    return Uint8List.fromList([ESC, 0x32]);
  }

  static Uint8List setLineSpace(int height) {
    return Uint8List.fromList([ESC, 0x33, height]);
  }

  static Uint8List underlineWithOneDotWidthOn() {
    return Uint8List.fromList([ESC, 45, 1]);
  }

  static Uint8List underlineWithTwoDotWidthOn() {
    return Uint8List.fromList([ESC, 45, 2]);
  }

  static Uint8List underlineOff() {
    return Uint8List.fromList([ESC, 45, 0]);
  }

  static Uint8List boldOn() {
    return Uint8List.fromList([ESC, 69, 0xF]);
  }

  static Uint8List boldOnB68() {
    return Uint8List.fromList([ESC, 0x45, 0x01]);
  }

  static Uint8List alignLeft() {
    return Uint8List.fromList([ESC, 0x61, 0x00]);
  }

  static Uint8List alignCenter() {
    return Uint8List.fromList([ESC, 0x61, 0x01]);
  }

  static Uint8List alignRight() {
    return Uint8List.fromList([ESC, 0x61, 0x02]);
  }

  static Uint8List cutter() {
    return Uint8List.fromList([0x1D, 0x56, 0x01]);
  }

  static Uint8List gogogo() {
    return Uint8List.fromList([0x1C, 0x28, 0x4C, 0x02, 0x00, 0x42, 0x31]);
  }

  static singleByte() {
    return Uint8List.fromList([FS, 0x2E]);
  }

  static Uint8List singleByteOff() {
    return Uint8List.fromList([FS, 0x26]);
  }

  static Uint8List setCodeSystemSingle(int charset) {
    return Uint8List.fromList([ESC, 0x74, charset]);
  }

  static Uint8List setCodeSystem(int charset) {
    return Uint8List.fromList([FS, 0x43, charset]);
  }
}
