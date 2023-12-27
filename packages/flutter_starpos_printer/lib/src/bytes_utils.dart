part of flutter_blue_plus;

class BytesUtil {
  static String getHexStringFromBytes(Uint8List? data) {
    if (data == null || data.length <= 0) {
      return "";
    }
    const hexString = "0123456789ABCDEF";
    final size = data.length * 2;
    final sb = StringBuffer(size);
    for (int i = 0; i < data.length; i++) {
      sb.write(hexString[(data[i] & 0xF0) >> 4]);
      sb.write(hexString[data[i] & 0x0F]);
    }
    return sb.toString();
  }

  static byteToChar(String c) {
    return "0123456789ABCDEF".indexOf(c);
  }

  static Uint8List getBytesFromHexString(String? hexString) {
    if (hexString == null || hexString.isEmpty) {
      return Uint8List(1);
    }
    hexString = hexString.replaceAll(" ", "");
    hexString = hexString.toUpperCase();
    final size = hexString.length ~/ 2;
    final hexArray = hexString.runes.toList();
    final result = Uint8List(size);
    for (int i = 0; i < size; i++) {
      final pos = i * 2;
      result[i] = (byteToChar(hexArray[pos].toString()) << 4) |
          byteToChar(hexArray[pos + 1].toString());
    }
    return result;
  }

  static Uint8List getBytesFromDecString(String? decString) {
    if (decString == null || decString.isEmpty) {
      return Uint8List(1);
    }
    decString = decString.replaceAll(" ", "");
    final size = decString.length ~/ 2;
    final decArray = decString.runes.toList();
    final result = Uint8List(size);
    for (int i = 0; i < size; i++) {
      final pos = i * 2;
      result[i] = (byteToChar(decArray[pos].toString()) * 10) +
          byteToChar(decArray[pos + 1].toString());
    }
    return result;
  }

  static Uint8List byteMerger(Uint8List byte1, Uint8List byte2) {
    final byte3 = Uint8List(byte1.length + byte2.length);
    byte3.setAll(0, byte1);
    byte3.setAll(byte1.length, byte2);
    return byte3;
  }

  static Uint8List byteMergerList(List<Uint8List> byteList) {
    var length = 0;
    for (final byte in byteList) {
      length += byte.length;
    }
    final result = Uint8List(length);

    var index = 0;
    for (final byte in byteList) {
      result.setAll(index, byte);
      index += byte.length;
    }
    return result;
  }

  static Uint8List initTable(int h, int w) {
    final hh = h * 32;
    final ww = w * 4;

    final data = Uint8List(hh * ww + 5);
    data[0] = ww & 0xFF;
    data[1] = (ww >> 8) & 0xFF;
    data[2] = hh & 0xFF;
    data[3] = (hh >> 8) & 0xFF;

    var k = 4;
    var m = 31;
    for (var i = 0; i < h; i++) {
      for (var j = 0; j < w; j++) {
        data[k++] = 0xFF;
        data[k++] = 0xFF;
        data[k++] = 0xFF;
        data[k++] = 0xFF;
      }
      if (i == h - 1) m = 30;
      for (var t = 0; t < m; t++) {
        for (var j = 0; j < w - 1; j++) {
          data[k++] = 0x80;
          data[k++] = 0;
          data[k++] = 0;
          data[k++] = 0;
        }
        data[k++] = 0x80;
        data[k++] = 0;
        data[k++] = 0;
        data[k++] = 0x01;
      }
    }
    for (var j = 0; j < w; j++) {
      data[k++] = 0xFF;
      data[k++] = 0xFF;
      data[k++] = 0xFF;
      data[k++] = 0xFF;
    }
    data[k++] = 0x0A;
    return data;
  }

  Uint8List getBytesFromBitMap(Uint8List bitmap) {
    int width = (bitmap[1] << 8) | bitmap[0];
    int height = (bitmap[3] << 8) | bitmap[2];
    int bw = (width - 1) ~/ 8 + 1;

    Uint8List rv = Uint8List(height * bw + 4);
    rv[0] = bw;
    rv[1] = bw >> 8;
    rv[2] = height;
    rv[3] = height >> 8;

    Int32List pixels = Int32List(width * height);
    for (int i = 0; i < pixels.length; i++) {
      pixels[i] = (bitmap[(i * 4) + 7] << 24) |
          (bitmap[(i * 4) + 6] << 16) |
          (bitmap[(i * 4) + 5] << 8) |
          (bitmap[(i * 4) + 4]);
    }

    for (int i = 0; i < height; i++) {
      for (int j = 0; j < width; j++) {
        int clr = pixels[width * i + j];
        int red = (clr & 0x00ff0000) >> 16;
        int green = (clr & 0x0000ff00) >> 8;
        int blue = clr & 0x000000ff;
        int gray = RGB2Gray(red, green, blue);
        rv[bw * i + j ~/ 8 + 4] |= (gray << (7 - j % 8));
      }
    }

    return rv;
  }

