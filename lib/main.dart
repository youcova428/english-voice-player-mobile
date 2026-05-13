import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const EnglishVoicePlayerApp());
}

class EnglishVoicePlayerApp extends StatelessWidget {
  const EnglishVoicePlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'English Voice Player',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(defaultTargetPlatform),
      home: const EnglishVoicePlayerPage(),
    );
  }

  ThemeData _buildTheme(TargetPlatform platform) {
    final isApple = platform == TargetPlatform.iOS;
    final fontFamily = isApple ? '.SF Pro Text' : 'Roboto';
    final fontFallback = isApple
        ? const ['Hiragino Sans', 'Hiragino Kaku Gothic ProN']
        : const ['Noto Sans CJK JP', 'Noto Sans JP', 'sans-serif'];

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B35D9),
        brightness: Brightness.light,
      ),
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      scaffoldBackgroundColor: const Color(0xFFF7F3FF),
      textTheme: Typography.material2021().black.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
      ),
      primaryTextTheme: Typography.material2021().black.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
      ),
    );
  }
}

class PhraseEntry {
  const PhraseEntry({required this.id, required this.text});

  final String id;
  final String text;
}

class VoiceProfile {
  const VoiceProfile({
    required this.label,
    required this.language,
    required this.names,
  });

  final String label;
  final String language;
  final List<String> names;
}

class VoiceOption {
  const VoiceOption({
    required this.label,
    required this.name,
    required this.language,
  });

  final String label;
  final String name;
  final String language;
}

class EnglishVoicePlayerPage extends StatefulWidget {
  const EnglishVoicePlayerPage({super.key});

  @override
  State<EnglishVoicePlayerPage> createState() => _EnglishVoicePlayerPageState();
}

class _EnglishVoicePlayerPageState extends State<EnglishVoicePlayerPage> {
  static const _pageSize = 50;
  static const _welcomeText =
      'Welcome to English Voice Player! Load a CSV file and start playing audio!';

  static const _voiceProfiles = [
    VoiceProfile(
      label: 'アメリカ 女性',
      language: 'en-US',
      names: ['Samantha', 'Nicky', 'Ava', 'Allison'],
    ),
    VoiceProfile(
      label: 'アメリカ 男性',
      language: 'en-US',
      names: ['Aaron', 'Tom', 'Evan', 'Nathan'],
    ),
    VoiceProfile(
      label: 'イギリス 女性',
      language: 'en-GB',
      names: ['Martha', 'Serena', 'Kate', 'Shelley', 'Flo'],
    ),
    VoiceProfile(
      label: 'イギリス 男性',
      language: 'en-GB',
      names: ['Daniel', 'Arthur', 'Oliver'],
    ),
    VoiceProfile(
      label: 'オーストラリア 女性',
      language: 'en-AU',
      names: ['Karen', 'Catherine'],
    ),
    VoiceProfile(
      label: 'オーストラリア 男性',
      language: 'en-AU',
      names: ['Gordon', 'Lee'],
    ),
    VoiceProfile(
      label: 'カナダ 女性',
      language: 'en-CA',
      names: ['Clair', 'Claire', 'Zoe', 'Joanna'],
    ),
    VoiceProfile(
      label: 'カナダ 男性',
      language: 'en-CA',
      names: ['Liam', 'Matthew'],
    ),
    VoiceProfile(label: 'インド 男性', language: 'en-IN', names: ['Rishi']),
    VoiceProfile(label: 'インド 女性', language: 'en-IN', names: ['Isha', 'Veena']),
    VoiceProfile(label: 'アイルランド 女性', language: 'en-IE', names: ['Moira']),
    VoiceProfile(
      label: 'アイルランド 男性',
      language: 'en-IE',
      names: ['Connor', 'Sean'],
    ),
    VoiceProfile(label: '南アフリカ 女性', language: 'en-ZA', names: ['Tessa']),
    VoiceProfile(label: '南アフリカ 男性', language: 'en-ZA', names: ['Luke']),
    VoiceProfile(label: 'ニュージーランド 女性', language: 'en-NZ', names: ['Aria']),
    VoiceProfile(label: 'ニュージーランド 男性', language: 'en-NZ', names: ['Mitchell']),
  ];

  static const _hardToHearVoiceNames = [
    'Bad News',
    'Bahh',
    'Bells',
    'Boing',
    'Bubbles',
    'Cellos',
    'Good News',
    'Jester',
    'Organ',
    'Superstar',
    'Trinoids',
    'Whisper',
    'Zarvox',
    'オルガン',
    'ささやき声',
    'スーパースター',
    'トリノイド',
    'ベル',
    '道化',
    '震え',
  ];

