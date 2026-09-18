import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'llama_service.dart';
import 'chat_storage.dart';
import 'voice_service.dart';
import 'translate_service.dart';

class ChatMessage {
  final String role;
  String content;
  ChatMessage({required this.role, required this.content});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final LlamaService _llama = LlamaService();
  final ChatStorage _storage = ChatStorage();
  final VoiceService _voice = VoiceService();
  final TranslateService _translate = TranslateService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isModelLoading = true;
  bool _isGenerating = false;
  String? _loadError;

  bool _isListening = false;
  bool _autoSpeak = false;

  bool _translateMode = false;
  TranslateLanguage? _targetLanguage;
  final Map<String, TranslateLanguage?> _languageOptions = {
    'Тоҷикӣ': null,
    'Русӣ': TranslateLanguage.russian,
    'Англисӣ': TranslateLanguage.english,
    'Форсӣ': TranslateLanguage.persian,
    'Туркӣ': TranslateLanguage.turkish,
    'Чинӣ': TranslateLanguage.chinese,
  };
  String _targetLanguageName = 'Тоҷикӣ';

  @override
  void initState() {
    super.initState();
    _prepareModel();
    _loadHistory();
    _voice.init();
  }

  Future<void> _prepareModel() async {
    try {
      await _llama.ensureModelReady();
      setState(() => _isModelLoading = false);
    } catch (e) {
      setState(() {
        _isModelLoading = false;
        _loadError = 'Хатогӣ ҳангоми боркунии модел: $e';
      });
    }
  }

  Future<void> _loadHistory() async {
    final saved = await _storage.loadMessages();
    if (saved.isNotEmpty) {
      setState(() {
        _messages.addAll(
          saved.map((m) => ChatMessage(role: m['role']!, content: m['content']!)),
        );
      });
      _scrollToBottom();
    }
  }

  Future<void> _persistHistory() async {
    await _storage.saveMessages(
      _messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
    );
  }

  Future<void> _startNewChat() async {
    await _storage.clearMessages();
    setState(() => _messages.clear());
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _voice.stopListening();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);
    await _voice.startListening(
      onResult: (text, isFinal) {
        setState(() => _inputController.text = text);
        if (isFinal) {
          setState(() => _isListening = false);
          if (text.trim().isNotEmpty) _sendMessage();
        }
      },
    );
  }

  Future<void> _maybeSpeak(String text) async {
    if (_autoSpeak) await _voice.speak(text);
  }

  Future<void> _translateLastMessage(ChatMessage msg) async {
    try {
      String translated;
      if (_targetLanguage == null) {
        translated = await _llama.translateText(
          text: msg.content,
          targetLanguageName: 'тоҷикӣ',
        );
      } else {
        translated = await _translate.translate(
          text: msg.content,
          from: TranslateLanguage.russian,
          to: _targetLanguage!,
        );
      }
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Тарҷума:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(translated),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'Хатогии тарҷума: $e\n(Модели забонро боргирӣ кардаед?)')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isGenerating) return;

    final history = _messages
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _messages.add(ChatMessage(role: 'assistant', content: ''));
      _isGenerating = true;
      _inputController.clear();
    });
    _scrollToBottom();

    final assistantMsg = _messages.last;

    try {
      await for (final chunk in _llama.chat(userMessage: text, history: history)) {
        setState(() => assistantMsg.content += chunk);
        _scrollToBottom();
      }
      await _maybeSpeak(assistantMsg.content);
    } catch (e) {
      setState(() => assistantMsg.content = 'Хатогӣ: $e');
    } finally {
      setState(() => _isGenerating = false);
      await _persistHistory();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Офлайн'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _autoSpeak ? 'Овоз: фаъол' : 'Овоз: хомӯш',
            icon: Icon(_autoSpeak ? Icons.volume_up : Icons.volume_off),
            onPressed: () => setState(() => _autoSpeak = !_autoSpeak),
          ),
          PopupMenuButton<String>(
            tooltip: 'Тарҷума',
            icon: Icon(_translateMode
                ? Icons.translate
                : Icons.translate_outlined),
            onSelected: (value) {
              if (value == 'toggle') {
                setState(() => _translateMode = !_translateMode);
              } else {
                final lang = _languageOptions[value];
                setState(() {
                  _targetLanguage = lang;
                  _targetLanguageName = value;
                });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(_translateMode
                    ? '✓ Реҷаи тарҷума фаъол (ба $_targetLanguageName)'
                    : 'Фаъол кардани реҷаи тарҷума'),
              ),
              const PopupMenuDivider(),
              ..._languageOptions.keys.map(
                (name) => PopupMenuItem(
                  value: name,
                  child: Text(name == _targetLanguageName ? '✓ $name' : name),
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Чати нав',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _isGenerating ? null : _startNewChat,
          ),
        ],
      ),
      body: _isModelLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Модел бор карда мешавад...'),
                ],
              ),
            )
          : _loadError != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(_loadError!, textAlign: TextAlign.center),
                ))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isUser = msg.role == 'user';
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: isUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? Colors.indigo
                                        : Colors.grey[800],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    msg.content.isEmpty ? '...' : msg.content,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                if (!isUser &&
                                    _translateMode &&
                                    msg.content.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () => _translateLastMessage(msg),
                                    icon: const Icon(Icons.translate, size: 16),
                                    label: const Text('Тарҷума кун'),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            IconButton.filledTonal(
                              tooltip: _isListening
                                  ? 'Қатъ кардани гӯшкунӣ'
                                  : 'Гуфтан бо овоз',
                              onPressed: _isGenerating ? null : _toggleListening,
                              icon: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: _isListening ? Colors.redAccent : null,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TextField(
                                controller: _inputController,
                                decoration: InputDecoration(
                                  hintText: _isListening
                                      ? 'Гӯш карда истодаам...'
                                      : 'Паёми худро нависед...',
                                  border: const OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(24)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                                enabled: !_isGenerating,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _isGenerating ? null : _sendMessage,
                              icon: const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
