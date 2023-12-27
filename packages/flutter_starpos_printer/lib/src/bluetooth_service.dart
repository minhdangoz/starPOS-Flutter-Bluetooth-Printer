part of flutter_blue_plus;

class BluetoothService {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final bool isPrimary;
  final List<BluetoothService> includedServices;

  /// convenience accessor
  Guid get uuid => serviceUuid;

  BluetoothService.fromProto(BmBluetoothService p)
      : remoteId = DeviceIdentifier(p.remoteId),
        serviceUuid = p.serviceUuid,
        isPrimary = p.isPrimary,
        includedServices = p.includedServices
            .map((s) => BluetoothService.fromProto(s))
            .toList();

  @override
  String toString() {
    return 'BluetoothService{'
        'remoteId: $remoteId, '
        'serviceUuid: $serviceUuid, '
        'isPrimary: $isPrimary, '
        'includedServices: $includedServices'
        '}';
  }

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get deviceId => remoteId;
}
