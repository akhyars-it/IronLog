import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';

class SaveWorkoutScreen extends StatefulWidget {
  final String routineTitle;
  final Duration duration;
  final double totalVolume;
  final int totalSets;
  final List<Map<String, dynamic>> setLogs;

  const SaveWorkoutScreen({
    super.key,
    required this.routineTitle,
    required this.duration,
    required this.totalVolume,
    required this.totalSets,
    required this.setLogs,
  });

  @override
  State<SaveWorkoutScreen> createState() => _SaveWorkoutScreenState();
}

class _SaveWorkoutScreenState extends State<SaveWorkoutScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return "${d.inHours}h ${d.inMinutes.remainder(60)}m";
    return "${d.inMinutes}min";
  }

  Future<void> _saveWorkout() async {
    setState(() => _isSaving = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("User not authenticated");

      // 1. Insert Workout Record
      // Notes are correctly placed here in the 'workouts' table
      final workoutResponse = await _supabase.from('workouts').insert({
        'user_id': user.id,
        'routine_name': widget.routineTitle,
        'total_volume': widget.totalVolume,
        'total_sets': widget.totalSets,
        'notes': _notesController.text.trim(),
        'duration_seconds': widget.duration.inSeconds,
        'start_time': DateTime.now().subtract(widget.duration).toIso8601String(),
        'end_time': DateTime.now().toIso8601String(),
        'status': 'completed',
      }).select().single();

      final workoutId = workoutResponse['id'];

      // 2. Clean and Insert Set Logs
      // We must ensure only valid columns from your SQL schema are sent
      final List<Map<String, dynamic>> finalLogs = widget.setLogs.map((log) {
        return {
          'workout_id': workoutId,
          'user_id': user.id,
          'exercise_id': log['exercise_id'],
          'weight': log['weight'],
          'reps': log['reps'],
          'set_index': log['set_index'],
          // 'notes' is EXPLICITLY excluded here because it doesn't exist in set_logs table
        };
      }).toList();

      if (finalLogs.isNotEmpty) {
        await _supabase.from('set_logs').insert(finalLogs);
      }

      _handleNavigationSuccess();

    } catch (e) {
      debugPrint("Save Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"), 
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleNavigationSuccess() {
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Workout Saved!"),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      title: const Text("Summary", style: TextStyle(fontSize: 16)),
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : _saveWorkout,
          child: _isSaving 
              ? const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                )
              : const Text(
                  "Finish", 
                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
                ),
        )
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Routine Details (Glass) ---
          glassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.routineTitle, 
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statItem("Duration", _formatDuration(widget.duration)),
                    _statItem("Volume", "${widget.totalVolume.toInt()} kg"),
                    _statItem("Sets", "${widget.totalSets}"),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- Date & Notes (Glass) ---
          glassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("DATE", 
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Text(DateFormat('EEEE, d MMM yyyy').format(DateTime.now()), 
                    style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.w500)),

                const SizedBox(height: 20),

                const Text("NOTES", 
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "How did it feel? Any PRs?",
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
                    fillColor: Colors.black.withOpacity(0.05),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
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


Widget _statItem(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
    ],
  );
}
}