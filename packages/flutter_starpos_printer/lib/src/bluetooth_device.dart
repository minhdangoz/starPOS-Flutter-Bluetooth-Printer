part of flutter_blue_plus;

class BluetoothDevice {
  BluetoothDevice({
    required this.remoteId,
  });
  BluetoothDevice.fromProto(BmBluetoothDevice p)
      : remoteId = DeviceIdentifier(p.remoteId);

  /// Create a device from an id
  ///   - to connect, this device must have been discovered by your app in a previous scan
  ///   - iOS uses 128-bit uuids the remoteId, e.g. e006b3a7-ef7b-4980-a668-1f8005f84383
  ///   - Android uses 48-bit mac addresses as the remoteId, e.g. 06:E5:28:3B:FD:E0
  BluetoothDevice.fromId(String remoteId)
      : remoteId = DeviceIdentifier(remoteId);
  final DeviceIdentifier remoteId;

  /// platform name
  /// - this name is kept track of by the platform
  /// - this name usually persist between app restarts
  /// - iOS: after you connect, iOS uses the GAP name characteristic (0x2A00)
  ///        if it exists. Otherwise iOS use the advertised name.
  /// - Android: always uses the advertised name
  String get platformName => FlutterBluePlus._platformNames[remoteId] ?? '';

  /// Advertised Named
  ///  - the is the name advertised by the device during scanning
  ///  - it is only available after you scan with FlutterBluePlus
  ///  - it is cleared when the app restarts.
  ///  - not all devices advertise a name
  String get advName => FlutterBluePlus._advNames[remoteId] ?? '';

  /// Returns true if this device currently connected to your app
  bool get isConnected {
    if (FlutterBluePlus._connectionStates[remoteId] == null) {
      return false;
    } else {
      final state =
          FlutterBluePlus._connectionStates[remoteId]!.connectionState;
      return state == BmConnectionStateEnum.connected;
    }
  }

