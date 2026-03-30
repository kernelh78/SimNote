import 'dart:async';
import 'package:flutter/foundation.dart';
import '../sync/discovery_service.dart';
import '../sync/sync_client.dart';
import '../sync/sync_conflict.dart';
import '../sync/sync_server.dart';
import '../sync/sync_state_store.dart';
import '../sync/trusted_devices.dart';

class DiscoveredDevice {
  final String name;
  final String ip;
  final String platform;
  final int    port;
  final String deviceId;
  final DateTime lastSeen;
  final bool isTrusted;

  const DiscoveredDevice({
    required this.name,
    required this.ip,
    required this.platform,
    required this.port,
    required this.deviceId,
    required this.lastSeen,
    this.isTrusted = false,
  });

  DiscoveredDevice refreshed() => DiscoveredDevice(
        name: name, ip: ip, platform: platform, port: port,
        deviceId: deviceId, lastSeen: DateTime.now(), isTrusted: isTrusted,
      );

  String get platformLabel {
    switch (platform) {
      case 'android': return '안드로이드';
      case 'macos':   return 'Mac';
      case 'ios':     return 'iPhone';
      case 'windows': return 'Windows';
      default:        return platform;
    }
  }
}

// ── 연결 / 동기화 상태 ──────────────────────────────────────
enum SyncState { idle, connecting, pinDisplay, pinInput, syncing, done, error }

class SyncProvider extends ChangeNotifier {
  final _discovery = DiscoveryService();
  final _server    = SyncServer();

  // 탐색
  List<DiscoveredDevice> discoveredDevices = [];
  bool   isDiscovering = false;
  String? localIp;
  String? discoveryError;

  // 연결/동기화 상태
  SyncState          syncState    = SyncState.idle;
  String?            displayPin;
  String?            connectingTo;
  int                lastSyncCount = 0;
  String?            syncError;
  List<SyncConflict> pendingConflicts = [];

  // 자동 동기화
  bool      autoSyncEnabled = false;
  DateTime? _lastAutoSync;
  static const _autoSyncCooldown = Duration(seconds: 60);

  // PIN 입력 완료를 기다리는 Completer (클라이언트 측)
  Completer<String?>? _pinCompleter;

  StreamSubscription<DiscoveryMessage>? _discoverySub;
  Timer? _cleanupTimer;

  // ── 초기화 ─────────────────────────────────────────────────

  Future<void> start() async {
    autoSyncEnabled = await SyncStateStore.getAutoSync();
    await _startDiscovery();
    await _startServer();
  }

