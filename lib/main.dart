import 'package:flutter/material.dart';

import 'agent/agent_service.dart';
import 'agent/gemini/gemini_agent.dart';
import 'agent/mock_agent.dart';
import 'gemini/gemini_client.dart';
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
  // Gemini answers when a key is configured; the scripted agent is the
  // offline fallback (no key, or Gemini unreachable).
  late final AgentService _agent =
      GeminiClient.configured ? GeminiAgent(fallback: MockAgent()) : MockAgent();
  late final ChatController _controller = ChatController(_agent);

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
