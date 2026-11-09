import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_controller.dart';
import 'screens/home_screen.dart';
import 'services/assistant_backend.dart';
import 'services/mock_assistant.dart';
import 'services/proxy_assistant.dart';
import 'services/recorder_service.dart';

const _fontFamily = 'NotoSansEthiopic';
const _seed = Color(0xFF0F7B45); // Ethiopian green

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SelamApp(
    backend: FallbackAssistant(
      primary: ProxyAssistant(),
      fallback: MockAssistant(),
    ),
    recorder: RecorderService(),
  ));
}

class SelamApp extends StatefulWidget {
  const SelamApp({super.key, required this.backend, required this.recorder});

  final AssistantBackend backend;
  final RecorderService recorder;

  @override
  State<SelamApp> createState() => _SelamAppState();
}

class _SelamAppState extends State<SelamApp> {
  late final ChatController _controller =
      ChatController(backend: widget.backend, recorder: widget.recorder);
  bool _english = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _english = p.getBool('english') ?? false);
    });
  }

  Future<void> _toggleLanguage() async {
    setState(() => _english = !_english);
    final p = await SharedPreferences.getInstance();
    await p.setBool('english', _english);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: b),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Selam',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: HomeScreen(
        controller: _controller,
        english: _english,
        onToggleLanguage: _toggleLanguage,
      ),
    );
  }
}
