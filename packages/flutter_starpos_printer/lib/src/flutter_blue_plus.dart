part of flutter_blue_plus;

class FlutterBluePlus {
  ///////////////////
  //  Internal
  //

  static bool _initialized = false;

  /// native platform channel
  static final MethodChannel _methods =
      const MethodChannel('starpos_bluetooth_printer/methods');

  /// a broadcast stream version of the MethodChannel
  // ignore: close_sinks
  static final StreamController<MethodCall> _methodStream =
      StreamController.broadcast();

  // always keep track of these device variables
  static final Map<DeviceIdentifier, BmConnectionStateResponse>
      _connectionStates = {};
  static final Map<DeviceIdentifier, BmBondStateResponse> _bondStates = {};
  static final Map<DeviceIdentifier, String> _platformNames = {};
  static final Map<DeviceIdentifier, String> _advNames = {};

  /// the last known adapter state
  static BmAdapterStateEnum? _adapterStateNow;

  /// FlutterBluePlus log level
  static LogLevel _logLevel = LogLevel.debug;
  static bool _logColor = true;

  ////////////////////
  //  Public
  //

  static LogLevel get logLevel => _logLevel;

  /// Checks whether the hardware supports Bluetooth
  static Future<bool> get isSupported async =>
      await _invokeMethod('isSupported');

  /// The current adapter state
  static BluetoothAdapterState get adapterStateNow => _adapterStateNow != null
      ? _bmToAdapterState(_adapterStateNow!)
      : BluetoothAdapterState.unknown;

  /// Return the friendly Bluetooth name of the local Bluetooth adapter
  static Future<String> get adapterName async =>
      await _invokeMethod('getAdapterName');

  /// Get access to all device event streams
  static final BluetoothEvents events = BluetoothEvents();

  /// Turn on Bluetooth (Android only),
  static Future<void> turnOn({int timeout = 60}) async {
    var responseStream = FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnTurnOnResponse")
        .map((m) => m.arguments)
        .map((args) => BmTurnOnResponse.fromMap(args));

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BmTurnOnResponse> futureResponse = responseStream.first;

    // invoke
    bool changed = await _invokeMethod('turnOn');

    // only wait if bluetooth was off
    if (changed) {
      // wait for response
      BmTurnOnResponse response =
          await futureResponse.fbpTimeout(timeout, "turnOn");

      // check response
      if (response.userAccepted == false) {
        throw FlutterBluePlusException(ErrorPlatform.fbp, "turnOn",
            FbpErrorCode.userRejected.index, "user rejected");
      }

      // wait for adapter to turn on
      await adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first
          .fbpTimeout(timeout, "turnOn");
    }
  }

  /// Gets the current state of the Bluetooth module
  static Stream<BluetoothAdapterState> get adapterState async* {
    // get current state if needed
    if (_adapterStateNow == null) {
      BmAdapterStateEnum val = await _invokeMethod('getAdapterState')
          .then((args) => BmBluetoothAdapterState.fromMap(args).adapterState);
      // update _adapterStateNow if it is still null after the await
      if (_adapterStateNow == null) {
        _adapterStateNow = val;
      }
    }

    yield* FlutterBluePlus._methodStream.stream
        .where((m) => m.method == "OnAdapterStateChanged")
        .map((m) => m.arguments)
        .map((args) => BmBluetoothAdapterState.fromMap(args))
        .map((s) => _bmToAdapterState(s.adapterState))
        .newStreamWithInitialValue(_bmToAdapterState(_adapterStateNow!));
  }

  /// Retrieve a list of devices currently connected to your app
  static List<BluetoothDevice> get connectedDevices {
    var copy = Map<DeviceIdentifier, BmConnectionStateResponse>.from(
        _connectionStates);
    copy.removeWhere((key, value) =>
        value.connectionState == BmConnectionStateEnum.disconnected);
    return copy.values
        .map((v) => BluetoothDevice(remoteId: DeviceIdentifier(v.remoteId)))
        .toList();
  }

  /// Retrieve a list of bonded devices (Android only)
  static Future<List<BluetoothDevice>> get bondedDevices async {
    BmDevicesList response = await _invokeMethod('getBondedDevices')
        .then((args) => BmDevicesList.fromMap(args));
    for (BmBluetoothDevice device in response.devices) {
      if (device.platformName != null) {
        _platformNames[DeviceIdentifier(device.remoteId)] =
            device.platformName!;
      }
    }
    return response.devices.map((d) => BluetoothDevice.fromProto(d)).toList();
  }

  /// Sets the internal FlutterBlue log level
  static void setLogLevel(LogLevel level, {color = true}) async {
    _logLevel = level;
    _logColor = color;
    await _invokeMethod('setLogLevel', level.index);
  }

  static Future<dynamic> _initFlutterBluePlus() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    // set platform method handler
    _methods.setMethodCallHandler(_methodCallHandler);

