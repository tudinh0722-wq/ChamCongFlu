import 'package:flutter/material.dart';

import 'app_services.dart';
import 'ui/history_page.dart';
import 'ui/home_page.dart';
import 'ui/tags_page.dart';

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
                  child: Text('Không mở được database hoặc NFC service.\n\n${snapshot.error}'),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final pages = [
      HomePage(
        controller: services.dayController,
        onMessage: (text, {error = false}) =>
            services.onMessage?.call(text, error: error),
      ),
      HistoryPage(repository: services.repository, controller: services.dayController),
      TagsPage(services: services),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chấm công NFC'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  services.nfcAvailable ? Icons.nfc : Icons.nfc_outlined,
                  color: services.nfcAvailable
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(services.nfcAvailable ? 'NFC sẵn sàng' : 'NFC không khả dụng',
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Hôm nay'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Lịch sử'),
          NavigationDestination(icon: Icon(Icons.nfc), label: 'Thẻ NFC'),
        ],
      ),
    );
  }
}
