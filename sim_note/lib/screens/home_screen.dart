import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/sidebar.dart';
import '../widgets/note_list.dart';
import '../widgets/note_editor.dart';
import '../widgets/mobile_layout.dart';
import '../widgets/sync_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SyncState _prevState = SyncState.idle;

  @override
  void initState() {
    super.initState();
    // 다음 프레임 후 리스너 등록 (context가 준비된 후)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SyncProvider>().addListener(_onSyncStateChanged);
    });
  }

  @override
  void dispose() {
    context.read<SyncProvider>().removeListener(_onSyncStateChanged);
    super.dispose();
  }

  void _onSyncStateChanged() {
    final sync = context.read<SyncProvider>();

    // 서버 측: PIN 표시 다이얼로그
    if (sync.syncState == SyncState.pinDisplay &&
        _prevState != SyncState.pinDisplay) {
      _showPinDisplayDialog(sync);
    }

    // 클라이언트 측: PIN 입력 다이얼로그
    if (sync.syncState == SyncState.pinInput &&
        _prevState != SyncState.pinInput) {
      _showPinInputDialog(sync);
    }

    // 동기화 완료 시 노트 목록 갱신
    if (sync.syncState == SyncState.done && _prevState != SyncState.done) {
      context.read<AppProvider>().load();
    }

    _prevState = sync.syncState;
  }

  void _showPinDisplayDialog(SyncProvider sync) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: sync,
        child: const _PinDisplayDialog(),
      ),
    );
  }

  void _showPinInputDialog(SyncProvider sync) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: sync,
        child: const _PinInputDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return Scaffold(
            body: Stack(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 220, child: Sidebar()),
                    const VerticalDivider(width: 1),
                    const SizedBox(width: 260, child: NoteList()),
                    const VerticalDivider(width: 1),
                    const Expanded(child: NoteEditor()),
                  ],
                ),
                const Positioned(top: 8, right: 8, child: SyncButton()),
              ],
            ),
          );
        }
        return const MobileLayout();
      },
    );
  }
}

// ── PIN 표시 다이얼로그 (서버 측) ────────────────────────────

class _PinDisplayDialog extends StatelessWidget {
  const _PinDisplayDialog();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();

    // 동기화 완료 or 취소되면 자동으로 닫기
    if (sync.syncState == SyncState.done ||
        sync.syncState == SyncState.idle ||
        sync.syncState == SyncState.error) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }

    return AlertDialog(
      title: Text('${sync.connectingTo ?? "기기"}의 연결 요청'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('상대 기기에 이 PIN을 입력하세요'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              sync.displayPin ?? '------',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          if (sync.syncState == SyncState.syncing) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            const Text('동기화 중...'),
          ],
        ],
      ),
      actions: [
        if (sync.syncState != SyncState.syncing)
          TextButton(
            onPressed: () {
              sync.dismissPin();
              Navigator.pop(context);
            },
            child: const Text('취소'),
          ),
      ],
    );
  }
}

// ── PIN 입력 다이얼로그 (클라이언트 측) ──────────────────────

class _PinInputDialog extends StatefulWidget {
  const _PinInputDialog();

  @override
  State<_PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<_PinInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();

    // 입력 완료 후 상태 변화 시 자동 닫기
    if (sync.syncState == SyncState.done ||
        sync.syncState == SyncState.syncing ||
        sync.syncState == SyncState.error ||
        sync.syncState == SyncState.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }

    return AlertDialog(
      title: Text('${sync.connectingTo ?? "기기"}에 연결'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('상대 기기 화면에 표시된 6자리 PIN을 입력하세요'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: '000000',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            style: const TextStyle(fontSize: 28, letterSpacing: 8),
            onSubmitted: (_) => _submit(sync),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            sync.cancelPin();
            Navigator.pop(context);
          },
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _controller.text.length == 6 ? () => _submit(sync) : null,
          child: const Text('확인'),
        ),
      ],
    );
  }

  void _submit(SyncProvider sync) {
    if (_controller.text.length == 6) {
      sync.submitPin(_controller.text);
    }
  }
}
