import 'package:flutter/material.dart';

import 'app_services.dart';
import 'ui/backup_sheet.dart';
import 'ui/history_page.dart';
import 'ui/home_page.dart';
import 'ui/tags_page.dart';
import 'util/time_utils.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatefulWidget {
  const AttendanceApp({super.key});

  @override
  State<AttendanceApp> createState() => _AttendanceAppState();
}

class _AttendanceAppState extends State<AttendanceApp> {
  late final Future<AppServices> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _servicesFuture = AppServices.create();
    _servicesFuture.then((services) {
      services.onMessage = (message, {error = false}) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: error ? Theme.of(context).colorScheme.error : null,
          duration: const Duration(seconds: 3),
        ));
      };
    }).catchError((Object error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không khởi tạo được ứng dụng: $error')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chấm công NFC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF60A5FA),
          brightness: Brightness.dark,
        ),
      ),
      home: FutureBuilder<AppServices>(
        future: _servicesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      'Không mở được database hoặc NFC service.\n\n${snapshot.error}'),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return MainShell(services: snapshot.data!);
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.services});

  final AppServices services;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final PageController _pageController = PageController();
  int _index = 0;
  bool _animating = false;

  static const _pageTitles = ['', 'Lịch sử', 'Thẻ NFC'];

  @override
  void initState() {
    super.initState();
    // Nhắc chọn thư mục sao lưu / khôi phục. Bỏ qua nếu app vừa được thẻ NFC
    // khởi chạy (người dùng chỉ muốn ghi nhanh, không muốn gặp hộp thoại).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.services.launchedByTag) return;
      promptBackupOnStart(context, widget.services);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Bấm thanh điều hướng: trượt tới trang. Trong lúc trượt, bỏ qua
  /// onPageChanged của các trang trung gian để chỉ báo không nhấp nháy.
  Future<void> _goTo(int index) async {
    if (index == _index) return;
    setState(() => _index = index);
    _animating = true;
    try {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _animating = false;
    }
  }

  void _onPageChanged(int index) {
    if (_animating) return;
    if (index != _index) setState(() => _index = index);
  }

  void _explainNfc(bool ok) {
    widget.services.onMessage?.call(
      ok
          ? 'NFC đang bật: chạm thẻ vào mặt lưng điện thoại để ghi sự kiện.'
          : 'NFC chưa bật hoặc máy không hỗ trợ. Bật NFC trong Cài đặt rồi mở lại app.',
      error: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final pages = <Widget>[
      _KeepAlive(
        child: HomePage(
          controller: services.dayController,
          onMessage: (text, {error = false}) =>
              services.onMessage?.call(text, error: error),
        ),
      ),
      _KeepAlive(
        child: HistoryPage(
          repository: services.repository,
          controller: services.dayController,
        ),
      ),
      _KeepAlive(child: TagsPage(services: services)),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleTextStyle: tt.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
        // Trang Hôm nay: thứ + ngày thay cho tên app; các trang khác: tên trang.
        title: ListenableBuilder(
          listenable: services.dayController,
          builder: (context, _) => Text(
            _index == 0
                ? dayTitle(services.dayController.day)
                : _pageTitles[_index],
          ),
        ),
        actions: [
          // Sao lưu ra thư mục ngoài app: màu chính = đã chọn thư mục,
          // viền + màu khác = chưa có thư mục (dữ liệu sẽ mất khi gỡ app).
          ListenableBuilder(
            listenable: services.backup,
            builder: (context, _) {
              final ok = services.backup.hasFolder;
              return IconButton(
                tooltip: ok ? 'Sao lưu: đã bật' : 'Sao lưu: chưa chọn thư mục',
                onPressed: () => showBackupSheet(context, services),
                icon: Icon(
                  ok ? Icons.cloud_done : Icons.cloud_off_outlined,
                  color: ok ? cs.primary : cs.tertiary,
                ),
              );
            },
          ),
          // Trạng thái NFC của máy: bấm để xem giải thích.
          ListenableBuilder(
            listenable: services,
            builder: (context, _) {
              final ok = services.nfcAvailable;
              return IconButton(
                tooltip: ok ? 'NFC sẵn sàng' : 'NFC không khả dụng',
                onPressed: () => _explainNfc(ok),
                icon: Icon(Icons.nfc, color: ok ? cs.primary : cs.error),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Vuốt trái/phải để đổi trang.
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: pages,
      ),
      // Thanh điều hướng nổi, bo tròn, có bóng đổ.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Material(
            color: cs.surfaceContainerHigh,
            surfaceTintColor: Colors.transparent,
            elevation: 10,
            shadowColor: Colors.black.withAlpha(110),
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: NavigationBar(
              height: 64,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              selectedIndex: _index,
              onDestinationSelected: _goTo,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.today_outlined),
                  selectedIcon: Icon(Icons.today),
                  label: 'Hôm nay',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'Lịch sử',
                ),
                NavigationDestination(
                  icon: Icon(Icons.nfc),
                  label: 'Thẻ NFC',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Giữ trạng thái mỗi trang khi vuốt đi (như IndexedStack trước đây).
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
