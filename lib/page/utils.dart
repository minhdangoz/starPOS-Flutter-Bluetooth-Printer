import 'dart:typed_data';

class Utils {
  static Uint8List stringToBytes(String input) {
    final list = <int>[];
    for (var rune in input.runes) {
      if (rune >= 0x10000) {
        rune -= 0x10000;
        final int firstWord = (rune >> 10) + 0xD800;
        list.add(firstWord >> 8);
        list.add(firstWord & 0xFF);
        final int secondWord = (rune & 0x3FF) + 0xDC00;
        list.add(secondWord >> 8);
        list.add(secondWord & 0xFF);
      } else {
        list.add(rune >> 8);
        list.add(rune & 0xFF);
      }
    }
    final Uint8List bytes = Uint8List.fromList(list);

    return bytes;
  }

  static String bytesToString(Uint8List bytes) {
    // Bytes to UTF-16 string
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < bytes.length;) {
      final int firstWord = (bytes[i] << 8) + bytes[i + 1];
      if (0xD800 <= firstWord && firstWord <= 0xDBFF) {
        final int secondWord = (bytes[i + 2] << 8) + bytes[i + 3];
        buffer.writeCharCode(
            ((firstWord - 0xD800) << 10) + (secondWord - 0xDC00) + 0x10000);
        i += 4;
      } else {
        buffer.writeCharCode(firstWord);
        i += 2;
      }
    }
    return buffer.toString();
  }
}