    // hot restart
    if ((await _methods.invokeMethod('flutterHotRestart')) != 0) {
      await Future.delayed(Duration(milliseconds: 50));
      while ((await _methods.invokeMethod('connectedCount')) != 0) {
        await Future.delayed(Duration(milliseconds: 50));
      }
    }
  }

  static Future<dynamic> _methodCallHandler(MethodCall call) async {
    // log result
    if (logLevel == LogLevel.verbose) {
      String func = '[[ ${call.method} ]]';
      String result = call.arguments.toString();
      func = _logColor ? _black(func) : func;
      result = _logColor ? _brown(result) : result;
      print("[FBP] $func result: $result");
    }

    // keep track of adapter states
    if (call.method == "OnAdapterStateChanged") {
      BmBluetoothAdapterState r =
          BmBluetoothAdapterState.fromMap(call.arguments);
      _adapterStateNow = r.adapterState;
    }

    // keep track of connection states
    if (call.method == "OnConnectionStateChanged") {
      BmConnectionStateResponse r =
          BmConnectionStateResponse.fromMap(call.arguments);
      var remoteId = DeviceIdentifier(r.remoteId);
      _connectionStates[remoteId] = r;
      if (r.connectionState == BmConnectionStateEnum.disconnected) {
        // to make FBP easier to use, we purposely do not clear knownServices,
        // otherwise `servicesList` would be annoying to use.
        // We also don't clear the `bondState` cache for faster performance.
      }
    }

    // keep track of device name
    if (call.method == "OnNameChanged") {
      BmNameChanged device = BmNameChanged.fromMap(call.arguments);
      if (Platform.isMacOS || Platform.isIOS) {
        // iOS & macOS internally use the name changed callback for the platform name
        _platformNames[DeviceIdentifier(device.remoteId)] = device.name;
      }
    }

    // keep track of bond state
    if (call.method == "OnBondStateChanged") {
      BmBondStateResponse r = BmBondStateResponse.fromMap(call.arguments);
      _bondStates[DeviceIdentifier(r.remoteId)] = r;
    }

    _methodStream.add(call);
  }

  /// invoke a platform method
  static Future<dynamic> _invokeMethod(String method,
      [dynamic arguments]) async {
    // return value
    dynamic out;

    // only allow 1 invocation at a time (guarentees that hot restart finishes)
    _Mutex mtx = _MutexFactory.getMutexForKey("invokeMethod");
    await mtx.take();

    try {
      // initialize
      _initFlutterBluePlus();

      // log args
      if (logLevel == LogLevel.verbose) {
        String func = '<$method>';
        String args = arguments.toString();
        func = _logColor ? _black(func) : func;
        args = _logColor ? _magenta(args) : args;
        print("[FBP] $func args: $args");
      }

      // invoke
      out = await _methods.invokeMethod(method, arguments);

      // log result
      if (logLevel == LogLevel.verbose) {
        String func = '<$method>';
        String result = out.toString();
        func = _logColor ? _black(func) : func;
        result = _logColor ? _brown(result) : result;
        print("[FBP] $func result: $result");
      }
    } finally {
      mtx.give();
    }

    return out;
  }

  /// Turn off Bluetooth (Android only),
  @Deprecated('Deprecated in Android SDK 33 with no replacement')
  static Future<void> turnOff({int timeout = 10}) async {
    Stream<BluetoothAdapterState> responseStream =
        adapterState.where((s) => s == BluetoothAdapterState.off);

    // Start listening now, before invokeMethod, to ensure we don't miss the response
    Future<BluetoothAdapterState> futureResponse = responseStream.first;

    // invoke
    await _invokeMethod('turnOff');

    // wait for response
    await futureResponse.fbpTimeout(timeout, "turnOff");
  }

  /// Checks if Bluetooth functionality is turned on
  @Deprecated('Use adapterState.first == BluetoothAdapterState.on instead')
  static Future<bool> get isOn async =>
      await adapterState.first == BluetoothAdapterState.on;

  @Deprecated('Use adapterName instead')
  static Future<String> get name => adapterName;

  @Deprecated('Use adapterState instead')
  static Stream<BluetoothAdapterState> get state => adapterState;

  @Deprecated('No longer needed, remove this from your code')
  static void get instance => null;

  @Deprecated('Use isSupported instead')
  static Future<bool> get isAvailable async => await isSupported;
}

/// Log levels for FlutterBlue
enum LogLevel {
  none, //0
  error, // 1
  warning, // 2
  info, // 3
  debug, // 4
  verbose, //5
}

class DeviceIdentifier {
  final String str;
  const DeviceIdentifier(this.str);

  @override
  String toString() => str;

  @override
  int get hashCode => str.hashCode;

  @override
  bool operator ==(other) =>
      other is DeviceIdentifier && _compareAsciiLowerCase(str, other.str) == 0;

  @Deprecated('Use str instead')
  String get id => str;
}

enum ErrorPlatform {
  fbp,
  android,
  apple,
}

final ErrorPlatform _nativeError = (() {
  if (Platform.isAndroid) {
    return ErrorPlatform.android;
  } else {
    return ErrorPlatform.apple;
  }
})();

enum FbpErrorCode {
  success,
  timeout,
  androidOnly,
  applePlatformOnly,
  createBondFailed,
  removeBondFailed,
  deviceIsDisconnected,
  serviceNotFound,
  characteristicNotFound,
  adapterIsOff,
  connectionCanceled,
  userRejected
}

class FlutterBluePlusException implements Exception {
  /// Which platform did the error occur on?
  final ErrorPlatform platform;

  /// Which function failed?
  final String function;

  /// note: depends on platform
  final int? code;

  /// note: depends on platform
  final String? description;

  FlutterBluePlusException(
      this.platform, this.function, this.code, this.description);

  @override
  String toString() {
    String sPlatform = platform.toString().split('.').last;
    return 'FlutterBluePlusException | $function | $sPlatform-code: $code | $description';
  }

  @Deprecated('Use function instead')
  String get errorName => function;

  @Deprecated('Use code instead')
  int? get errorCode => code;

  @Deprecated('Use description instead')
  String? get errorString => description;
}
