import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F7A68),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      home: const EnglishVoicePlayerPage(),
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
    VoiceProfile(label: 'アイルランド 女性', language: 'en-IE', names: ['Moira']),
    VoiceProfile(label: 'インド 男性', language: 'en-IN', names: ['Rishi']),
    VoiceProfile(label: '南アフリカ 女性', language: 'en-ZA', names: ['Tessa']),
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
  int _currentPage = 1;

  double _rate = 1;
  double _pitch = 1;
  double _gapSeconds = 1.5;
  int _repeatCount = 1;

  String _status = 'Ready';
  String _currentText = '';
  String _currentId = '';
  String _hiddenPlaybackText = '';
  String _csvSummary = '未読み込み';

  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isPlaybackHidden = false;

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
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = 'TTS unavailable';
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
        _status = 'Playing';
      });
    });

    _tts.setCompletionHandler(() {
      if (!mounted) {
        return;
      }
      _handleSpeechComplete(_playbackRunId);
    });

    _tts.setErrorHandler((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _isPaused = false;
        _status = 'Playback error';
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

    final availableVoices = rawVoices
        .whereType<Map>()
        .map((voice) {
          final name = '${voice['name'] ?? ''}';
          final locale = '${voice['locale'] ?? voice['language'] ?? ''}';
          return VoiceOption(label: name, name: name, language: locale);
        })
        .where((voice) => voice.language.toLowerCase().startsWith('en'))
        .where(_isClearVoice)
        .toList();

    final selected = <VoiceOption>[];
    final options = <VoiceOption>[];
    for (final profile in _voiceProfiles) {
      if (options.length >= 10) {
        break;
      }
      final voice = _findProfileVoice(profile, availableVoices, selected);
      if (voice != null) {
        selected.add(voice);
        options.add(
          VoiceOption(
            label: '${profile.label}: ${voice.name} (${voice.language})',
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
    List<VoiceOption> selectedVoices,
  ) {
    final sameLanguage = availableVoices
        .where((voice) => voice.language == profile.language)
        .toList();

    for (final name in profile.names) {
      for (final voice in sameLanguage) {
        if (voice.name.toLowerCase().contains(name.toLowerCase()) &&
            !selectedVoices.contains(voice)) {
          return voice;
        }
      }
    }

    if (profile.language == 'en-CA') {
      for (final voice in sameLanguage) {
        if (!selectedVoices.contains(voice)) {
          return voice;
        }
      }
    }

    return null;
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
      _setStatus('TTS unavailable');
    }
  }

  VoiceOption? get _selectedVoice {
    if (_selectedVoiceIndex < 0 || _selectedVoiceIndex >= _voices.length) {
      return null;
    }
    return _voices[_selectedVoiceIndex];
  }

  String get _wordCountLabel {
    if (_csvEntries.isEmpty && _textController.text.trim() == _welcomeText) {
      return '';
    }
    final matches = RegExp(
      r"[A-Za-z]+(?:'[A-Za-z]+)?",
    ).allMatches(_textController.text.trim());
    final idText = _currentId.isEmpty ? '' : 'id: $_currentId / ';
    final count = matches.length;
    return '$idText$count word${count == 1 ? '' : 's'}';
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

  Future<void> _playText([String? text, String id = '']) async {
    final trimmed = (text ?? _textController.text).trim();
    if (_csvEntries.isEmpty && trimmed == _welcomeText) {
      _setStatus('Load CSV first');
      return;
    }
    if (trimmed.isEmpty) {
      _setStatus('Enter text');
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
      _resetHiddenPlaybackText(changeState: false);
    });
    await _speak(trimmed);
  }

  Future<void> _playPhraseList(List<PhraseEntry> phrases) async {
    if (phrases.isEmpty) {
      _setStatus('No CSV text');
      return;
    }

    await _tts.stop();
    _queueTimer?.cancel();
    _playbackRunId += 1;
    setState(() {
      _playbackQueue = List.of(phrases);
      _queueIndex = 0;
    });
    await _speakCurrentQueueItem();
  }

  Future<void> _speakCurrentQueueItem() async {
    final entry = _playbackQueue[_queueIndex];
    setState(() {
      _currentId = entry.id;
      _currentText = entry.text;
      _repeatRemaining = _repeatCount;
      _hideCurrentPlaybackText(changeState: false);
    });
    await _speak(entry.text);
  }

  Future<void> _speak(String text) async {
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
        _status = 'Ready';
      });
    }
  }

  void _waitThenSpeakCurrentText(int runId) {
    setState(() {
      _isPlaying = false;
      _status = 'Waiting';
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
      _resetHiddenPlaybackText(changeState: false);
      _textController.text = '';
      _currentId = '';
      _isPlaying = false;
      _status = 'Ready';
    });
  }

  Future<void> _pauseOrResume() async {
    if (_isPaused) {
      await _tts.speak(_currentText);
      setState(() {
        _isPaused = false;
        _isPlaying = true;
        _status = 'Playing';
      });
      return;
    }

    await _tts.pause();
    setState(() {
      _isPaused = true;
      _isPlaying = false;
      _status = 'Paused';
    });
  }

  Future<void> _stopPlayback() async {
    _playbackRunId += 1;
    _queueTimer?.cancel();
    await _tts.stop();
    setState(() {
      _repeatRemaining = 0;
      _playbackQueue = [];
      _queueIndex = 0;
      _resetHiddenPlaybackText(changeState: false);
      _currentId = '';
      _isPlaying = false;
      _isPaused = false;
      _status = 'Stopped';
    });
  }

  void _hideCurrentPlaybackText({bool changeState = true}) {
    void update() {
      _hiddenPlaybackText = _currentText;
      _isPlaybackHidden = true;
      _textController.text = '';
    }

    if (changeState) {
      setState(update);
    } else {
      update();
    }
  }

  void _revealCurrentPlaybackText() {
    if (_hiddenPlaybackText.isEmpty) {
      _setStatus('No hidden text');
      return;
    }

    setState(() {
      _isPlaybackHidden = false;
      _textController.text = _hiddenPlaybackText;
      _status = 'Shown';
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
      _setStatus('No hidden text');
      return;
    }
    if (_isPlaybackHidden) {
      _revealCurrentPlaybackText();
    } else {
      _hideCurrentPlaybackText();
      _setStatus('Hidden');
    }
  }

  void _clearText() {
    setState(() {
      _resetHiddenPlaybackText(changeState: false);
      _currentId = '';
      _textController.text = '';
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
      _setStatus('CSV read error');
      return;
    }

    final content = utf8.decode(bytes, allowMalformed: true);
    final entries = _extractCsvEntries(_parseCsv(content));
    setState(() {
      _csvEntries = entries;
      _currentPage = 1;
      _currentId = '';
      _textController.text = '';
      _csvSummary = entries.isNotEmpty
          ? '${file.name}: ${entries.length}件'
          : '${file.name}: 英文なし';
      _status = entries.isNotEmpty ? 'CSV loaded' : 'No English text';
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
      _textController.text = _welcomeText;
      _status = 'CSV cleared';
    });
  }

  void _searchById() {
    final id = _idSearchController.text.trim();
    if (id.isEmpty) {
      _setStatus('Enter id');
      return;
    }

    final entryIndex = _csvEntries.indexWhere((entry) => entry.id == id);
    if (entryIndex < 0) {
      _setStatus('id not found');
      return;
    }

    final entry = _csvEntries[entryIndex];
    setState(() {
      _currentPage = (entryIndex / _pageSize).floor() + 1;
      _showEntry(entry, changeState: false);
      _status = 'Found';
    });
  }

  void _showEntry(PhraseEntry entry, {bool changeState = true}) {
    void update() {
      _resetHiddenPlaybackText(changeState: false);
      _currentId = entry.id;
      _currentText = entry.text;
      _textController.text = entry.text;
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1456513080510-7bf3a84b82f8?auto=format&fit=crop&w=1800&q=80',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: Color(0xFFF4F6F3)),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            color: _isPlaying
                ? const Color(0xFFE9E0FA).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.72),
          ),
          SafeArea(
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
                        _TopBar(status: _status, isPlaying: _isPlaying),
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
        ],
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
                  tooltip: 'Clear text',
                  onPressed: _clearText,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: TextField(
                controller: _textController,
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
                  fillColor: const Color(0xFFFBFCFB),
                  border: _fieldBorder,
                  enabledBorder: _fieldBorder,
                  focusedBorder: _fieldBorder.copyWith(
                    borderSide: const BorderSide(color: Color(0xFF1F7A68)),
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
                      color: Color(0xFF68716D),
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
                items: [
                  if (_voices.isEmpty)
                    const DropdownMenuItem(
                      value: -1,
                      child: Text('Default browser voice'),
                    ),
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
                  fillColor: const Color(0xFFFBFCFB),
                  border: _fieldBorder,
                  enabledBorder: _fieldBorder,
                ),
              ),
              const SizedBox(height: 16),
              _SliderField(
                label: 'Speed',
                valueLabel: _rate.toStringAsFixed(2),
                value: _rate,
                min: 0.5,
                max: 1.5,
                divisions: 20,
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
                  fillColor: const Color(0xFFFBFCFB),
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
                tooltip: 'Play',
                color: const Color(0xFF1F7A68),
                onPressed: () => _playText(),
              ),
              const SizedBox(width: 12),
              _TransportButton(
                icon: _isPaused ? Icons.play_arrow : Icons.pause,
                tooltip: 'Pause',
                color: const Color(0xFF1F7A68),
                onPressed: _pauseOrResume,
              ),
              const SizedBox(width: 12),
              _TransportButton(
                icon: Icons.stop,
                tooltip: 'Stop',
                color: const Color(0xFFC96145),
                onPressed: _stopPlayback,
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
          const Text(
            'リスト',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'all', label: Text('全再生')),
                ButtonSegment(value: 'random', label: Text('ランダム再生')),
              ],
              selected: const <String>{},
              emptySelectionAllowed: true,
              onSelectionChanged: (selection) {
                final value = selection.firstOrNull;
                if (value == 'all') {
                  _playPhraseList(_csvEntries);
                } else if (value == 'random') {
                  _playPhraseList(_shufflePhrases(_csvEntries));
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
                  color: Color(0xFF68716D),
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
              const SizedBox(
                width: double.infinity,
                child: Text('検索', style: _labelStyle),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _idSearchController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '半角数字',
                    filled: true,
                    fillColor: const Color(0xFFFBFCFB),
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
                    mainAxisExtent: 116,
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
            color: Color(0xFF68716D),
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
            color: Color(0xFF68716D),
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
  color: Color(0xFF68716D),
  fontSize: 13,
  fontWeight: FontWeight.w800,
);

final _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(8),
  borderSide: const BorderSide(color: Color(0xFFD9DED8)),
);

class _TopBar extends StatelessWidget {
  const _TopBar({required this.status, required this.isPlaying});

  final String status;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      isPlaying: isPlaying,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 18,
        runSpacing: 12,
        children: [
          const Text(
            'English Voice Player',
            style: TextStyle(
              color: Color(0xFF19211D),
              fontSize: 38,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 112),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isPlaying
                  ? const Color(0xFF704CB6)
                  : const Color(0xFFEAF2EF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isPlaying ? Colors.white : const Color(0xFF155F52),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
            ? const Color(0xFFF8F4FF).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.91),
        border: Border.all(
          color: isPlaying
              ? const Color(0xFF704CB6).withValues(alpha: 0.36)
              : const Color(0xFFD9DED8).withValues(alpha: 0.9),
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: isPlaying
                ? const Color(0xFF5D3E9B).withValues(alpha: 0.20)
                : const Color(0xFF1D2C25).withValues(alpha: 0.12),
            blurRadius: 45,
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
          activeColor: const Color(0xFF1F7A68),
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
          backgroundColor: const Color(0xFFEEF3F1),
          foregroundColor: const Color(0xFF19211D),
          disabledBackgroundColor: const Color(
            0xFFEEF3F1,
          ).withValues(alpha: 0.5),
          disabledForegroundColor: const Color(
            0xFF19211D,
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
        backgroundColor: const Color(0xFFEDF2EF),
        foregroundColor: const Color(0xFF19211D),
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
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 28),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(58),
        backgroundColor: color,
        foregroundColor: Colors.white,
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
        color: isActive ? const Color(0xFFEEF8F4) : const Color(0xFFFBFCFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? const Color(0xFF1F7A68) : const Color(0xFFD9DED8),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF1F7A68).withValues(alpha: 0.12),
                  spreadRadius: 3,
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
                      color: Color(0xFF19211D),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ),
                Text(
                  'id: ${entry.id}',
                  style: const TextStyle(
                    color: Color(0xFF68716D),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              _CircleButton(
                icon: Icons.north_east,
                tooltip: 'Use phrase',
                onPressed: onUse,
              ),
              const SizedBox(height: 8),
              _CircleButton(
                icon: Icons.play_arrow,
                tooltip: 'Play phrase',
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
          color: const Color(0xFFD9DED8),
          style: BorderStyle.solid,
        ),
      ),
      child: const Text(
        '読み込みをすると英文がここに表示されます。',
        style: TextStyle(color: Color(0xFF68716D), fontWeight: FontWeight.w800),
      ),
    );
  }
}
