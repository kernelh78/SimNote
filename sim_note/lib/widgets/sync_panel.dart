import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';

/// 안테나 아이콘 버튼 (탭 → 바텀시트)
class SyncButton extends StatelessWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context) {
    final sync  = context.watch<SyncProvider>();
    final count = sync.discoveredDevices.length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: _icon(sync),
          tooltip: '기기 동기화',
          onPressed: () => _openPanel(context),
        ),
        if (count > 0)
          Positioned(
            right: 4, top: 4,
            child: Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('$count',
                    style: const TextStyle(color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _icon(SyncProvider sync) {
    switch (sync.syncState) {
      case SyncState.connecting:
      case SyncState.syncing:
        return const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncState.done:
        return const Icon(Icons.check_circle_outline, color: Colors.green);
      case SyncState.error:
        return const Icon(Icons.error_outline, color: Colors.red);
      default:
        return const Icon(Icons.wifi_tethering);
    }
  }

  void _openPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<SyncProvider>(),
        child: const _SyncPanel(),
      ),
    );
  }
}

// ── 동기화 패널 ─────────────────────────────────────────────

class _SyncPanel extends StatelessWidget {
  const _SyncPanel();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('주변 기기',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (sync.localIp != null)
                    Text('내 IP: ${sync.localIp}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
              IconButton(
                icon: sync.isDiscovering
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                onPressed: sync.refresh,
                tooltip: '다시 탐색',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 동기화 상태 메시지
          _StatusBanner(sync: sync),

          // 탐색 중
          if (sync.isDiscovering && sync.discoveredDevices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),

          // 기기 없음
          if (!sync.isDiscovering && sync.discoveredDevices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('같은 Wi-Fi에서 SimNote 기기를 찾지 못했습니다',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    textAlign: TextAlign.center),
              ),
            ),

          // 기기 목록
          ...sync.discoveredDevices.map(
            (device) => _DeviceTile(device: device, sync: sync),
          ),

        ],
      ),
    );
  }
}

// ── 상태 배너 ────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final SyncProvider sync;
  const _StatusBanner({required this.sync});

  @override
  Widget build(BuildContext context) {
    switch (sync.syncState) {
      case SyncState.connecting:
        return _banner(context, Colors.blue.shade50,
            '${sync.connectingTo}에 연결 중...', Icons.sync);
      case SyncState.pinDisplay:
        return _banner(context, Colors.orange.shade50,
            '${sync.connectingTo}이(가) 연결을 요청했습니다', Icons.lock_outline);
      case SyncState.pinInput:
        return _banner(context, Colors.orange.shade50,
            '상대 기기 화면의 PIN을 입력하세요', Icons.lock_outline);
      case SyncState.syncing:
        return _banner(context, Colors.blue.shade50,
            '동기화 중...', Icons.cloud_sync);
      case SyncState.done:
        return _banner(context, Colors.green.shade50,
            '동기화 완료! (${sync.lastSyncCount}개 변경)', Icons.check_circle);
      case SyncState.error:
        return _banner(context, Colors.red.shade50,
            sync.syncError ?? '오류 발생', Icons.error_outline);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _banner(BuildContext context, Color color, String text, IconData icon) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

// ── 기기 타일 ────────────────────────────────────────────────

class _DeviceTile extends StatelessWidget {
  final DiscoveredDevice device;
  final SyncProvider sync;

  const _DeviceTile({required this.device, required this.sync});

  @override
  Widget build(BuildContext context) {
    final canConnect = sync.syncState == SyncState.idle;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(_platformIcon(device.platform),
              color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text(device.name,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('${device.platformLabel} · ${device.ip}',
            style: const TextStyle(fontSize: 12)),
        trailing: FilledButton(
          onPressed: canConnect
              ? () {
                  Navigator.pop(context);
                  sync.connectTo(device);
                }
              : null,
          child: const Text('동기화'),
        ),
      ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case 'android': return Icons.phone_android;
      case 'macos':   return Icons.laptop_mac;
      case 'ios':     return Icons.phone_iphone;
      case 'windows': return Icons.desktop_windows;
      default:        return Icons.devices;
    }
  }
}

// ── PIN 입력 위젯 (클라이언트) ───────────────────────────────

class _PinInputWidget extends StatefulWidget {
  final SyncProvider sync;
  const _PinInputWidget({required this.sync});

  @override
  State<_PinInputWidget> createState() => _PinInputWidgetState();
}

class _PinInputWidgetState extends State<_PinInputWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        const Text('상대 기기에 표시된 6자리 PIN을 입력하세요',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '000000',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () {
                if (_controller.text.length == 6) {
                  widget.sync.submitPin(_controller.text);
                }
              },
              child: const Text('확인'),
            ),
          ],
        ),
        TextButton(
          onPressed: widget.sync.cancelPin,
          child: const Text('취소'),
        ),
      ],
    );
  }
}

