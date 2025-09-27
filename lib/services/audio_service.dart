/*import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _soundsEnabled = true;

  static Future<void> init() async {
    // Précharger les sons pour éviter les délais
    await _player.setSource(AssetSource('sounds/1.mp3'));
  }

  static void toggleSounds(bool enabled) {
    _soundsEnabled = enabled;
  }

  static Future<void> playBuzz() async {
    if (!_soundsEnabled) return;
    await _player.play(AssetSource('sounds/buzz.mp3'));
  }
}*/