  Future<void> _startDiscovery() async {
    try {
      localIp = await _discovery.getLocalIp();
      isDiscovering = true;
      notifyListeners();

      final stream = await _discovery.start();
      _discoverySub = stream.listen(_onDiscoveryMessage);

      Timer(const Duration(seconds: 6), () {
        isDiscovering = false;
        notifyListeners();
      });

      _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        final cutoff = DateTime.now().subtract(const Duration(seconds: 10));
        final pruned = discoveredDevices
            .where((d) => d.lastSeen.isAfter(cutoff))
            .toList();
        if (pruned.length != discoveredDevices.length) {
          discoveredDevices = pruned;
          notifyListeners();
        }
      });
    } catch (e) {
      discoveryError = '탐색 시작 실패: $e';
      isDiscovering = false;
      notifyListeners();
    }
  }

  Future<void> _startServer() async {
    _server.onPinRequired = (pin, clientName) {
      displayPin   = pin;
      connectingTo = clientName;
      syncState    = SyncState.pinDisplay;
      notifyListeners();
    };
    _server.onSyncDone = (count, conflicts) {
      displayPin       = null;
      lastSyncCount    = count;
      pendingConflicts = conflicts;
      syncState        = SyncState.done;
      notifyListeners();
      Future.delayed(const Duration(seconds: 3), () {
        if (pendingConflicts.isEmpty) {
          syncState = SyncState.idle;
          notifyListeners();
        }
      });
    };
    _server.onError = (msg) {
      displayPin = null;
      syncError  = msg;
      syncState  = SyncState.error;
      notifyListeners();
    };
    await _server.start();
  }

  // ── 탐색 이벤트 ────────────────────────────────────────────

  void _onDiscoveryMessage(DiscoveryMessage msg) async {
    final idx = discoveredDevices.indexWhere((d) => d.ip == msg.ip);
    if (idx >= 0) {
      final updated = List<DiscoveredDevice>.from(discoveredDevices);
      updated[idx] = updated[idx].refreshed();
      discoveredDevices = updated;
      // 목록 갱신 없이 lastSeen만 업데이트 (UI 깜빡임 방지)
      return;
    }

    // 새 기기 발견 — 신뢰 여부 확인
    final trusted = msg.deviceId.isNotEmpty
        ? await TrustedDevices.isTrusted(msg.deviceId)
        : false;

    final device = DiscoveredDevice(
      name:      msg.name,
      ip:        msg.ip,
      platform:  msg.platform,
      port:      msg.port,
      deviceId:  msg.deviceId,
      lastSeen:  DateTime.now(),
      isTrusted: trusted,
    );
    discoveredDevices = [...discoveredDevices, device];
    notifyListeners();

    // 자동 동기화 트리거
    if (autoSyncEnabled && trusted && syncState == SyncState.idle) {
      final now = DateTime.now();
      if (_lastAutoSync == null ||
          now.difference(_lastAutoSync!) > _autoSyncCooldown) {
        _lastAutoSync = now;
        debugPrint('[AutoSync] 신뢰 기기 발견 → 자동 동기화: ${device.name}');
        Future.delayed(const Duration(seconds: 1), () => connectTo(device));
      }
    }
  }

  // ── 연결 (클라이언트) ──────────────────────────────────────

  Future<void> connectTo(DiscoveredDevice device) async {
    if (syncState != SyncState.idle) return;

    syncError    = null;
    connectingTo = device.name;
    syncState    = SyncState.connecting;
    notifyListeners();

    try {
      final result = await SyncClient.connect(
        ip:   device.ip,
        port: SyncServer.port,
        onPinNeeded: () async {
          _pinCompleter = Completer<String?>();
          syncState = SyncState.pinInput;
          notifyListeners();
          return _pinCompleter!.future;
        },
      );

      lastSyncCount    = result.changed;
      pendingConflicts = result.conflicts;
      syncState        = SyncState.done;
      notifyListeners();

      Future.delayed(const Duration(seconds: 3), () {
        if (pendingConflicts.isEmpty) {
          syncState = SyncState.idle;
          notifyListeners();
        }
      });
    } catch (e) {
      syncError = e.toString();
      syncState = SyncState.error;
      notifyListeners();
    }
  }

  // ── 자동 동기화 토글 ───────────────────────────────────────

  Future<void> toggleAutoSync() async {
    autoSyncEnabled = !autoSyncEnabled;
    await SyncStateStore.setAutoSync(autoSyncEnabled);
    notifyListeners();
  }

  /// 사용자가 PIN을 입력했을 때 호출
  void submitPin(String pin) {
    _pinCompleter?.complete(pin);
    _pinCompleter = null;
    syncState = SyncState.syncing;
    notifyListeners();
  }

  /// PIN 입력 취소
  void cancelPin() {
    _pinCompleter?.complete(null);
    _pinCompleter = null;
    syncState = SyncState.idle;
    notifyListeners();
  }

  /// 충돌 해결 완료 후 호출
  void clearConflicts() {
    pendingConflicts = [];
    syncState = SyncState.idle;
    notifyListeners();
  }

  /// 서버 측 PIN 표시 닫기 (연결 취소)
  void dismissPin() {
    displayPin = null;
    syncState  = SyncState.idle;
    notifyListeners();
  }

  Future<void> refresh() async {
    discoveredDevices = [];
    await _discoverySub?.cancel();
    _cleanupTimer?.cancel();
    await _discovery.stop();
    await _startDiscovery();
  }

  @override
  Future<void> dispose() async {
    _cleanupTimer?.cancel();
    await _discoverySub?.cancel();
    await _discovery.dispose();
    await _server.stop();
    super.dispose();
  }
}
