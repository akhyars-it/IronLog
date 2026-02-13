import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise_model.dart';
import 'live_workout_screen.dart';
import 'create_routine_screen.dart';
import 'routine_detail_screen.dart';
import 'dart:ui';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _routines = [];

  @override
  void initState() {
    super.initState();
    _fetchRoutines();
  }

  Future<void> _fetchRoutines() async {
  setState(() => _isLoading = true);

  final userId = _supabase.auth.currentUser!.id;

  debugPrint("Logged in userId: $userId");

  try {
    final data = await _supabase
        .from('routines')
        .select('''
          *,
          routine_exercises (
            *,
            exercises (*)
          )
        ''')
        .eq('user_id', userId);

    debugPrint("Fetched routines: $data");

    if (mounted) {
      setState(() {
        _routines = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    }
  } catch (e) {
    debugPrint("Error fetching routines: $e");
    if (mounted) setState(() => _isLoading = false);
  }
}



  void _startRoutine(Map<String, dynamic> routine) {
    final List<Exercise> selectedExercises = (routine['routine_exercises'] as List)
        .map((re) => Exercise.fromJson(re['exercises']))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveWorkoutScreen(
          routineTitle: routine['title'],
          initialExercises: selectedExercises,
        ),
      ),
    ).then((value) {
      if (value == true) _fetchRoutines();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          "Start Workout",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateRoutineScreen()),
          );
          if (result == true) _fetchRoutines();
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : RefreshIndicator(
              onRefresh: _fetchRoutines,
              color: Colors.blue,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildQuickStartCard(),
                  const SizedBox(height: 30),
                  const Text(
                    "My Routines",
                    style: TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // ✅ Display routines or empty state
                  if (_routines.isEmpty)
                    _buildEmptyState()
                  else
                    ..._routines.map((routine) => _buildRoutineCard(routine)),

                  const SizedBox(height: 80), // Padding for FAB
                ],
              ),
            ),
    );
  }

  Widget _buildQuickStartCard() {
  return InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => const LiveWorkoutScreen(
          routineTitle: "Empty Workout",
          initialExercises: [],
        ),
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.blue.withOpacity(0.4),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Start an Empty Workout",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.flash_on, color: Colors.blue),
            ],
          ),
        ),
      ),
    ),
  );
}


  Widget _buildRoutineCard(Map<String, dynamic> routine) {
  final exercises = (routine['routine_exercises'] as List?) ?? [];

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RoutineDetailScreen(routine: routine),
          ),
        ).then((value) {
          if (value == true) _fetchRoutines();
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine['title'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        exercises.isEmpty
                            ? "No exercises"
                            : exercises
                                .map((e) => e['exercises']['name'])
                                .join(", "),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.play_arrow, color: Colors.blue),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}


  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 40),
      child: Center(
        child: Text("No routines found. Create one!",
            style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
