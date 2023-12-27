import 'dart:typed_data';

class ByteBuffer {
  ByteData _buffer = ByteData(1);
  int _position = 0;

  ByteBuffer(int length) {
    _buffer = ByteData(length);
    _position = 0;
  }

  int get position => _position;

  set position(int newPosition) {
    if (newPosition < 0 || newPosition > _buffer.lengthInBytes) {
      throw RangeError('Invalid position');
    }
    _position = newPosition;
  }

  int get length => _buffer.lengthInBytes;

  void writeUint8(int value) {
    _checkSpace(1);
    _buffer.setUint8(_position, value);
    _position++;
  }

  void writeUint16(int value) {
    _checkSpace(2);
    _buffer.setUint16(_position, value, Endian.big);
    _position += 2;
  }

  void writeUint32(int value) {
    _checkSpace(4);
    _buffer.setUint32(_position, value, Endian.big);
    _position += 4;
  }

  Uint8List toUint8List() {
    return _buffer.buffer.asUint8List();
  }

  void _checkSpace(int size) {
    if (_position + size > _buffer.lengthInBytes) {
      int newLength =
          (_buffer.lengthInBytes * 2).clamp(_position + size, _position);
      ByteData newBuffer = ByteData(newLength);
      newBuffer.buffer.asUint8List().setAll(0, _buffer.buffer.asUint8List());
      _buffer = newBuffer;
    }
  }
}
