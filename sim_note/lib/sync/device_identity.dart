import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 이 기기의 고유 ID — 앱 설치 시 1회 생성, 이후 영구 보존
class DeviceIdentity {
  static String? _id;

  static Future<String> getId() async {
    if (_id != null) return _id!;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/.simnote_device_id');

    if (await file.exists()) {
      _id = (await file.readAsString()).trim();
    } else {
      _id = const Uuid().v4();
      await file.writeAsString(_id!);
    }
    return _id!;
  }
}
