import 'dart:async';
import 'package:flutter/material.dart';

class WorkoutProvider with ChangeNotifier {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _currentDuration = "00:00:00";
  DateTime? _startTime;

  String get currentDuration => _currentDuration;
  bool get isWorkoutActive => _stopwatch.isRunning;
  DateTime? get startTime => _startTime;

  void startWorkout() {
    if (_stopwatch.isRunning) return; // Prevent multiple timers starting

    _startTime = DateTime.now();
    _stopwatch.start();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimerString();
    });
  }

  void _updateTimerString() {
    final d = _stopwatch.elapsed;
    
    // Formatting to HH:MM:SS for a professional look (Req #22)
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    
    _currentDuration = "$hours:$minutes:$seconds";
    notifyListeners();
  }

  void stopWorkout() {
    _stopwatch.stop();
    _stopwatch.reset();
    _timer?.cancel();
    _timer = null;
    _currentDuration = "00:00:00";
    notifyListeners();
  }

  // Very important to prevent app crashes when closing
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}