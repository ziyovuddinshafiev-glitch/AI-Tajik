import 'dart:async';
import 'dart:io';
import 'package:fllama/fllama.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class LlamaService {
  static const String modelAssetPath = 'assets/models/model.gguf';
  static const String modelFileName = 'model.gguf';

  static const String systemPrompt =
      'Ту як ёрдамчии ҳушманди муфид ҳастӣ, ки Шафиев Зиёвуддин '
      'туро сохтааст. Агар касе пурсад «Туро кӣ сохтааст?» ё ба ин '
      'монанд, бигӯ ки созандаи ту Шафиев Зиёвуддин аст. Забони '
      'асосии ту тоҷикӣ (алифбои кириллӣ) аст — ҳамеша бо забони '
      'тоҷикӣ ҷавоб деҳ, ба истиснои ҳолате ки корбар бо забони '
      'дигар савол диҳад ё аз ту хоҳиш кунад ба забони дигар '
      'тарҷума кунӣ — дар он сурат бо ҳамон забон ё тарҷумаи '
      'дархостшуда ҷавоб деҳ.\n\n'
      'Ту метавонӣ:\n'
      '- Матнро аз як забон ба забони дигар тарҷума кунӣ (тоҷикӣ, '
      'русӣ, англисӣ ва ғайра).\n'
      '- Мисолҳо ва масъалаҳои риёзиро қадам ба қадам ҳал кунӣ ва '
      'роҳи ҳалро равшан нишон диҳӣ.\n'
      '- Агар аз ту хоҳиш шавад оҳанг ё сурудеро «созӣ», матни '
      '(лирика)-и суруд ва тавсифи оҳанги онро (масалан навъи '
      'мусиқӣ, ритм, кайфият) бинавис — зеро ту наметавонӣ садои '
      'воқеии мусиқиро тавлид кунӣ, танҳо матн ва тавсифро '
      'пешниҳод мекунӣ.\n\n'
      'Ҷавобҳоятро равшан, дақиқ ва фаҳмо нависед.';

  String? _localModelPath;

  Future<String> ensureModelReady({
    void Function(double progress)? onProgress,
  }) async {
    if (_localModelPath != null) return _localModelPath!;

    final dir = await getApplicationSupportDirectory();
    final localFile = File('${dir.path}/$modelFileName');

    if (await localFile.exists()) {
      _localModelPath = localFile.path;
      return _localModelPath!;
    }

    final byteData = await rootBundle.load(modelAssetPath);
    final buffer = byteData.buffer;
    await localFile.writeAsBytes(
      buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    );

    _localModelPath = localFile.path;
    return _localModelPath!;
  }

  Stream<String> chat({
    required String userMessage,
    required List<Map<String, String>> history,
  }) async* {
    final modelPath = await ensureModelReady();

    final messages = [
      Message(Role.system, systemPrompt),
      ...history.map((m) => Message(
            _roleFromString(m['role']!),
            m['content']!,
          )),
      Message(Role.user, userMessage),
    ];

    final request = OpenAiRequest(
      maxTokens: 512,
      messages: messages,
      numGpuLayers: 99,
      modelPath: modelPath,
      temperature: 0.7,
      topP: 0.9,
    );

    final controller = StreamController<String>();
    String fullResponse = '';

    fllamaChat(request, (response, openAiResponseJsonString, done) {
      final newPart = response.substring(fullResponse.length);
      fullResponse = response;
      if (newPart.isNotEmpty) controller.add(newPart);
      if (done) controller.close();
    });

    yield* controller.stream;
  }

  Role _roleFromString(String role) {
    switch (role) {
      case 'user':
        return Role.user;
      case 'assistant':
        return Role.assistant;
      case 'system':
        return Role.system;
      default:
        return Role.user;
    }
  }

  Future<String> translateText({
    required String text,
    required String targetLanguageName,
  }) async {
    final modelPath = await ensureModelReady();

    final prompt = 'Матни зеринро танҳо ба забони $targetLanguageName '
        'тарҷума кун. Ҳеҷ изоҳ, шарҳ ё матни иловагӣ нанавис — фақат '
        'тарҷумаи холисро баргардон.\n\nМатн:\n"$text"';

    final request = OpenAiRequest(
      maxTokens: 512,
      messages: [
        Message(Role.system,
            'Ту як мутарҷими дақиқ ҳастӣ. Танҳо тарҷумаро бидеҳ, чизи дигар нанавис.'),
        Message(Role.user, prompt),
      ],
      numGpuLayers: 99,
      modelPath: modelPath,
      temperature: 0.3,
      topP: 0.9,
    );

    final completer = Completer<String>();
    fllamaChat(request, (response, openAiResponseJsonString, done) {
      if (done) completer.complete(response.trim());
    });

    return completer.future;
  }
}
