import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; 
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:confetti/confetti.dart';
import '../services/workout_provider.dart';
import '../models/exercise_model.dart';
import 'exercise_library_screen.dart';
import 'save_workout_screen.dart'; // Ensure this is imported

class LiveWorkoutScreen extends StatefulWidget {
  final String routineTitle;
  final List<Exercise> initialExercises;

  const LiveWorkoutScreen({
    super.key,
    required this.routineTitle,
    required this.initialExercises,
  });

  @override
  State<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends State<LiveWorkoutScreen> {
  final _supabase = Supabase.instance.client;
  late ConfettiController _confettiController;
  List<Exercise> _activeExercises = [];

  // Data structure to hold set info and notes
  Map<String, List<Map<String, dynamic>>> _workoutData = {};
  Map<String, TextEditingController> _exerciseNotesControllers = {};
  Map<String, List<Map<String, dynamic>>> _previousSessionData = {};
  Map<String, double> _personalRecords = {};
  Map<String, int> _exerciseRestTimes = {}; 

  Timer? _restTimer;
  int _remainingRestTime = 0;
  int _currentTimerMax = 180; 
  bool _isResting = false;

  double _totalVolume = 0;
  int _completedSets = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _activeExercises = List.from(widget.initialExercises);
    _loadInitialData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WorkoutProvider>().startWorkout();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _restTimer?.cancel();
    _exerciseNotesControllers.forEach((_, controller) => controller.dispose());
    for (var exerciseSets in _workoutData.values) {
      for (var setData in exerciseSets) {
        (setData['weight'] as TextEditingController).dispose();
        (setData['reps'] as TextEditingController).dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    for (var ex in _activeExercises) {
      await _fetchPreviousSessionSets(ex.id);
      await _fetchAllTimePR(ex.id);
      _exerciseRestTimes[ex.id] = 180; 
      _initExerciseData(ex.id);
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchAllTimePR(String exerciseId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final response = await _supabase
          .from('set_logs')
          .select('weight')
          .eq('user_id', userId)
          .eq('exercise_id', exerciseId)
          .order('weight', ascending: false)
          .limit(1)
          .maybeSingle();

      _personalRecords[exerciseId] = response != null ? (response['weight'] as num).toDouble() : 0;
    } catch (e) {
      debugPrint("PR Fetch Error: $e");
    }
  }

  Future<void> _fetchPreviousSessionSets(String exerciseId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final lastWorkoutEntry = await _supabase
          .from('set_logs')
          .select('workout_id')
          .eq('exercise_id', exerciseId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastWorkoutEntry != null) {
        final lastWorkoutId = lastWorkoutEntry['workout_id'];
        final List<dynamic> sets = await _supabase
            .from('set_logs')
            .select('weight, reps')
            .eq('workout_id', lastWorkoutId)
            .eq('exercise_id', exerciseId)
            .order('set_index', ascending: true);

        _previousSessionData[exerciseId] = sets.map((s) => {
          'weight': s['weight'].toString(),
          'reps': s['reps'].toString(),
        }).toList();
      }
    } catch (e) {
      debugPrint("Error fetching previous: $e");
    }
  }

  void _initExerciseData(String id) {
    if (!_exerciseNotesControllers.containsKey(id)) {
      _exerciseNotesControllers[id] = TextEditingController();
    }
    if (!_workoutData.containsKey(id)) {
      List<Map<String, dynamic>> initialSets = [];
      if (_previousSessionData.containsKey(id) && _previousSessionData[id]!.isNotEmpty) {
        for (var prevSet in _previousSessionData[id]!) {
          initialSets.add(_createNewSetMap(weight: prevSet['weight'], reps: prevSet['reps']));
        }
      } else {
        initialSets.add(_createNewSetMap());
      }
      _workoutData[id] = initialSets;
    }
  }

  Map<String, dynamic> _createNewSetMap({String? weight, String? reps}) {
    return {
      'weight': TextEditingController(text: weight ?? ""),
      'reps': TextEditingController(text: reps ?? ""),
      'isDone': false
    };
  }

  // --- UI ACTIONS ---

  void _showExerciseOptions(Exercise ex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.white),
              title: const Text("Replace Exercise", style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final Exercise? newEx = await Navigator.push(context, MaterialPageRoute(builder: (c) => const ExerciseLibraryScreen(isSelectionMode: true)));
                if (newEx != null) {
                  setState(() {
                    int idx = _activeExercises.indexOf(ex);
                    _activeExercises[idx] = newEx;
                    _initExerciseData(newEx.id);
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Remove Exercise", style: TextStyle(color: Colors.red)),
              onTap: () {
                setState(() {
                  _activeExercises.removeWhere((e) => e.id == ex.id);
                  _workoutData.remove(ex.id);
                });
                Navigator.pop(context);
                _calculateLiveStats();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startRestTimer(String exerciseId) {
    _restTimer?.cancel();
    int duration = _exerciseRestTimes[exerciseId] ?? 180;
    setState(() {
      _currentTimerMax = duration;
      _remainingRestTime = duration;
      _isResting = true;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingRestTime > 0) {
        setState(() => _remainingRestTime--);
      } else {
        _onTimerFinished();
      }
    });
  }

  void _onTimerFinished() {
    _restTimer?.cancel();
    HapticFeedback.heavyImpact(); 
    setState(() {
      _isResting = false;
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() => _isResting = false);
  }

  void _adjustRestTime(int seconds) {
    setState(() {
      _remainingRestTime = (_remainingRestTime + seconds).clamp(0, 999);
    });
    HapticFeedback.selectionClick();
  }

  void _calculateLiveStats() {
    double vol = 0;
    int setsCount = 0;
    _workoutData.forEach((exId, list) {
      if (_activeExercises.any((e) => e.id == exId)) {
        for (var s in list) {
          if (s['isDone']) {
            double w = double.tryParse((s['weight'] as TextEditingController).text) ?? 0;
            int r = int.tryParse((s['reps'] as TextEditingController).text) ?? 0;
            vol += (w * r);
            setsCount++;
          }
        }
      }
    });
    setState(() {
      _totalVolume = vol;
      _completedSets = setsCount;
    });
  }

  void _finishWorkout() {
    if (_completedSets == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Complete at least one set before finishing!")),
      );
      return;
    }

    // Prepare set logs to be passed to the SaveWorkoutScreen
    List<Map<String, dynamic>> setLogs = [];
    for (var ex in _activeExercises) {
      var sets = _workoutData[ex.id] ?? [];
      String notes = _exerciseNotesControllers[ex.id]?.text ?? "";

      for (int i = 0; i < sets.length; i++) {
        if (sets[i]['isDone']) {
          setLogs.add({
            'exercise_id': ex.id,
            'weight': double.tryParse((sets[i]['weight'] as TextEditingController).text) ?? 0,
            'reps': int.tryParse((sets[i]['reps'] as TextEditingController).text) ?? 0,
            'set_index': i + 1,
            'notes': notes.isNotEmpty ? notes : null,
          });
        }
      }
    }

    final workoutProvider = context.read<WorkoutProvider>();
    final duration = DateTime.now().difference(workoutProvider.startTime ?? DateTime.now());

    // Stop the background timer before navigating
    workoutProvider.stopWorkout();

    // Navigate to SaveWorkoutScreen (Post-Workout Summary)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SaveWorkoutScreen(
          routineTitle: widget.routineTitle,
          duration: duration,
          totalVolume: _totalVolume,
          totalSets: _completedSets,
          setLogs: setLogs,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerText = context.watch<WorkoutProvider>().currentDuration;

    return WillPopScope(
      onWillPop: () async {
        _showDiscardDialog();
        return false;
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: Text(widget.routineTitle, style: const TextStyle(fontSize: 16)),
              backgroundColor: Colors.black,
              leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.blue, size: 32), onPressed: _showDiscardDialog),
              actions: [
                TextButton(
                  onPressed: _finishWorkout,
                  child: const Text("FINISH", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            body: Stack(
  children: [
    // Main content: Header + Exercises List
    Column(
      children: [
        _buildLiveHeader(timerText),
        Expanded(
          child: ListView.builder(
            itemCount: _activeExercises.length + 1,
            itemBuilder: (context, index) {
              if (index == _activeExercises.length) return _addExerciseButton();
              return _buildExerciseCard(_activeExercises[index]);
            },
          ),
        ),
      ],
    ),

    // Rest timer overlay
    if (_isResting)
      Positioned(
        bottom: 20,
        left: 20,
        right: 20,
        child: _buildRestTimerBar(),
      ),
  ],
),

          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [Colors.blue, Colors.orange, Colors.white],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveHeader(String timerText) {
  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: glassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat("TIME", timerText, Colors.blue),
          _buildStat("VOLUME", "${_totalVolume.toInt()} kg", Colors.white),
          _buildStat("SETS", "$_completedSets", Colors.white),
        ],
      ),
    ),
  );
}


  Widget _buildExerciseCard(Exercise ex) {
    int restSec = _exerciseRestTimes[ex.id] ?? 180;
    
    return Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: glassContainer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Exercise Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.fitness_center, size: 20, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(child: Text(ex.name, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 17))),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                onPressed: () => _showExerciseOptions(ex),
              ),
            ],
          ),
        ),
        // Notes
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextField(
            controller: _exerciseNotesControllers[ex.id],
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: "Add exercise notes...",
              hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Rest timer toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: InkWell(
            onTap: () => _showRestTimePicker(ex.id, ex.name),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 14, color: Colors.blue),
                const SizedBox(width: 4),
                Text("${(_exerciseRestTimes[ex.id] ?? 180) ~/ 60}:${((_exerciseRestTimes[ex.id] ?? 180) % 60).toString().padLeft(2, '0')}", 
                  style: const TextStyle(color: Colors.blue, fontSize: 13)),
              ],
            ),
          ),
        ),
        // Sets
        const SizedBox(height: 8),
        ..._workoutData[ex.id]!.asMap().entries.map((e) => _buildSetRow(ex, e.key)).toList(),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                final sets = _workoutData[ex.id]!;
                String? lastW = sets.isNotEmpty ? (sets.last['weight'] as TextEditingController).text : null;
                String? lastR = sets.isNotEmpty ? (sets.last['reps'] as TextEditingController).text : null;
                _workoutData[ex.id]!.add(_createNewSetMap(weight: lastW, reps: lastR));
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white12,
              minimumSize: const Size(double.infinity, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("+ Add Set", style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ),
      ],
    ),
  ),
);

  }

  Widget _buildSetRow(Exercise ex, int idx) {
  var setData = _workoutData[ex.id]![idx];
  bool isDone = setData['isDone'];

  String prev = "—";
  if (_previousSessionData.containsKey(ex.id) &&
      _previousSessionData[ex.id]!.length > idx) {
    var p = _previousSessionData[ex.id]![idx];
    prev = "${p['weight']} x ${p['reps']}";
  }

  return Dismissible(
    key: ValueKey("${ex.id}_$idx"), // <-- Dismissible key
    direction: DismissDirection.endToStart,
    background: Container(
      alignment: Alignment.centerRight,
      color: Colors.red,
      child: const Padding(
        padding: EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
    ),
    onDismissed: (_) {
      setState(() {
        _workoutData[ex.id]!.removeAt(idx);
        _calculateLiveStats();
      });
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: isDone ? Colors.green.withOpacity(0.15) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text("${idx + 1}", style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(flex: 3, child: Center(child: Text(prev, style: const TextStyle(color: Colors.white24)))),
          Expanded(flex: 2, child: _buildInput(setData['weight'], isDone, keyId: "${ex.id}_${idx}_w")),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: _buildInput(setData['reps'], isDone, keyId: "${ex.id}_${idx}_r")),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              setState(() {
                setData['isDone'] = !setData['isDone'];
                if (setData['isDone']) {
                  _startRestTimer(ex.id);
                  double w = double.tryParse((setData['weight'] as TextEditingController).text) ?? 0;
                  if (w > (_personalRecords[ex.id] ?? 0)) {
                    _confettiController.play();
                    HapticFeedback.vibrate();
                  }
                } else {
                  _stopRestTimer();
                }
                _calculateLiveStats();
              });
            },
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: isDone ? Colors.green : Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.check, color: isDone ? Colors.white : Colors.white24, size: 20),
            ),
          ),
        ],
      ),
    ),
  );
}



  Widget _buildRestTimerBar() {
  double progress = _remainingRestTime / _currentTimerMax;
  return glassContainer(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white10,
          color: Colors.blue,
          minHeight: 2,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _timerAdjustBtn("-15", () => _adjustRestTime(-15)),
            const Spacer(),
            Text(
              "${_remainingRestTime ~/ 60}:${(_remainingRestTime % 60).toString().padLeft(2, '0')}", 
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            _timerAdjustBtn("+15", () => _adjustRestTime(15)),
            const SizedBox(width: 15),
            TextButton(
              onPressed: _stopRestTimer, 
              child: const Text("SKIP", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    ),
  );
}


  Widget _timerAdjustBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Colors.white.withOpacity(0.05)),
        child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, bool isDone, {required String keyId}) {
  return TextField(
    key: ValueKey(keyId), // <-- crucial!
    controller: controller,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.center,
    enabled: !isDone,
    style: const TextStyle(color: Colors.white, fontSize: 15),
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      filled: true,
      fillColor: isDone ? Colors.transparent : Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
    ),
  );
}


  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Discard Workout?", style: TextStyle(color: Colors.white)),
        content: const Text("Your progress will be lost.", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          TextButton(onPressed: () {
            context.read<WorkoutProvider>().stopWorkout();
            Navigator.pop(c); Navigator.pop(context);
          }, child: const Text("DISCARD", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showRestTimePicker(String exerciseId, String name) {
    int current = _exerciseRestTimes[exerciseId] ?? 180;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (context) => SizedBox(
        height: 250,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Rest Timer: $name", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.ms,
                initialTimerDuration: Duration(seconds: current),
                onTimerDurationChanged: (Duration d) {
                  setState(() => _exerciseRestTimes[exerciseId] = d.inSeconds);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget glassContainer({
  required Widget child,
  double blur = 18,
  double opacity = 0.08,
  EdgeInsets? padding,
  BorderRadius? borderRadius,
}) {
  return ClipRRect(
    borderRadius: borderRadius ?? BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity), // subtle white tint
          borderRadius: borderRadius ?? BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)), // visible border
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(opacity * 1.5),
              Colors.white.withOpacity(opacity),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: child,
      ),
    ),
  );
}




  Widget _addExerciseButton() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: OutlinedButton.icon(
        onPressed: () async {
          final Exercise? ex = await Navigator.push(context, MaterialPageRoute(builder: (c) => const ExerciseLibraryScreen(isSelectionMode: true)));
          if (ex != null) {
            setState(() {
              if (!_activeExercises.any((e) => e.id == ex.id)) {
                _activeExercises.add(ex);
                _initExerciseData(ex.id);
              }
            });
          }
        },
        icon: const Icon(Icons.add),
        label: const Text("ADD EXERCISE"),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, side: const BorderSide(color: Colors.blue)),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      Text(value, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.bold)),
    ]);
  }
}
