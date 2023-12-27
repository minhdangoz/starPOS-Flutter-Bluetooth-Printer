part of flutter_blue_plus;

class BluetoothEvents {
  Stream<OnConnectionStateChangedEvent> get onConnectionStateChanged {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnConnectionStateChanged")
        .map((m) => m.arguments)
        .map((args) => BmConnectionStateResponse.fromMap(args))
        .map((p) => OnConnectionStateChangedEvent(p));
  }

  Stream<OnNameChangedEvent> get onNameChanged {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnNameChanged")
        .map((m) => m.arguments)
        .map((args) => BmBluetoothDevice.fromMap(args))
        .map((p) => OnNameChangedEvent(p));
  }

  Stream<OnBondStateChangedEvent> get onBondStateChanged {
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnBondStateChanged")
        .map((m) => m.arguments)
        .map((args) => BmBondStateResponse.fromMap(args))
        .map((p) => OnBondStateChangedEvent(p));
  }
}

class FbpError {
  final int errorCode;
  final String errorString;
  ErrorPlatform get platform => _nativeError;
  FbpError(this.errorCode, this.errorString);
}

//
// Event Classes
//

// On Connection State Changed
class OnConnectionStateChangedEvent {
  final BmConnectionStateResponse _response;

  OnConnectionStateChangedEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the new connection state
  BluetoothConnectionState get connectionState =>
      _bmToConnectionState(_response.connectionState);
}

// On Name Changed
class OnNameChangedEvent {
  final BmBluetoothDevice _response;

  OnNameChangedEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the new name
  String? get name => _response.platformName;
}

// On Bond State Changed
class OnBondStateChangedEvent {
  final BmBondStateResponse _response;

  OnBondStateChangedEvent(this._response);

  /// the relevant device
  BluetoothDevice get device => BluetoothDevice.fromId(_response.remoteId);

  /// the new bond state
  BluetoothBondState get bondState => _bmToBondState(_response.bondState);
}
