import 'package:english_voice_player_mobile/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
          MethodCall methodCall,
        ) async {
          switch (methodCall.method) {
            case 'getVoices':
              return [
                {'name': 'Samantha', 'locale': 'en-US'},
                {'name': 'Daniel', 'locale': 'en-GB'},
              ];
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  testWidgets('renders the English Voice Player shell', (tester) async {
    await tester.pumpWidget(const EnglishVoicePlayerApp());
    await tester.pump();

    expect(find.text('English Voice Player'), findsOneWidget);
    expect(find.text('準備完了'), findsOneWidget);
    expect(find.text('全再生'), findsOneWidget);
    expect(find.text('読み込み'), findsOneWidget);
  });
}
