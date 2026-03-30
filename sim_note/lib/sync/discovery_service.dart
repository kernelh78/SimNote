import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'device_identity.dart';

/// UDP 브로드캐스트 방식으로 같은 Wi-Fi 안의 SimNote 기기를 탐색
///
/// 작동 방식:
///   - 3초마다 255.255.255.255로 "나 여기 있어" 패킷을 전송
///   - 같은 포트를 수신해서 다른 기기의 패킷을 감지
class DiscoveryService {
  static const int discoveryPort = 8766;
  static const int servicePort = 8765; // 3단계 데이터 전송용
  static const Duration _broadcastInterval = Duration(seconds: 3);

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  final _controller = StreamController<DiscoveryMessage>.broadcast();

  String? _localIp;

  /// 이 기기의 Wi-Fi IP 주소 반환
  /// 우선순위: wlan0(안드로이드) → 192.168.x.x → 10.x.x.x → 나머지 사설 IP
  Future<String> getLocalIp() async {
    if (_localIp != null) return _localIp!;

    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );

    String? best;

    for (final iface in interfaces) {
      final name = iface.name.toLowerCase();
      if (_isVirtualInterface(name)) continue;

      for (final addr in iface.addresses) {
        if (addr.isLoopback) continue;
        final ip = addr.address;

        if (name == 'wlan0') {
          _localIp = ip;
          return ip; // 안드로이드 Wi-Fi — 최우선
        }
        if (_isCommonPrivate(ip)) best ??= ip;
      }
    }

    _localIp = best ?? '127.0.0.1';
    return _localIp!;
  }

  /// 브로드캐스트 송신 + 수신 시작. 발견 이벤트를 스트림으로 반환
  Future<Stream<DiscoveryMessage>> start() async {
    await stop();

    final localIp = await getLocalIp();
    final deviceName = Platform.localHostname;
    final platform = Platform.operatingSystem;
    final deviceId = await DeviceIdentity.getId();

    // UDP 소켓 열기
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      _socket!.broadcastEnabled = true;
      debugPrint('[SimNote] UDP 소켓 바인딩 성공: $localIp:$discoveryPort');
    } catch (e) {
      debugPrint('[SimNote] UDP 소켓 바인딩 실패: $e');
      rethrow;
    }

    // 수신 리스너
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = _socket?.receive();
      if (dg == null) return;
      final raw = utf8.decode(dg.data);
      debugPrint('[SimNote] 수신: $raw (from ${dg.address.address})');
      final msg = _parse(raw);
      if (msg != null && msg.ip != localIp) {
        _controller.add(msg);
      }
    });

    // 서브넷 브로드캐스트 주소 계산 (192.168.0.x → 192.168.0.255)
    final broadcastAddr = _subnetBroadcast(localIp);
    debugPrint('[SimNote] 브로드캐스트 대상: $broadcastAddr');

    // 주기적 브로드캐스트 송신
    void broadcast() {
      final payload = jsonEncode({
        'app': 'simnote',
        'name': deviceName,
        'ip': localIp,
        'platform': platform,
        'port': servicePort,
        'deviceId': deviceId,
      });
      final data = utf8.encode(payload);
      try {
        // 서브넷 브로드캐스트 + 제한 브로드캐스트 둘 다 전송
        _socket?.send(data, InternetAddress(broadcastAddr), discoveryPort);
        _socket?.send(data, InternetAddress('255.255.255.255'), discoveryPort);
        debugPrint('[SimNote] 브로드캐스트 전송: $deviceName @ $localIp');
      } catch (e) {
        debugPrint('[SimNote] 브로드캐스트 전송 실패: $e');
      }
    }

    broadcast(); // 즉시 한 번 전송
    _broadcastTimer = Timer.periodic(_broadcastInterval, (_) => broadcast());

    return _controller.stream;
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _socket?.close();
    _socket = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  // ── 내부 헬퍼 ───────────────────────────────────────────

  DiscoveryMessage? _parse(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['app'] != 'simnote') return null;
      return DiscoveryMessage(
        name:     map['name']     as String,
        ip:       map['ip']       as String,
        platform: map['platform'] as String,
        port:     map['port']     as int,
        deviceId: map['deviceId'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// 192.168.0.5 → 192.168.0.255 (서브넷 /24 가정)
  String _subnetBroadcast(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) return '${parts[0]}.${parts[1]}.${parts[2]}.255';
    return '255.255.255.255';
  }

  bool _isVirtualInterface(String name) =>
      name.contains('tun') ||
      name.contains('tap') ||
      name.contains('vpn') ||
      name.contains('docker') ||
      name.contains('bridge') ||
      name.contains('vmnet');

  bool _isCommonPrivate(String ip) {
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('10.')) return true;
    final parts = ip.split('.');
    if (parts.length == 4 && parts[0] == '172') {
      final second = int.tryParse(parts[1]) ?? 0;
      if (second >= 16 && second <= 31) return true;
    }
    return false;
  }
}

class DiscoveryMessage {
  final String name;
  final String ip;
  final String platform;
  final int    port;
  final String deviceId;

  const DiscoveryMessage({
    required this.name,
    required this.ip,
    required this.platform,
    required this.port,
    required this.deviceId,
  });
}
