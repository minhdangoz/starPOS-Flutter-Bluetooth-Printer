part of flutter_blue_plus;

enum BmAdapterStateEnum {
  unknown, // 0
  unavailable, // 1
  unauthorized, // 2
  turningOn, // 3
  on, // 4
  turningOff, // 5
  off, // 6
}

class BmBluetoothAdapterState {
  BmAdapterStateEnum adapterState;

  BmBluetoothAdapterState({required this.adapterState});

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['adapter_state'] = adapterState.index;
    return data;
  }

  factory BmBluetoothAdapterState.fromMap(Map<dynamic, dynamic> json) {
    return BmBluetoothAdapterState(
      adapterState: BmAdapterStateEnum.values[json['adapter_state']],
    );
  }
}

class BmConnectRequest {
  String remoteId;
  bool autoConnect;

  BmConnectRequest({
    required this.remoteId,
    required this.autoConnect,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['auto_connect'] = autoConnect ? 1 : 0;
    return data;
  }
}

class BmBluetoothDevice {
  String remoteId;
  String? platformName;

  BmBluetoothDevice({
    required this.remoteId,
    required this.platformName,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['platform_name'] = platformName;
    return data;
  }

  factory BmBluetoothDevice.fromMap(Map<dynamic, dynamic> json) {
    return BmBluetoothDevice(
      remoteId: json['remote_id'],
      platformName: json['platform_name'],
    );
  }
}

class BmNameChanged {
  String remoteId;
  String name;

  BmNameChanged({
    required this.remoteId,
    required this.name,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['name'] = name;
    return data;
  }

  factory BmNameChanged.fromMap(Map<dynamic, dynamic> json) {
    return BmNameChanged(
      remoteId: json['remote_id'],
      name: json['name'],
    );
  }
}

class BmBluetoothService {
  final String remoteId;
  final Guid serviceUuid;
  bool isPrimary;
  List<BmBluetoothService> includedServices;

  BmBluetoothService({
    required this.serviceUuid,
    required this.remoteId,
    required this.isPrimary,
    required this.includedServices,
  });

  factory BmBluetoothService.fromMap(Map<dynamic, dynamic> json) {
    // convert services
    List<BmBluetoothService> svcs = [];
    for (var v in json['included_services']) {
      svcs.add(BmBluetoothService.fromMap(v));
    }

    return BmBluetoothService(
      serviceUuid: Guid(json['service_uuid']),
      remoteId: json['remote_id'],
      isPrimary: json['is_primary'] != 0,
      includedServices: svcs,
    );
  }
}

enum BmWriteType {
  withResponse,
  withoutResponse,
}

enum BmConnectionStateEnum {
  disconnected, // 0
  connected, // 1
}

class BmConnectionStateResponse {
  final String remoteId;
  final BmConnectionStateEnum connectionState;
  final int? disconnectReasonCode;
  final String? disconnectReasonString;

  BmConnectionStateResponse({
    required this.remoteId,
    required this.connectionState,
    required this.disconnectReasonCode,
    required this.disconnectReasonString,
  });

  factory BmConnectionStateResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmConnectionStateResponse(
      remoteId: json['remote_id'],
      connectionState:
          BmConnectionStateEnum.values[json['connection_state'] as int],
      disconnectReasonCode: json['disconnect_reason_code'],
      disconnectReasonString: json['disconnect_reason_string'],
    );
  }
}

class BmDevicesList {
  final List<BmBluetoothDevice> devices;

  BmDevicesList({required this.devices});

  factory BmDevicesList.fromMap(Map<dynamic, dynamic> json) {
    // convert to BmBluetoothDevice
    List<BmBluetoothDevice> devices = [];
    for (var i = 0; i < json['devices'].length; i++) {
      devices.add(BmBluetoothDevice.fromMap(json['devices'][i]));
    }
    return BmDevicesList(devices: devices);
  }
}

enum BmConnectionPriorityEnum {
  balanced, // 0
  high, // 1
  lowPower, // 2
}

class BmConnectionPriorityRequest {
  final String remoteId;
  final BmConnectionPriorityEnum connectionPriority;

  BmConnectionPriorityRequest({
    required this.remoteId,
    required this.connectionPriority,
  });

  Map<dynamic, dynamic> toMap() {
    final Map<dynamic, dynamic> data = {};
    data['remote_id'] = remoteId;
    data['connection_priority'] = connectionPriority.index;
    return data;
  }
}

enum BmBondStateEnum {
  none, // 0
  bonding, // 1
  bonded, // 2
}

class BmBondStateResponse {
  final String remoteId;
  final BmBondStateEnum bondState;
  final BmBondStateEnum? prevState;

  BmBondStateResponse({
    required this.remoteId,
    required this.bondState,
    required this.prevState,
  });

  factory BmBondStateResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmBondStateResponse(
      remoteId: json['remote_id'],
      bondState: BmBondStateEnum.values[json['bond_state']],
      prevState: json['prev_state'] != null
          ? BmBondStateEnum.values[json['prev_state']]
          : null,
    );
  }
}

// BmTurnOnResponse
class BmTurnOnResponse {
  bool userAccepted;

  BmTurnOnResponse({
    required this.userAccepted,
  });

  factory BmTurnOnResponse.fromMap(Map<dynamic, dynamic> json) {
    return BmTurnOnResponse(
      userAccepted: json['user_accepted'],
    );
  }
}
