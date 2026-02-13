import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise_model.dart';
import 'create_exercise_screen.dart';
import 'exercise_details_screen.dart';
import 'dart:ui';

class ExerciseLibraryScreen extends StatefulWidget {
  final bool isSelectionMode;
  const ExerciseLibraryScreen({super.key, this.isSelectionMode = false});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _supabase = Supabase.instance.client;
  List<Exercise> _allExercises = [];
  List<Exercise> _recentExercises = [];
  List<Exercise> _customExercises = [];
  List<Exercise> _otherExercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchExercises();
  }

  Future<void> _fetchExercises() async {
    try {
      final userId = _supabase.auth.currentUser?.id;

      // Fetch all exercises
      final allData = await _supabase
          .from('exercises')
          .select()
          .or('is_custom.eq.false,user_id.eq.$userId');

      _allExercises = (allData as List).map((e) => Exercise.fromJson(e)).toList();

      // Sort alphabetically by name
      _allExercises.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Fetch recent exercise IDs
      final recentLogs = await _supabase
          .from('set_logs')
          .select('exercise_id')
          .order('created_at', ascending: false)
          .limit(50);
      final recentIds = (recentLogs as List).map((log) => log['exercise_id']).toSet();

      // Build lists
      _recentExercises = _allExercises.where((ex) => recentIds.contains(ex.id)).toList();
      _customExercises = _allExercises.where((ex) => ex.isCustom && !recentIds.contains(ex.id)).toList();
      _otherExercises = _allExercises.where((ex) => !ex.isCustom && !recentIds.contains(ex.id)).toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Library Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Delete custom exercise
  Future<void> _deleteExercise(Exercise ex) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Delete Exercise?", style: TextStyle(color: Colors.white)),
        content: const Text("This will permanently delete your custom exercise.", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _supabase.from('exercises').delete().eq('id', ex.id);
      _fetchExercises();
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  // Edit custom exercise
  Future<void> _editExercise(Exercise ex) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreateExerciseScreen(exercise: ex)),
    );
    if (result != null) _fetchExercises();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.isSelectionMode ? "Select Exercise" : "Exercises",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!widget.isSelectionMode)
            TextButton(
              onPressed: () async {
                final result = await Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const CreateExerciseScreen()));
                if (result != null) _fetchExercises();
              },
              child: const Text("Create",
                  style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : ListView(
              padding: const EdgeInsets.only(bottom: 30),
              children: [
                if (_recentExercises.isNotEmpty) ...[
                  _sectionHeader("Recent Exercises"),
                  ..._recentExercises.map((ex) => _exerciseTile(ex)),
                ],
                if (_customExercises.isNotEmpty) ...[
                  _sectionHeader("Your Exercises"),
                  ..._customExercises.map((ex) => _exerciseTile(ex, isCustom: true)),
                ],
                if (_otherExercises.isNotEmpty) ...[
                  _sectionHeader("All Exercises"),
                  ..._otherExercises.map((ex) => _exerciseTile(ex)),
                ],
              ],
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title.toUpperCase(),
          style: const TextStyle(
              color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
    );
  }

  Widget _exerciseTile(Exercise ex, {bool isCustom = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (widget.isSelectionMode) {
                Navigator.pop(context, ex);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ExerciseDetailsScreen(exercise: ex),
                  ),
                );
              }
            },
            child: Row(
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: Colors.white,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 16),

                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ex.primaryMuscle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Trailing
                if (isCustom)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editExercise(ex),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteExercise(ex),
                      ),
                    ],
                  )
                else
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
