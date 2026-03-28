import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database/db_service.dart';
import 'providers/app_provider.dart';
import 'providers/sync_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DbService.init();
  runApp(const SimNoteApp());
}

class SimNoteApp extends StatelessWidget {
  const SimNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()..load()),
        ChangeNotifierProvider(create: (_) => SyncProvider()..start()),
      ],
      child: MaterialApp(
        title: 'SimNote',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5B6AF0),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5B6AF0),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