  static Uint8List getBytesFromBitMapMode(Uint8List bitmap, int mode) {
    int width = (bitmap[1] << 8) | bitmap[0];
    int height = (bitmap[3] << 8) | bitmap[2];
    Int32List pixels = Int32List(width * height);
    for (int i = 0; i < pixels.length; i++) {
      pixels[i] = (bitmap[(i * 4) + 7] << 24) |
          (bitmap[(i * 4) + 6] << 16) |
          (bitmap[(i * 4) + 5] << 8) |
          (bitmap[(i * 4) + 4]);
    }

    if (mode == 0 || mode == 1) {
      Uint8List res = Uint8List(width * height ~/ 8 + 5 * height ~/ 8);
      for (int i = 0; i < height ~/ 8; i++) {
        res[i * (width + 5)] = 0x1b;
        res[i * (width + 5) + 1] = 0x2a;
        res[i * (width + 5) + 2] = mode;
        res[i * (width + 5) + 3] = width % 256;
        res[i * (width + 5) + 4] = width ~/ 256;
        for (int j = 0; j < width; j++) {
          int gray = 0;
          for (int m = 0; m < 8; m++) {
            int clr = pixels[j + width * (i * 8 + m)];
            int red = (clr & 0x00ff0000) >> 16;
            int green = (clr & 0x0000ff00) >> 8;
            int blue = clr & 0x000000ff;
            gray = ((RGB2Gray(red, green, blue) << (7 - m)) | gray) & 0xFF;
          }
          res[5 + j + i * (width + 5)] = gray;
        }
      }
      return res;
    } else if (mode == 32 || mode == 33) {
      Uint8List res = Uint8List(width * height ~/ 8 + 5 * height ~/ 24);
      for (int i = 0; i < height ~/ 24; i++) {
        res[i * (width * 3 + 5)] = 0x1b;
        res[i * (width * 3 + 5) + 1] = 0x2a;
        res[i * (width * 3 + 5) + 2] = mode;
        res[i * (width * 3 + 5) + 3] = width % 256;
        res[i * (width * 3 + 5) + 4] = width ~/ 256;
        for (int j = 0; j < width; j++) {
          for (int n = 0; n < 3; n++) {
            int gray = 0;
            for (int m = 0; m < 8; m++) {
              int clr = pixels[j + width * (i * 24 + m + n * 8)];
              int red = (clr & 0x00ff0000) >> 16;
              int green = (clr & 0x0000ff00) >> 8;
              int blue = clr & 0x000000ff;
              gray = ((RGB2Gray(red, green, blue) << (7 - m)) | gray) & 0xFF;
            }
            res[5 + j * 3 + i * (width * 3 + 5) + n] = gray;
          }
        }
      }
      return res;
    } else {
      return Uint8List.fromList([0x0A]);
    }
  }

  static int RGB2Gray(int r, int g, int b) {
    return (false
            ? ((0.29900 * r + 0.58700 * g + 0.11400 * b) > 200)
            : ((0.29900 * r + 0.58700 * g + 0.11400 * b) < 200))
        ? 1
        : 0;
  }

  Uint8List initBlackBlock(int w) {
    int ww = (w + 7) ~/ 8;
    int n = (ww + 11) ~/ 12;
    int hh = n * 24;
    Uint8List data = Uint8List(hh * ww + 5);

    data[0] = ww;
    data[1] = ww >> 8;
    data[2] = hh;
    data[3] = hh >> 8;

    int k = 4;
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < 24; j++) {
        for (int m = 0; m < ww; m++) {
          data[k++] = (m ~/ 12 == i) ? 0xFF : 0;
        }
      }
    }
    data[k++] = 0x0A;
    return data;
  }

  Uint8List initBlackBlockWH(int h, int w) {
    int hh = h;
    int ww = (w - 1) ~/ 8 + 1;
    Uint8List data = Uint8List(hh * ww + 6);

    data[0] = ww;
    data[1] = ww >> 8;
    data[2] = hh;
    data[3] = hh >> 8;

    int k = 4;
    for (int i = 0; i < hh; i++) {
      for (int j = 0; j < ww; j++) {
        data[k++] = 0xFF;
      }
    }
    data[k++] = 0x00;
    data[k++] = 0x00;
    return data;
  }
}
