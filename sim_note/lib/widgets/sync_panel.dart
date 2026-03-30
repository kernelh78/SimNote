import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../sync/sync_log.dart';

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

class _SyncPanel extends StatefulWidget {
  const _SyncPanel();

  @override
  State<_SyncPanel> createState() => _SyncPanelState();
}

class _SyncPanelState extends State<_SyncPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('동기화',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  if (sync.localIp != null)
                    Text('내 IP: ${sync.localIp}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
              IconButton(
                icon: sync.isDiscovering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                onPressed: sync.refresh,
                tooltip: '다시 탐색',
              ),
            ],
          ),
        ),
        // 자동 동기화 토글
        _AutoSyncToggle(sync: sync),
        // 탭바
        TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '주변 기기'),
            Tab(text: '동기화 로그'),
          ],
        ),
        // 탭 내용
        SizedBox(
          height: 320 + bottom,
          child: TabBarView(
            controller: _tab,
            children: [
              _DevicesTab(sync: sync, bottomPad: bottom),
              const _LogTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 자동 동기화 토글 ─────────────────────────────────────────

class _AutoSyncToggle extends StatelessWidget {
  final SyncProvider sync;
  const _AutoSyncToggle({required this.sync});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Icon(
            sync.autoSyncEnabled
                ? Icons.sync_outlined
                : Icons.sync_disabled_outlined,
            size: 18,
            color: sync.autoSyncEnabled
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('자동 동기화',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(
                  sync.autoSyncEnabled
                      ? '신뢰 기기 발견 시 자동으로 동기화합니다'
                      : '켜면 신뢰 기기가 발견될 때 자동으로 동기화합니다',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Switch(
            value: sync.autoSyncEnabled,
            onChanged: (_) => sync.toggleAutoSync(),
          ),
        ],
      ),
    );
  }
}

// ── 기기 탭 ──────────────────────────────────────────────────

class _DevicesTab extends StatelessWidget {
  final SyncProvider sync;
  final double bottomPad;

  const _DevicesTab({required this.sync, required this.bottomPad});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusBanner(sync: sync),

          if (sync.isDiscovering && sync.discoveredDevices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (!sync.isDiscovering && sync.discoveredDevices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('같은 Wi-Fi에서 SimNote 기기를 찾지 못했습니다',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    textAlign: TextAlign.center),
              ),
            ),

          ...sync.discoveredDevices.map(
            (device) => _DeviceTile(device: device, sync: sync),
          ),
        ],
      ),
    );
  }
}

// ── 로그 탭 ───────────────────────────────────────────────────

class _LogTab extends StatefulWidget {
  const _LogTab();

  @override
  State<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<_LogTab> {
  List<SyncLogEntry> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await SyncLog.load();
    if (mounted) setState(() { _logs = logs; _loading = false; });
  }

  Future<void> _clear() async {
    await SyncLog.clear();
    if (mounted) setState(() => _logs = []);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (_logs.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('로그 지우기', style: TextStyle(fontSize: 12)),
            ),
          ),
        Expanded(
          child: _logs.isEmpty
              ? Center(
                  child: Text('동기화 기록이 없습니다',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: _logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _LogTile(entry: _logs[i]),
                ),
        ),
      ],
    );
  }
}

final _logDateFmt = DateFormat('MM/dd HH:mm');

class _LogTile extends StatelessWidget {
  final SyncLogEntry entry;
  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (entry.action) {
      SyncLogAction.added            => (Icons.add_circle_outline, Colors.green),
      SyncLogAction.updated          => (Icons.edit_outlined, Colors.blue),
      SyncLogAction.deleted          => (Icons.delete_outline, Colors.red),
      SyncLogAction.tagChanged       => (Icons.tag, Colors.orange),
      SyncLogAction.conflictResolved => (Icons.call_merge, Colors.purple),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.noteTitle,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(entry.actionLabel,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Text(_logDateFmt.format(entry.time),
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
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
        title: Row(
          children: [
            Text(device.name,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            if (device.isTrusted) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('신뢰',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ],
        ),
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

