import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records the user's voice to a temporary m4a (AAC) file.
class RecorderService {
  RecorderService({AudioRecorder? recorder}) : _r = recorder;

  // Created lazily so tests can build the UI without the platform plugin.
  AudioRecorder? _r;
  AudioRecorder get _recorder => _r ??= AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  final _levels = StreamController<double>.broadcast();

  /// Normalised input level 0..1, emitted ~every 80 ms while recording.
  Stream<double> get levels => _levels.stream;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}${Platform.pathSeparator}selam_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 32000,
      ),
      path: path,
    );
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen((a) => _levels.add(normalise(a.current)));
  }

  /// Stops recording and returns the file path (null if nothing was captured).
  Future<String?> stop() async {
    await _ampSub?.cancel();
    _ampSub = null;
    return _recorder.stop();
  }

  Future<void> cancel() async {
    await _ampSub?.cancel();
    _ampSub = null;
    await _recorder.cancel();
  }

  /// Maps dBFS (about -60..0) to 0..1.
  static double normalise(double dbfs) {
    if (dbfs.isNaN || dbfs.isInfinite) return 0;
    return ((dbfs + 60) / 60).clamp(0.0, 1.0);
  }

  Future<void> dispose() async {
    await _ampSub?.cancel();
    await _levels.close();
    await _r?.dispose();
  }
}