  /// Establishes a connection to the Bluetooth Device.
  ///   [timeout] if timeout occurs, cancel the connection request and throw exception
  ///   [mtu] Android only. Request a larger mtu right after connection, if set.
  ///   [autoConnect] reconnect whenever the device is found
  ///      - if true, this function always returns immediately.
  ///      - you must listen to `connectionState` to know when connection occurs.
  ///      - auto connect is turned off by calling `disconnect`
  ///      - auto connect results in a slower connection process compared to a direct connection
  ///        because it relies on the internal scheduling of background scans.
  Future<void> connect({
    Duration timeout = const Duration(seconds: 35),
    int? mtu = 512,
    bool autoConnect = false,
  }) async {
    // If you hit this assert, you must set `mtu:null`, i.e `device.connect(mtu:null, autoConnect:true)`
    // and you'll have to call `requestMtu` yourself. `autoConnect` is not compatibile with `mtu`.
    assert(
        (mtu == null) || !autoConnect, 'mtu and auto connect are incompatible');

    // make sure no one else is calling disconnect
    final _Mutex dmtx = _MutexFactory.getMutexForKey('disconnect');
    bool dtook = await dmtx.take();

    // Only allow a single ble operation to be underway at a time
    final _Mutex mtx = _MutexFactory.getMutexForKey('global');
    await mtx.take();

    try {
      final request = BmConnectRequest(
        remoteId: remoteId.str,
        autoConnect: autoConnect,
      );

      final responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == 'OnConnectionStateChanged')
          .map((m) => m.arguments)
          .map((args) => BmConnectionStateResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId.str);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      final Future<BmConnectionStateResponse> futureState =
          responseStream.first;

      // invoke
      final bool changed =
          await FlutterBluePlus._invokeMethod('connect', request.toMap());

      // we return the disconnect mutex now so that this
      // connection attempt can be canceled by calling disconnect
      dtook = dmtx.give();

      print('--> connect changed = $changed');

      // only wait for connection if we weren't already connected
      // if (changed && !autoConnect) {
      //   BmConnectionStateResponse response = await futureState
      //       .fbpEnsureAdapterIsOn("connect")
      //       .fbpTimeout(timeout.inSeconds, "connect")
      //       .catchError((e) async {
      //     if (e is FlutterBluePlusException &&
      //         e.code == FbpErrorCode.timeout.index) {
      //       // await FlutterBluePlus._invokeMethod('disconnect', remoteId.str); // cancel connection attempt
      //       print('--> ensure adapter is on timeout');
      //     }
      //     // throw e;
      //   });

      //   if (response.connectionState == BmConnectionStateEnum.connected) {
      //     print('--> on connect > response state connected');
      //   }

      //   //   // failure?
      //   if (response.connectionState == BmConnectionStateEnum.disconnected) {
      //     print('--> on connect > response state disconnected');
      //     if (response.disconnectReasonCode == 23789258) {
      //       print('--> on connect > connection canceled');
      //       throw FlutterBluePlusException(ErrorPlatform.fbp, "connect",
      //           FbpErrorCode.connectionCanceled.index, "connection canceled");
      //     } else {
      //       print('--> on connect > _nativeError');
      //       throw FlutterBluePlusException(_nativeError, "connect",
      //           response.disconnectReasonCode, response.disconnectReasonString);
      //     }
      //   }
      // }
    } finally {
      if (dtook) {
        dmtx.give();
      }
      mtx.give();
    }
  }

  Future<bool> initPrinter() async {
    final bool result = await FlutterBluePlus._invokeMethod('initPrinter');

    print('--> initPrinter result = $result');

    return result;
  }

  Future<bool> setPrinterDarkness(int value) async {
    final bool result =
        await FlutterBluePlus._invokeMethod('setPrinterDarkness', value);

    print('--> setPrinterDarkness result = $result');

    return result;
  }

  Future<bool> getPrintQRCode(
    String code,
    int modulesize,
    int errorlevel,
  ) async {
    final data = {
      'code': code,
      'modulesize': modulesize,
      'errorlevel': errorlevel,
    };
    final bool result =
        await FlutterBluePlus._invokeMethod('getPrintQRCode', data);

    print('--> getPrintQRCode result = $result');

    return result;
  }

  Future<bool> getPrintDoubleQRCode(
    String code1,
    String code2,
    int modulesize,
    int errorlevel,
  ) async {
    final data = {
      'code1': code1,
      'code2': code2,
      'modulesize': modulesize,
      'errorlevel': errorlevel,
    };
    final bool result =
        await FlutterBluePlus._invokeMethod('getPrintDoubleQRCode', data);

    print('--> getPrintDoubleQRCode result = $result');

    return result;
  }

  Future<bool> getPrintZXingQRCode(
    String code,
    int size,
  ) async {
    final data = {
      'code': code,
      'size': size,
    };
    final bool result =
        await FlutterBluePlus._invokeMethod('getPrintZXingQRCode', data);

    print('--> getPrintZXingQRCode result = $result');

    return result;
  }

  /// String data,
  /// encode "UPC-A", "UPC-E", "EAN13", "EAN8", "CODE39", "ITF", "CODABAR",
  /// "CODE93", "CODE128A", "CODE128B", "CODE128C"
  /// int symbology
  /// int height
  /// int width
  /// HRI position: int textposition: 0 null, 1 above barcode, 2 underneath, 3
  /// above & underneath
  ///
  Future<bool> getPrintBarCode(
    String code,
    int encode,
    int height,
    int width,
    int position,
  ) async {
    final data = {
      'code': code,
      'encode': encode,
      'height': height,
      'width': width,
      'position': position,
    };
    final bool result =
        await FlutterBluePlus._invokeMethod('getPrintBarCode', data);

    print('--> getPrintBarCode result = $result');

    return result;
  }

  Future<bool> sendData(Uint8List? data) async {
    final bool result = await FlutterBluePlus._invokeMethod('sendData', data);

    print('--> send data result = $result');

    return result;
  }

  Future<bool> printText(String text, String charset) async {
    final data = {
      'text': text,
      'charset': charset,
    };
    final bool result = await FlutterBluePlus._invokeMethod('printText', data);

    print('--> send print text result = $result');

    return result;
  }

  ///
  /// WARNING: this function might not work perfectly, try printRasterBitmap instead
  ///
  Future<bool> printBitmap(Uint8List? data) async {
    final bool result =
        await FlutterBluePlus._invokeMethod('printBitmap', data);

    print('--> print bitmap result = $result');
    return result;
  }

  Future<bool> printRasterBitmap(Uint8List? image, int? mode) async {
    final data = {
      'data': image,
      'mode': mode,
    };

    final bool result =
        await FlutterBluePlus._invokeMethod('printRasterBitmap', data);

    print('--> print printRasterBitmap result = $result');
    return result;
  }

  /*
	* Select bit-image mode
	* m	Mode
		0	8 Dot single density
		1	8 Dot double density
		32	24 Dot single density
		33	24 Dot double density
	* */
  Future<bool> printBitmapMode(int width) async {
    final bool result =
        await FlutterBluePlus._invokeMethod('printBitmapMode', width);

    print('--> print printRasterBitmap result = $result');
    return result;
  }

  Future<bool> printByteBitmap(Uint8List? data) async {
    final bool result =
        await FlutterBluePlus._invokeMethod('printByteBitmap', data);

    print('--> print printByteBitmap result = $result');
    return result;
  }

  Future<bool> printNextLine(int line) async {
    final bool result =
        await FlutterBluePlus._invokeMethod('printNextLine', line);

    print('--> nextline result = $result');
    return result;
  }

  Future<bool> partialCut() async {
    final bool result = await FlutterBluePlus._invokeMethod('partialCut');

    print('--> nextline result = $result');
    return result;
  }

  Future<bool> fullCut() async {
    final bool result = await FlutterBluePlus._invokeMethod('fullCut');

    print('--> nextline result = $result');
    return result;
  }

  Future<bool> setDefaultLineSpace() async {
    final bool result =
        await FlutterBluePlus._invokeMethod('setDefaultLineSpace');

    print('--> setDefaultLineSpace result = $result');
    return result;
  }

  Future<bool> setLineSpace(int height) async {
    final bool result =
        await FlutterBluePlus._invokeMethod('setLineSpace', height);

    print('--> setLineSpace result = $result');
    return result;
  }

  Future<bool> underlineWithOneDotWidthOn() async {
    final bool result =
        await FlutterBluePlus._invokeMethod('underlineWithOneDotWidthOn');

    print('--> underlineWithOneDotWidthOn result = $result');
    return result;
  }

  Future<bool> underlineWithTwoDotWidthOn() async {
    final bool result =
        await FlutterBluePlus._invokeMethod('underlineWithTwoDotWidthOn');

    print('--> underlineWithTwoDotWidthOn result = $result');
    return result;
  }

  Future<bool> underlineOff() async {
    final bool result = await FlutterBluePlus._invokeMethod('underlineOff');

    print('--> underlineOff result = $result');
    return result;
  }

  Future<bool> boldOn() async {
    final bool result = await FlutterBluePlus._invokeMethod('boldOn');

    print('--> boldOn result = $result');
    return result;
  }

  Future<bool> b68boldOn() async {
    final bool result = await FlutterBluePlus._invokeMethod('b68boldOn');

    print('--> b68boldOn result = $result');
    return result;
  }

  Future<bool> boldOff() async {
    final bool result = await FlutterBluePlus._invokeMethod('boldOff');

    print('--> boldOff result = $result');
    return result;
  }

  Future<bool> alignLeft() async {
    final bool result = await FlutterBluePlus._invokeMethod('alignLeft');

    print('--> alignLeft result = $result');
    return result;
  }

  Future<bool> alignRight() async {
    final bool result = await FlutterBluePlus._invokeMethod('alignRight');

    print('--> alignRight result = $result');
    return result;
  }

  Future<bool> alignCenter() async {
    final bool result = await FlutterBluePlus._invokeMethod('alignCenter');

    print('--> alignCenter result = $result');
    return result;
  }

  Future<bool> singleByte() async {
    final bool result = await FlutterBluePlus._invokeMethod('singleByte');

    print('--> singleByte result = $result');
    return result;
  }

  Future<bool> singleByteOff() async {
    final bool result = await FlutterBluePlus._invokeMethod('singleByteOff');

    print('--> singleByteOff result = $result');
    return result;
  }

  Future<bool> setCodeSystem(Uint8List charset) async {
    final bool result =
        await FlutterBluePlus._invokeMethod('setCodeSystem', charset);

    print('--> setCodeSystem result = $result');
    return result;
  }

  Future<bool> setCodeSystemSingle(Uint8List charset) async {
    final bool result =
        await FlutterBluePlus._invokeMethod('setCodeSystemSingle', charset);

    print('--> setCodeSystemSingle result = $result');
    return result;
  }

  /// Cancels connection to the Bluetooth Device
  ///   - [queue] If true, this disconnect request will be executed after all other operations complete.
  ///     If false, this disconnect request will be executed right now, i.e. skipping to the front
  ///     of the fbp operation queue, which is useful to cancel an in-progress connection attempt.
  Future<void> disconnect({int timeout = 35, bool queue = true}) async {
    // Only allow a single disconnect operation at a time
    final _Mutex dtx = _MutexFactory.getMutexForKey('disconnect');
    await dtx.take();

    // Only allow a single ble operation to be underway at a time?
    final _Mutex mtx = _MutexFactory.getMutexForKey('global');
    if (queue) {
      await mtx.take();
    }

    try {
      final responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == 'OnConnectionStateChanged')
          .map((m) => m.arguments)
          .map((args) => BmConnectionStateResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId.str)
          .where(
              (p) => p.connectionState == BmConnectionStateEnum.disconnected);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      final Future<BmConnectionStateResponse> futureState =
          responseStream.first;

      // invoke
      final bool changed =
          await FlutterBluePlus._invokeMethod('disconnect', remoteId.str);

      // only wait for disconnection if weren't already disconnected
      if (changed) {
        await futureState
            .fbpEnsureAdapterIsOn('disconnect')
            .fbpTimeout(timeout, 'disconnect');
      }
    } finally {
      dtx.give();
      if (queue) {
        mtx.give();
      }
    }
  }

  /// The most recent disconnection reason
  DisconnectReason? get disconnectReason {
    if (FlutterBluePlus._connectionStates[remoteId] == null) {
      return null;
    }
    final int? code =
        FlutterBluePlus._connectionStates[remoteId]!.disconnectReasonCode;
    final String? description =
        FlutterBluePlus._connectionStates[remoteId]!.disconnectReasonString;
    return DisconnectReason(_nativeError, code, description);
  }

  /// The current connection state *of our app* to the device
  Stream<BluetoothConnectionState> get connectionState {
    // initial value - Note: we only care about the current connection state of
    // *our* app, which is why we can use our cached value, or assume disconnected
    BluetoothConnectionState initialValue =
        BluetoothConnectionState.disconnected;
    if (FlutterBluePlus._connectionStates[remoteId] != null) {
      initialValue = _bmToConnectionState(
          FlutterBluePlus._connectionStates[remoteId]!.connectionState);
    }
    return FlutterBluePlus._methodStream.stream
        .where((m) => m.method == 'OnConnectionStateChanged')
        .map((m) => m.arguments)
        .map((args) => BmConnectionStateResponse.fromMap(args))
        .where((p) => p.remoteId == remoteId.str)
        .map((p) => _bmToConnectionState(p.connectionState))
        .newStreamWithInitialValue(initialValue);
  }

  /// Request connection priority update (Android only)
  Future<void> requestConnectionPriority(
      {required ConnectionPriority connectionPriorityRequest}) async {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp,
          'requestConnectionPriority',
          FbpErrorCode.androidOnly.index,
          'android-only');
    }

    // check connected
    if (isConnected == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.fbp,
          'requestConnectionPriority',
          FbpErrorCode.deviceIsDisconnected.index,
          'device is not connected');
    }

    final request = BmConnectionPriorityRequest(
      remoteId: remoteId.str,
      connectionPriority: _bmFromConnectionPriority(connectionPriorityRequest),
    );

    // invoke
    await FlutterBluePlus._invokeMethod(
        'requestConnectionPriority', request.toMap());
  }

  /// Force the bonding popup to show now (Android Only)
  /// Note! calling this is usually not necessary!! The platform does it automatically.
  Future<void> createBond({int timeout = 90}) async {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(ErrorPlatform.fbp, 'createBond',
          FbpErrorCode.androidOnly.index, 'android-only');
    }

    // check connected
    if (isConnected == false) {
      throw FlutterBluePlusException(ErrorPlatform.fbp, 'createBond',
          FbpErrorCode.deviceIsDisconnected.index, 'device is not connected');
    }

    // Only allow a single ble operation to be underway at a time
    final _Mutex mtx = _MutexFactory.getMutexForKey('global');
    await mtx.take();

    try {
      final responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == 'OnBondStateChanged')
          .map((m) => m.arguments)
          .map((args) => BmBondStateResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId.str)
          .where((p) => p.bondState != BmBondStateEnum.bonding);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      final Future<BmBondStateResponse> futureResponse = responseStream.first;

      // invoke
      final bool changed =
          await FlutterBluePlus._invokeMethod('createBond', remoteId.str);

      // only wait for 'bonded' if we weren't already bonded
      if (changed) {
        final BmBondStateResponse bs = await futureResponse
            .fbpEnsureAdapterIsOn('createBond')
            .fbpEnsureDeviceIsConnected(this, 'createBond')
            .fbpTimeout(timeout, 'createBond');

        // success?
        if (bs.bondState != BmBondStateEnum.bonded) {
          throw FlutterBluePlusException(
              ErrorPlatform.fbp,
              'createBond',
              FbpErrorCode.createBondFailed.hashCode,
              'Failed to create bond. ${bs.bondState}');
        }
      }
    } finally {
      mtx.give();
    }
  }

  /// Remove bond (Android Only)
  Future<void> removeBond({int timeout = 30}) async {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(ErrorPlatform.fbp, 'removeBond',
          FbpErrorCode.androidOnly.index, 'android-only');
    }

    // Only allow a single ble operation to be underway at a time
    final _Mutex mtx = _MutexFactory.getMutexForKey('global');
    await mtx.take();

    try {
      final responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == 'OnBondStateChanged')
          .map((m) => m.arguments)
          .map((args) => BmBondStateResponse.fromMap(args))
          .where((p) => p.remoteId == remoteId.str)
          .where((p) => p.bondState != BmBondStateEnum.bonding);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      final Future<BmBondStateResponse> futureResponse = responseStream.first;

      // invoke
      final bool changed =
          await FlutterBluePlus._invokeMethod('removeBond', remoteId.str);

      // only wait for 'unbonded' state if we weren't already unbonded
      if (changed) {
        final BmBondStateResponse bs = await futureResponse
            .fbpEnsureAdapterIsOn('removeBond')
            .fbpEnsureDeviceIsConnected(this, 'removeBond')
            .fbpTimeout(timeout, 'removeBond');

        // success?
        if (bs.bondState != BmBondStateEnum.none) {
          throw FlutterBluePlusException(
              ErrorPlatform.fbp,
              'createBond',
              FbpErrorCode.removeBondFailed.hashCode,
              'Failed to remove bond. ${bs.bondState}');
        }
      }
    } finally {
      mtx.give();
    }
  }

  /// Get the current bondState of the device (Android Only)
  Stream<BluetoothBondState> get bondState async* {
    // check android
    if (Platform.isAndroid == false) {
      throw FlutterBluePlusException(ErrorPlatform.fbp, 'bondState',
          FbpErrorCode.androidOnly.index, 'android-only');
    }

    // get current state if needed
    if (FlutterBluePlus._bondStates[remoteId] == null) {
      final val = await FlutterBluePlus._methods
          .invokeMethod('getBondState', remoteId.str)
          .then((args) => BmBondStateResponse.fromMap(args));
      // update _bondStates if it is still null after the await
      if (FlutterBluePlus._bondStates[remoteId] == null) {
        FlutterBluePlus._bondStates[remoteId] = val;
      }
    }

    yield* FlutterBluePlus._methodStream.stream
        .where((m) => m.method == 'OnBondStateChanged')
        .map((m) => m.arguments)
        .map((args) => BmBondStateResponse.fromMap(args))
        .where((p) => p.remoteId == remoteId.str)
        .map((p) => _bmToBondState(p.bondState))
        .newStreamWithInitialValue(
            _bmToBondState(FlutterBluePlus._bondStates[remoteId]!.bondState));
  }

  /// Get the previous bondState of the device (Android Only)
  BluetoothBondState? get prevBondState {
    final b = FlutterBluePlus._bondStates[remoteId]?.prevState;
    return b != null ? _bmToBondState(b) : null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BluetoothDevice &&
          runtimeType == other.runtimeType &&
          remoteId == other.remoteId);

  @override
  int get hashCode => remoteId.hashCode;

  @override
  String toString() {
    return 'BluetoothDevice{'
        'remoteId: $remoteId, '
        'platformName: $platformName, '
        '}';
  }

  @Deprecated('removed. no replacement')
  Stream<bool> get isDiscoveringServices async* {
    yield false;
  }

  @Deprecated('Use createBond() instead')
  Future<void> pair() async => await createBond();

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get id => remoteId;

  @Deprecated('Use platformName instead')
  String get localName => platformName;

  @Deprecated('Use platformName instead')
  String get name => platformName;

  @Deprecated('Use connectionState instead')
  Stream<BluetoothConnectionState> get state => connectionState;

  @Deprecated('removed. no replacement')
  Stream<List<BluetoothService>> get servicesStream async* {
    yield [];
  }

  @Deprecated('removed. no replacement')
  Stream<List<BluetoothService>> get services async* {
    yield [];
  }
}
