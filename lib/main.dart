import 'package:flutter/material.dart';

import 'agent/mock_agent.dart';
import 'screens/home_screen.dart';
import 'state/chat_controller.dart';
import 'theme.dart';

void main() => runApp(const StratusApp());

class StratusApp extends StatefulWidget {
  const StratusApp({super.key});

  @override
  State<StratusApp> createState() => _StratusAppState();
}

class _StratusAppState extends State<StratusApp> {
  // Swap MockAgent() for a GeminiAgent once it exists.
  late final ChatController _controller = ChatController(MockAgent());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Stratus',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: HomeScreen(controller: _controller),
      );
}