  final _tts = FlutterTts();
  final _textController = TextEditingController(text: _welcomeText);
  final _idSearchController = TextEditingController();
  final _scrollController = ScrollController();

  List<VoiceOption> _voices = [];
  List<PhraseEntry> _csvEntries = [];
  List<PhraseEntry> _playbackQueue = [];

  int _selectedVoiceIndex = -1;
  int _repeatRemaining = 0;
  int _queueIndex = 0;
  int _playbackRunId = 0;
  int _activeSpeechRunId = 0;
  int _currentPage = 1;

  double _rate = 0.45;
  double _pitch = 1;
  double _gapSeconds = 1.5;
  int _repeatCount = 1;

  String _status = '準備完了';
  String _currentText = '';
  String _currentId = '';
  String _hiddenPlaybackText = '';
  String _csvSummary = '未読み込み';
  String? _activeListPlaybackMode;

  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isPlaybackHidden = false;
  bool _isUpdatingTextProgrammatically = false;
  bool _isWaitingBetweenPhrases = false;
  int _waitProgressRunId = 0;

  Timer? _queueTimer;

  @override
  void initState() {
    super.initState();
    _configureTts();
    _loadVoices();
    _textController.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _queueTimer?.cancel();
    _tts.stop();
    _textController.dispose();
    _idSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _configureTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(_rate);
      await _tts.setPitch(_pitch);
      await _tts.awaitSpeakCompletion(false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = '音声を使用できません';
        });
      }
      return;
    }

    _tts.setStartHandler(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = true;
        _isPaused = false;
        _status = '再生中';
      });
    });

    _tts.setCompletionHandler(() {
      if (!mounted) {
        return;
      }
      _handleSpeechComplete(_activeSpeechRunId);
    });

    _tts.setErrorHandler((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _isPaused = false;
        _status = '再生エラー';
      });
    });
  }

  Future<void> _loadVoices() async {
    final dynamic rawVoices;
    try {
      rawVoices = await _tts.getVoices;
    } catch (_) {
      return;
    }
    if (rawVoices is! List) {
      return;
    }

    final profileLanguages = _voiceProfiles
        .map((profile) => _normalizeVoiceLanguage(profile.language))
        .toSet();
    final availableVoices = rawVoices
        .whereType<Map>()
        .map((voice) {
          final name = '${voice['name'] ?? ''}';
          final locale = '${voice['locale'] ?? voice['language'] ?? ''}';
          return VoiceOption(label: name, name: name, language: locale);
        })
        .where(
          (voice) => profileLanguages.contains(
            _normalizeVoiceLanguage(voice.language),
          ),
        )
        .where(_isClearVoice)
        .toList();

    final selectedVoiceKeys = <String>{};
    final options = <VoiceOption>[];
    for (final profile in _voiceProfiles) {
      final voice = _findProfileVoice(
        profile,
        availableVoices,
        selectedVoiceKeys,
      );
      if (voice != null) {
        selectedVoiceKeys.add(_voiceKey(voice));
        options.add(
          VoiceOption(
            label: profile.label,
            name: voice.name,
            language: voice.language,
          ),
        );
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _voices = options;
      _selectedVoiceIndex = options.isEmpty ? -1 : 0;
    });
  }

  bool _isClearVoice(VoiceOption voice) {
    final lowerName = voice.name.toLowerCase();
    return !_hardToHearVoiceNames.any(
      (name) => lowerName.contains(name.toLowerCase()),
    );
  }

  VoiceOption? _findProfileVoice(
    VoiceProfile profile,
    List<VoiceOption> availableVoices,
    Set<String> selectedVoiceKeys,
  ) {
    final sameLanguage = availableVoices
        .where(
          (voice) => _isSameVoiceLanguage(voice.language, profile.language),
        )
        .toList();

    for (final name in profile.names) {
      for (final voice in sameLanguage) {
        if (voice.name.toLowerCase().contains(name.toLowerCase()) &&
            !selectedVoiceKeys.contains(_voiceKey(voice))) {
          return voice;
        }
      }
    }

    for (final voice in sameLanguage) {
      if (!selectedVoiceKeys.contains(_voiceKey(voice))) {
        return voice;
      }
    }

    return null;
  }

  bool _isSameVoiceLanguage(String voiceLanguage, String profileLanguage) {
    return _normalizeVoiceLanguage(voiceLanguage) ==
        _normalizeVoiceLanguage(profileLanguage);
  }

  String _normalizeVoiceLanguage(String language) {
    return language.replaceAll('_', '-').toLowerCase();
  }

  String _voiceKey(VoiceOption voice) {
    return '${voice.name}::${_normalizeVoiceLanguage(voice.language)}'
        .toLowerCase();
  }

  Future<void> _applyVoiceSettings() async {
    final selectedVoice = _selectedVoice;
    try {
      if (selectedVoice != null) {
        await _tts.setLanguage(selectedVoice.language);
        await _tts.setVoice({
          'name': selectedVoice.name,
          'locale': selectedVoice.language,
        });
      } else {
        await _tts.setLanguage('en-US');
      }
      await _tts.setSpeechRate(_rate);
      await _tts.setPitch(_pitch);
    } catch (_) {
      _setStatus('音声を使用できません');
    }
  }

  VoiceOption? get _selectedVoice {
    if (_selectedVoiceIndex < 0 || _selectedVoiceIndex >= _voices.length) {
      return null;
    }
    return _voices[_selectedVoiceIndex];
  }

  bool get _isPlaybackActive {
    return _isPlaying ||
        _isPaused ||
        _playbackQueue.isNotEmpty ||
        (_queueTimer?.isActive ?? false);
  }

  String get _wordCountLabel {
    if (_isPlaybackHidden) {
      return '';
    }
    final visibleText = _textController.text.trim();
    if (_csvEntries.isEmpty && visibleText == _welcomeText) {
      return '';
    }
    if (visibleText.isEmpty) {
      return '';
    }
    final matches = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?").allMatches(visibleText);
    final idText = _currentId.isEmpty ? '' : 'id: $_currentId / ';
    final count = matches.length;
    return '$idText$count語';
  }

  List<PhraseEntry> get _currentPageEntries {
    final start = (_currentPage - 1) * _pageSize;
    return _csvEntries.skip(start).take(_pageSize).toList();
  }

  int get _totalPages => max(1, (_csvEntries.length / _pageSize).ceil());

  void _setStatus(String status) {
    setState(() {
      _status = status;
    });
  }

  void _handleTextChanged() {
    if (_isUpdatingTextProgrammatically) {
      return;
    }
    if (_isPlaybackHidden && _textController.text.isNotEmpty) {
      _resetHiddenPlaybackText();
    }
    if (_currentId.isNotEmpty && _textController.text != _currentText) {
      setState(() {
        _currentId = '';
      });
    } else {
      setState(() {});
    }
  }

  void _setEditorText(String text) {
    _isUpdatingTextProgrammatically = true;
    try {
      _textController.text = text;
    } finally {
      _isUpdatingTextProgrammatically = false;
    }
  }

  Future<void> _playText([String? text, String id = '']) async {
    final trimmed = (text ?? _textController.text).trim();
    if (_csvEntries.isEmpty && trimmed == _welcomeText) {
      _setStatus('CSVを読み込んでください');
      return;
    }
    if (trimmed.isEmpty) {
      _setStatus('英文を入力してください');
      return;
    }

    await _tts.stop();
    _queueTimer?.cancel();
    _playbackRunId += 1;
    setState(() {
      _playbackQueue = [];
      _queueIndex = 0;
      _currentId = id;
      _currentText = trimmed;
      _repeatRemaining = _repeatCount;
      _activeListPlaybackMode = null;
      _isWaitingBetweenPhrases = false;
      _resetHiddenPlaybackText(changeState: false);
    });
    unawaited(_speak(trimmed));
  }

  Future<void> _playPhraseList(
    List<PhraseEntry> phrases,
    String playbackMode,
  ) async {
    if (phrases.isEmpty) {
      _setStatus('CSVに英文がありません');
      return;
    }

    await _tts.stop();
    _queueTimer?.cancel();
    _playbackRunId += 1;
    setState(() {
      _playbackQueue = List.of(phrases);
      _queueIndex = 0;
      _activeListPlaybackMode = playbackMode;
      _isWaitingBetweenPhrases = false;
    });
    unawaited(_speakCurrentQueueItem());
  }

  Future<void> _speakCurrentQueueItem() async {
    final entry = _playbackQueue[_queueIndex];
    setState(() {
      _currentId = entry.id;
      _currentText = entry.text;
      _repeatRemaining = _repeatCount;
      _hideCurrentPlaybackText(changeState: false);
    });
    unawaited(_speak(entry.text));
  }

  Future<void> _speak(String text) async {
    _activeSpeechRunId = _playbackRunId;
    if (mounted && _isWaitingBetweenPhrases) {
      setState(() {
        _isWaitingBetweenPhrases = false;
      });
    }
    await _applyVoiceSettings();
    await _tts.speak(text);
  }

  void _handleSpeechComplete(int runId) {
    if (runId != _playbackRunId) {
      return;
    }

    if (_playbackQueue.isNotEmpty) {
      _repeatRemaining -= 1;
      if (_repeatRemaining > 0) {
        _waitThenSpeakCurrentText(runId);
        return;
      }

      _queueIndex += 1;
      if (_queueIndex < _playbackQueue.length) {
        final entry = _playbackQueue[_queueIndex];
        setState(() {
          _currentId = entry.id;
          _currentText = entry.text;
          _repeatRemaining = _repeatCount;
          _hideCurrentPlaybackText(changeState: false);
        });
        _waitThenSpeakCurrentText(runId);
      } else {
        _finishQueuePlayback();
      }
      return;
    }

    _repeatRemaining -= 1;
    if (_repeatRemaining > 0) {
      unawaited(_speak(_currentText));
    } else {
      setState(() {
        _isPlaying = false;
        _status = '準備完了';
      });
    }
  }

  void _waitThenSpeakCurrentText(int runId) {
    setState(() {
      _isPlaying = false;
      _isWaitingBetweenPhrases = true;
      _waitProgressRunId += 1;
      _status = '待機中';
    });
    _queueTimer?.cancel();
    _queueTimer = Timer(
      Duration(milliseconds: (_gapSeconds * 1000).round()),
      () {
        if (runId == _playbackRunId) {
          unawaited(_speak(_currentText));
        }
      },
    );
  }

  void _finishQueuePlayback() {
    setState(() {
      _playbackQueue = [];
      _queueIndex = 0;
      _activeListPlaybackMode = null;
      _isWaitingBetweenPhrases = false;
      _resetHiddenPlaybackText(changeState: false);
      _setEditorText('');
      _currentId = '';
      _currentText = '';
      _isPlaying = false;
      _status = '準備完了';
    });
  }

  void _resumePlayback() {
    unawaited(_speak(_currentText));
    setState(() {
      _isPaused = false;
      _isPlaying = true;
      _status = '再生中';
    });
  }

  Future<void> _pausePlayback() async {
    await _tts.pause();
    setState(() {
      _isPaused = true;
      _isPlaying = false;
      _status = '一時停止';
    });
  }

  Future<void> _stopPlayback() async {
    _playbackRunId += 1;
    _queueTimer?.cancel();
    setState(() {
      _repeatRemaining = 0;
      _playbackQueue = [];
      _queueIndex = 0;
      _activeListPlaybackMode = null;
      _isWaitingBetweenPhrases = false;
      _resetHiddenPlaybackText(changeState: false);
      _currentId = '';
      _currentText = '';
      _setEditorText('');
      _isPlaying = false;
      _isPaused = false;
      _status = '停止しました';
    });
    unawaited(_tts.stop());
  }

  void _hideCurrentPlaybackText({bool changeState = true}) {
    void update() {
      _hiddenPlaybackText = _currentText;
      _isPlaybackHidden = true;
      _setEditorText('');
    }

    if (changeState) {
      setState(update);
    } else {
      update();
    }
  }

  void _revealCurrentPlaybackText() {
    if (_hiddenPlaybackText.isEmpty) {
      _setStatus('非表示の英文はありません');
      return;
    }

    setState(() {
      _isPlaybackHidden = false;
      _setEditorText(_hiddenPlaybackText);
      _status = '表示中';
    });
  }

  void _resetHiddenPlaybackText({bool changeState = true}) {
    void update() {
      _hiddenPlaybackText = '';
      _isPlaybackHidden = false;
    }

    if (changeState) {
      setState(update);
    } else {
      update();
    }
  }

  void _togglePlaybackText() {
    if (_hiddenPlaybackText.isEmpty) {
      _setStatus('非表示の英文はありません');
      return;
    }
    if (_isPlaybackHidden) {
      _revealCurrentPlaybackText();
    } else {
      _hideCurrentPlaybackText();
      _setStatus('非表示中');
    }
  }

  void _clearText() {
    setState(() {
      _resetHiddenPlaybackText(changeState: false);
      _currentId = '';
      _currentText = '';
      _setEditorText('');
    });
  }

  Future<void> _loadCsvFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) {
      return;
    }

    final bytes = file.bytes;
    if (bytes == null) {
      _setStatus('CSVを読み込めません');
      return;
    }

    final content = utf8.decode(bytes, allowMalformed: true);
    final entries = _extractCsvEntries(_parseCsv(content));
    setState(() {
      _csvEntries = entries;
      _currentPage = 1;
      _currentId = '';
      _setEditorText('');
      _csvSummary = entries.isNotEmpty
          ? '${file.name}: ${entries.length}件'
          : '${file.name}: 英文なし';
      _status = entries.isNotEmpty ? 'CSVを読み込みました' : '英文がありません';
    });
  }

  void _clearCsv() {
    setState(() {
      _csvEntries = [];
      _currentPage = 1;
      _playbackQueue = [];
      _queueIndex = 0;
      _resetHiddenPlaybackText(changeState: false);
      _currentId = '';
      _csvSummary = '未読み込み';
      _setEditorText(_welcomeText);
      _status = 'CSVをクリアしました';
    });
  }

  void _searchById() {
    final id = _idSearchController.text.trim();
    if (id.isEmpty) {
      _setStatus('idを入力してください');
      return;
    }

    final entryIndex = _csvEntries.indexWhere((entry) => entry.id == id);
    if (entryIndex < 0) {
      _setStatus('idが見つかりません');
      return;
    }

    final entry = _csvEntries[entryIndex];
    setState(() {
      _currentPage = (entryIndex / _pageSize).floor() + 1;
      _showEntry(entry, changeState: false);
      _status = '見つかりました';
    });
  }

  void _showEntry(PhraseEntry entry, {bool changeState = true}) {
    void update() {
      _resetHiddenPlaybackText(changeState: false);
      _currentId = entry.id;
      _currentText = entry.text;
      _setEditorText(entry.text);
    }

    if (changeState) {
      setState(update);
    } else {
      update();
    }
  }

  List<List<String>> _parseCsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    var cell = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < text.length; index += 1) {
      final char = text[index];
      final nextChar = index + 1 < text.length ? text[index + 1] : '';

      if (char == '"' && inQuotes && nextChar == '"') {
        cell.write('"');
        index += 1;
      } else if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        row.add(cell.toString().trim());
        cell = StringBuffer();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && nextChar == '\n') {
          index += 1;
        }
        row.add(cell.toString().trim());
        if (row.any((value) => value.isNotEmpty)) {
          rows.add(row);
        }
        row = <String>[];
        cell = StringBuffer();
      } else {
        cell.write(char);
      }
    }

    row.add(cell.toString().trim());
    if (row.any((value) => value.isNotEmpty)) {
      rows.add(row);
    }

    return rows;
  }

  List<PhraseEntry> _extractCsvEntries(List<List<String>> rows) {
    if (rows.isEmpty) {
      return [];
    }

    final headerRow = rows.first;
    final idColumn = _findColumnIndex(headerRow, ['id', 'no', 'number', '番号']);
    final englishColumn = _findColumnIndex(headerRow, [
      'english',
      'text',
      'sentence',
      'phrase',
      '英文',
    ]);

    final entries = <PhraseEntry>[];
    for (var index = 0; index < rows.skip(1).length; index += 1) {
      final row = rows[index + 1];
      final rawId = idColumn >= 0 && idColumn < row.length
          ? row[idColumn]
          : row.isNotEmpty
          ? row.first
          : '';
      final text = englishColumn >= 0 && englishColumn < row.length
          ? row[englishColumn]
          : row.indexed
                .where((cell) => cell.$1 != idColumn)
                .map((cell) => cell.$2)
                .firstWhere(_looksLikeEnglish, orElse: () => '');
      final id = rawId.trim().isEmpty ? '${index + 1}' : rawId.trim();
      final trimmedText = text.trim();
      if (_looksLikeEnglish(trimmedText)) {
        entries.add(PhraseEntry(id: id, text: trimmedText));
      }
    }

    return entries;
  }

  int _findColumnIndex(List<String> headerRow, List<String> names) {
    return headerRow.indexWhere(
      (cell) => names.contains(cell.trim().toLowerCase()),
    );
  }

  bool _looksLikeEnglish(String cell) {
    final letters = RegExp('[A-Za-z]').allMatches(cell).length;
    return letters >= 2;
  }

  List<PhraseEntry> _shufflePhrases(List<PhraseEntry> phrases) {
    final shuffled = List<PhraseEntry>.of(phrases);
    final random = Random();
    for (var index = shuffled.length - 1; index > 0; index -= 1) {
      final randomIndex = random.nextInt(index + 1);
      final current = shuffled[index];
      shuffled[index] = shuffled[randomIndex];
      shuffled[randomIndex] = current;
    }
    return shuffled;
  }

  void _goToPreviousPage() {
    if (_currentPage <= 1) {
      return;
    }
    setState(() {
      _currentPage -= 1;
    });
  }

  void _goToNextPage() {
    if (_currentPage >= _totalPages) {
      return;
    }
    setState(() {
      _currentPage += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isPlaying
                ? const [
                    Color(0xFF2A124D),
                    Color(0xFF5D2BB8),
                    Color(0xFF163D3A),
                  ]
                : const [
                    Color(0xFFF8F4FF),
                    Color(0xFFF3FBF7),
                    Color(0xFFFFFFFF),
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        status: _status,
                        isPlaying: _isPlaying,
                        isWaiting: _isWaitingBetweenPhrases,
                        waitProgressRunId: _waitProgressRunId,
                        gapSeconds: _gapSeconds,
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 860;
                          final inputPanel = _buildInputPanel();
                          final controlPanel = _buildControlPanel();
                          if (!isWide) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                inputPanel,
                                const SizedBox(height: 18),
                                controlPanel,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: inputPanel),
                              const SizedBox(width: 18),
                              SizedBox(width: 340, child: controlPanel),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildPhraseSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputPanel() {
    return _Panel(
      isPlaying: _isPlaying,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 360),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('英文', style: _labelStyle),
                const Spacer(),
                _CircleButton(
                  icon: Icons.close,
                  tooltip: '英文をクリア',
                  onPressed: _clearText,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: TextField(
                controller: _textController,
                readOnly: true,
                minLines: null,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 18, height: 1.65),
                decoration: InputDecoration(
                  hintText: _isPlaybackHidden
                      ? '再生中の英文は非表示です。表示ボタンで確認できます。'
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFFCFAFF),
                  border: _fieldBorder,
                  enabledBorder: _fieldBorder,
                  focusedBorder: _fieldBorder.copyWith(
                    borderSide: const BorderSide(color: Color(0xFF6B35D9)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _ActionButton(
                  label: _isPlaybackHidden ? '表示' : '非表示',
                  onPressed: _togglePlaybackText,
                ),
                if (_wordCountLabel.isNotEmpty)
                  Text(
                    _wordCountLabel,
                    style: const TextStyle(
                      color: Color(0xFF5E556B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return _Panel(
      isPlaying: _isPlaying,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('声', style: _labelStyle),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _selectedVoiceIndex,
                isExpanded: true,
                menuMaxHeight: 340,
                items: [
                  if (_voices.isEmpty)
                    const DropdownMenuItem(value: -1, child: Text('標準音声')),
                  ..._voices.indexed.map(
                    (voice) => DropdownMenuItem(
                      value: voice.$1,
                      child: Text(
                        voice.$2.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedVoiceIndex = value ?? -1;
                  });
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFFCFAFF),
                  border: _fieldBorder,
                  enabledBorder: _fieldBorder,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SliderField(
                label: '速度',
                valueLabel: _rate.toStringAsFixed(2),
                value: _rate,
                min: 0.2,
                max: 0.8,
                divisions: 12,
                onChanged: (value) {
                  setState(() {
                    _rate = value;
                  });
                },
              ),
              _SliderField(
                label: '高さ',
                valueLabel: _pitch.toStringAsFixed(2),
                value: _pitch,
                min: 0.7,
                max: 1.3,
                divisions: 12,
                onChanged: (value) {
                  setState(() {
                    _pitch = value;
                  });
                },
              ),
              const Text('繰り返し', style: _labelStyle),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: '1',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFFCFAFF),
                  border: _fieldBorder,
                  enabledBorder: _fieldBorder,
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value) ?? 1;
                  setState(() {
                    _repeatCount = parsed.clamp(1, 10);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TransportButton(
                icon: Icons.play_arrow,
                tooltip: '再生',
                color: const Color(0xFF6B35D9),
                onPressed: _isPlaying
                    ? null
                    : _isPaused
                    ? _resumePlayback
                    : _isPlaybackActive
                    ? null
                    : () => _playText(),
              ),
              const SizedBox(width: 12),
              _TransportButton(
                icon: Icons.pause,
                tooltip: '一時停止',
                color: const Color(0xFF6B35D9),
                onPressed: _isPlaying ? _pausePlayback : null,
              ),
              const SizedBox(width: 12),
              _TransportButton(
                icon: Icons.stop,
                tooltip: '停止',
                color: const Color(0xFFC96145),
                onPressed: _isPlaybackActive ? _stopPlayback : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhraseSection() {
    final entries = _currentPageEntries;
    return _Panel(
      isPlaying: _isPlaying,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF6B35D9);
                  }
                  return const Color(0xFFF0ECFA);
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return const Color(0xFF20182D);
                }),
                side: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const BorderSide(color: Color(0xFF6B35D9));
                  }
                  return const BorderSide(color: Color(0xFFE3DDF1));
                }),
              ),
              segments: const [
                ButtonSegment(value: 'all', label: Text('全再生')),
                ButtonSegment(value: 'random', label: Text('ランダム再生')),
              ],
              selected: {?_activeListPlaybackMode},
              emptySelectionAllowed: true,
              onSelectionChanged: (selection) {
                final value = selection.firstOrNull;
                if (value == 'all') {
                  _playPhraseList(_csvEntries, 'all');
                } else if (value == 'random') {
                  _playPhraseList(_shufflePhrases(_csvEntries), 'random');
                }
              },
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: _SliderField(
                label: '文間隔',
                valueLabel: '${_gapSeconds.toStringAsFixed(1)}秒',
                value: _gapSeconds,
                min: 0.5,
                max: 5,
                divisions: 9,
                onChanged: (value) {
                  setState(() {
                    _gapSeconds = value;
                  });
                },
              ),
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(label: '読み込み', onPressed: _loadCsvFile),
              _ActionButton(label: 'クリア', onPressed: _clearCsv),
              Text(
                _csvSummary,
                style: const TextStyle(
                  color: Color(0xFF5E556B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _idSearchController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '半角数字',
                    filled: true,
                    fillColor: const Color(0xFFFCFAFF),
                    border: _fieldBorder,
                    enabledBorder: _fieldBorder,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onChanged: (value) {
                    final normalized = value.replaceAll(RegExp(r'\D'), '');
                    if (normalized != value) {
                      _idSearchController.text = normalized;
                      _idSearchController.selection = TextSelection.collapsed(
                        offset: normalized.length,
                      );
                    }
                  },
                  onSubmitted: (_) => _searchById(),
                ),
              ),
              _ActionButton(label: '検索', onPressed: _searchById),
              if (_csvEntries.length > _pageSize) _buildPagination(),
            ],
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const _EmptyState()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 860 ? 3 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 132,
                  ),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _PhraseCard(
                      entry: entry,
                      isActive: entry.id == _currentId,
                      onUse: () => _showEntry(entry),
                      onPlay: () => _playText(entry.text, entry.id),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final start = (_currentPage - 1) * _pageSize + 1;
    final end = min(_currentPage * _pageSize, _csvEntries.length);
    return Wrap(
      spacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$start-$end / ${_csvEntries.length}',
          style: const TextStyle(
            color: Color(0xFF5E556B),
            fontWeight: FontWeight.w800,
          ),
        ),
        _ActionButton(
          label: '前へ',
          onPressed: _currentPage == 1 ? null : _goToPreviousPage,
        ),
        Text(
          '$_currentPage / $_totalPages',
          style: const TextStyle(
            color: Color(0xFF5E556B),
            fontWeight: FontWeight.w800,
          ),
        ),
        _ActionButton(
          label: '次へ',
          onPressed: _currentPage == _totalPages ? null : _goToNextPage,
        ),
      ],
    );
  }
}

const _labelStyle = TextStyle(
  color: Color(0xFF5E556B),
  fontSize: 13,
  fontWeight: FontWeight.w800,
);

final _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(8),
  borderSide: const BorderSide(color: Color(0xFFE3DDF1)),
);

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.status,
    required this.isPlaying,
    required this.isWaiting,
    required this.waitProgressRunId,
    required this.gapSeconds,
  });

  final String status;
  final bool isPlaying;
  final bool isWaiting;
  final int waitProgressRunId;
  final double gapSeconds;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      isPlaying: isPlaying,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = _HeaderTitle(isCompact: constraints.maxWidth < 520);
          final statusPill = _StatusPill(
            status: status,
            isPlaying: isPlaying,
            isWaiting: isWaiting,
            waitProgressRunId: waitProgressRunId,
            gapSeconds: gapSeconds,
          );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: statusPill),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 18),
              statusPill,
            ],
          );
        },
      ),
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/branding/app_icon.png',
            width: isCompact ? 42 : 48,
            height: isCompact ? 42 : 48,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'English Voice Player',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF20182D),
              fontSize: isCompact ? 25 : 31,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.status,
    required this.isPlaying,
    required this.isWaiting,
    required this.waitProgressRunId,
    required this.gapSeconds,
  });

  final String status;
  final bool isPlaying;
  final bool isWaiting;
  final int waitProgressRunId;
  final double gapSeconds;

  @override
  Widget build(BuildContext context) {
    final baseColor = isPlaying
        ? const Color(0xFF7B3FEB)
        : const Color(0xFFF0ECFA);
    final textColor = isPlaying || isWaiting
        ? Colors.white
        : const Color(0xFF5B33B8);
    final borderColor = isPlaying || isWaiting
        ? const Color(0xFFB79DFF).withValues(alpha: 0.5)
        : const Color(0xFFE3DDF1);

    return TweenAnimationBuilder<double>(
      key: ValueKey(isWaiting ? waitProgressRunId : -1),
      tween: Tween(begin: 0, end: isWaiting ? 1 : 0),
      duration: Duration(
        milliseconds: isWaiting ? (gapSeconds * 1000).round() : 180,
      ),
      curve: Curves.linear,
      builder: (context, progress, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minWidth: 112, maxWidth: 180),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            child: Stack(
              children: [
                if (isWaiting)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: const ColoredBox(color: Color(0xFF6B35D9)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Center(
                    child: Text(
                      status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    required this.isPlaying,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final bool isPlaying;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: padding,
      decoration: BoxDecoration(
        color: isPlaying
            ? const Color(0xFFF1E9FF).withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.94),
        border: Border.all(
          color: isPlaying
              ? const Color(0xFF8A5BE8).withValues(alpha: 0.48)
              : const Color(0xFFE3DDF1).withValues(alpha: 0.95),
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: isPlaying
                ? const Color(0xFF2F1559).withValues(alpha: 0.26)
                : const Color(0xFF2F2440).withValues(alpha: 0.10),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label, style: _labelStyle),
            const Spacer(),
            Text(
              valueLabel,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: const Color(0xFF6B35D9),
          inactiveColor: const Color(0xFFE1D8F5),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF0ECFA),
          foregroundColor: const Color(0xFF20182D),
          disabledBackgroundColor: const Color(
            0xFFF0ECFA,
          ).withValues(alpha: 0.5),
          disabledForegroundColor: const Color(
            0xFF20182D,
          ).withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
        child: Text(label),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(38),
        minimumSize: const Size.square(38),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: const Color(0xFFF0ECFA),
        foregroundColor: const Color(0xFF20182D),
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 28),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(58),
        minimumSize: const Size.square(58),
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE4DDED),
        disabledForegroundColor: const Color(0xFF7C738A),
      ),
    );
  }
}

class _PhraseCard extends StatelessWidget {
  const _PhraseCard({
    required this.entry,
    required this.isActive,
    required this.onUse,
    required this.onPlay,
  });

  final PhraseEntry entry;
  final bool isActive;
  final VoidCallback onUse;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFF0E9FF) : const Color(0xFFFCFAFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? const Color(0xFF6B35D9) : const Color(0xFFE3DDF1),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF6B35D9).withValues(alpha: 0.16),
                  spreadRadius: 2,
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF20182D),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ),
                Text(
                  'id: ${entry.id}',
                  style: const TextStyle(
                    color: Color(0xFF5E556B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleButton(
                icon: Icons.north_east,
                tooltip: '英文を入力欄へ',
                onPressed: onUse,
              ),
              const SizedBox(height: 8),
              _CircleButton(
                icon: Icons.play_arrow,
                tooltip: 'この英文を再生',
                onPressed: onPlay,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE3DDF1),
          style: BorderStyle.solid,
        ),
      ),
      child: const Text(
        '読み込みをすると英文がここに表示されます。',
        style: TextStyle(color: Color(0xFF5E556B), fontWeight: FontWeight.w800),
      ),
    );
  }
}
