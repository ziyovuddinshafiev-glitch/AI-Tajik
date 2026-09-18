import 'package:flutter/material.dart';
import 'chat_screen.dart';

void main() {
  runApp(const OfflineAiApp());
}

class OfflineAiApp extends StatelessWidget {
  const OfflineAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Офлайн',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const ChatScreen(),
    );
  }
}
