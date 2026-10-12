import 'package:flutter/material.dart';

import 'data/tracker_store.dart';
import 'ui/auth_screen.dart';
import 'ui/design.dart';
import 'ui/workspace_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BugTrackerApp());
}

class BugTrackerApp extends StatefulWidget {
  const BugTrackerApp({super.key, this.store});
  final TrackerStore? store;
  @override
  State<BugTrackerApp> createState() => _BugTrackerAppState();
}

class _BugTrackerAppState extends State<BugTrackerApp> {
  late Future<TrackerStore> _store;
  @override
  void initState() {
    super.initState();
    _store = widget.store == null
        ? TrackerStore.open()
        : Future.value(widget.store);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'БагТрекер',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: FutureBuilder<TrackerStore>(
      future: _store,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: EmptyState(
                  title: 'Не удалось открыть локальную базу',
                  message:
                      'Проверьте доступ к папке данных и свободное место.\n${snapshot.error}',
                  icon: Icons.storage_rounded,
                  action: FilledButton(
                    onPressed: () => setState(() {
                      _store = TrackerStore.open();
                    }),
                    child: const Text('Попробовать снова'),
                  ),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bug_report_rounded,
                    size: 52,
                    color: AppColors.accent,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'БагТрекер',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          );
        }
        final store = snapshot.data!;
        return ListenableBuilder(
          listenable: store,
          builder: (context, _) => store.currentUser == null
              ? AuthScreen(store: store)
              : WorkspaceScreen(
                  key: ValueKey(store.currentUser!.id),
                  store: store,
                ),
        );
      },
    ),
  );
}
