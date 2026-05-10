# English Voice Player Mobile

English Voice Player Mobile is a Flutter app for practicing English listening and shadowing with text-to-speech playback.

## Features

- Enter English text manually and play it with TTS.
- Load CSV files and play English phrases one by one.
- Search CSV phrases by `id`.
- Play all phrases in order or shuffled.
- Adjust voice, speech rate, pitch, repeat count, and gap between repeats.
- Hide the current phrase during playback for listening practice.
- Show word count and current phrase id.

## CSV Format

The app reads `.csv` files and looks for an id column and an English text column.

Recommended headers:

```csv
id,english
1,How are you today?
2,I would like a cup of coffee.
3,Could you say that again?
```

Supported id header names include `id`, `no`, `number`, and `番号`.

Supported English text header names include `english`, `text`, `sentence`, `phrase`, and `英文`.

## Requirements

- Flutter SDK
- iOS CocoaPods for iOS builds

## Setup

Install dependencies:

```bash
flutter pub get
```

For iOS:

```bash
cd ios
pod install
cd ..
```

## Run

```bash
flutter run
```

## Test

```bash
flutter test
```

## Main Dependencies

- `file_picker` for selecting CSV files.
- `flutter_tts` for text-to-speech playback.
