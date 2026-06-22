import 'package:shared_preferences/shared_preferences.dart';

class MeshRuntimeSettings {
  final String serviceUuid;
  final String txCharUuid;
  final String rxCharUuid;
  final String hmacSecret;

  const MeshRuntimeSettings({
    required this.serviceUuid,
    required this.txCharUuid,
    required this.rxCharUuid,
    required this.hmacSecret,
  });

  static const MeshRuntimeSettings defaults = MeshRuntimeSettings(
    serviceUuid: '12345678-1234-5678-1234-56789abcdef0',
    txCharUuid: '12345678-1234-5678-1234-56789abcdef1',
    rxCharUuid: '12345678-1234-5678-1234-56789abcdef2',
    hmacSecret: 'gardenergrid-default-mesh-secret',
  );

  MeshRuntimeSettings copyWith({
    String? serviceUuid,
    String? txCharUuid,
    String? rxCharUuid,
    String? hmacSecret,
  }) {
    return MeshRuntimeSettings(
      serviceUuid: serviceUuid ?? this.serviceUuid,
      txCharUuid: txCharUuid ?? this.txCharUuid,
      rxCharUuid: rxCharUuid ?? this.rxCharUuid,
      hmacSecret: hmacSecret ?? this.hmacSecret,
    );
  }
}

class MeshSettingsService {
  static const _serviceUuidKey = 'mesh_service_uuid';
  static const _txCharUuidKey = 'mesh_tx_char_uuid';
  static const _rxCharUuidKey = 'mesh_rx_char_uuid';
  static const _hmacSecretKey = 'mesh_hmac_secret';

  Future<MeshRuntimeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return MeshRuntimeSettings(
      serviceUuid:
          prefs.getString(_serviceUuidKey) ?? MeshRuntimeSettings.defaults.serviceUuid,
      txCharUuid:
          prefs.getString(_txCharUuidKey) ?? MeshRuntimeSettings.defaults.txCharUuid,
      rxCharUuid:
          prefs.getString(_rxCharUuidKey) ?? MeshRuntimeSettings.defaults.rxCharUuid,
      hmacSecret:
          prefs.getString(_hmacSecretKey) ?? MeshRuntimeSettings.defaults.hmacSecret,
    );
  }

  Future<void> save(MeshRuntimeSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serviceUuidKey, settings.serviceUuid);
    await prefs.setString(_txCharUuidKey, settings.txCharUuid);
    await prefs.setString(_rxCharUuidKey, settings.rxCharUuid);
    await prefs.setString(_hmacSecretKey, settings.hmacSecret);
  }
}
