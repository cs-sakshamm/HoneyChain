import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Senior Product Audio Beeper for HoneyChain Critical Alerts
/// Synthesizes and plays 3-4 consecutive loud alert beeps with immediate stop support.
class AudioAlertService {
  AudioAlertService._();
  static final AudioAlertService instance = AudioAlertService._();

  Timer? _beepTimer;
  bool _isPlaying = false;
  int _beepsPlayed = 0;

  bool get isPlaying => _isPlaying;

  /// Plays 3-4 distinct consecutive alert beeps
  Future<void> playCriticalAlertBeeps({int count = 4}) async {
    stopAlert();
    _isPlaying = true;
    _beepsPlayed = 0;

    // Trigger initial immediate alert sound & haptic pulse
    _emitSingleBeep();
    _beepsPlayed++;

    _beepTimer = Timer.periodic(const Duration(milliseconds: 450), (timer) {
      if (!_isPlaying || _beepsPlayed >= count) {
        stopAlert();
        return;
      }
      _emitSingleBeep();
      _beepsPlayed++;
    });
  }

  void _emitSingleBeep() {
    try {
      // System Alert Sound & Haptic Pulse
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    } catch (e) {
      debugPrint('[AudioAlertService] Audio playback note: $e');
    }
  }

  /// Immediately stops any active beep sequence
  void stopAlert() {
    _isPlaying = false;
    _beepTimer?.cancel();
    _beepTimer = null;
    _beepsPlayed = 0;
  }
}
