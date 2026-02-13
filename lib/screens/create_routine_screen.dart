import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise_model.dart';
import 'exercise_library_screen.dart';
import 'dart:ui'; // For blur effect

class CreateRoutineScreen extends StatefulWidget {
  const CreateRoutineScreen({super.key});

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen> {
  final _titleController = TextEditingController();
  final List<Exercise> _selectedExercises = [];
  bool _isSaving = false;

  Future<void> _saveRoutine() async {
    if (_titleController.text.isEmpty || _selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add a title and at least one exercise")),
      );
      return;
    }

    setState(() => _isSaving = true);
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Insert Routine Header
      final routineResponse = await supabase.from('routines').insert({
        'title': _titleController.text.trim(),
        'user_id': userId,
      }).select().single();

      final routineId = routineResponse['id'];

      // Insert Routine Exercises
      final List<Map<String, dynamic>> routineExercises = [];
      for (int i = 0; i < _selectedExercises.length; i++) {
        routineExercises.add({
          'routine_id': routineId,
          'exercise_id': _selectedExercises[i].id,
          'order_index': i,
        });
      }
      await supabase.from('routine_exercises').insert(routineExercises);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Routine saved successfully!")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error saving routine: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// ---------------- GLASS CONTAINER ----------------
  Widget _glassContainer({
  Key? key, // ✅ add this
  required Widget child,
  EdgeInsets? padding,
  BorderRadius? radius,
  double blurX = 10,
  double blurY = 10,
  double opacity = 0.05,
  double borderOpacity = 0.08,
  EdgeInsets? margin,
}) {
  return ClipRRect(
    key: key, // ✅ forward it here
    borderRadius: radius ?? BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
      child: Container(
        padding: padding ?? const EdgeInsets.all(12),
        margin: margin ?? const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          borderRadius: radius ?? BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(borderOpacity)),
        ),
        child: child,
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Create Routine"),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveRoutine,
            child: _isSaving
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text(
                    "SAVE",
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Routine Title
            _glassContainer(
              child: TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontSize: 22),
                decoration: const InputDecoration(
                  hintText: "Routine Title (e.g. Leg Day)",
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Exercise List with individual glass cards
            Expanded(
              child: ReorderableListView(
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _selectedExercises.removeAt(oldIndex);
                    _selectedExercises.insert(newIndex, item);
                  });
                },
                children: _selectedExercises
                    .map(
                      (ex) => _glassContainer(
                        key: ValueKey(ex.id),
                        child: ListTile(
                          leading: const Icon(Icons.drag_handle, color: Colors.grey),
                          title: Text(ex.name, style: const TextStyle(color: Colors.white)),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: () => setState(() => _selectedExercises.remove(ex)),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

            // Add Exercise Button
            _glassContainer(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final Exercise? result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const ExerciseLibraryScreen(isSelectionMode: true),
                    ),
                  );
                  if (result != null) setState(() => _selectedExercises.add(result));
                },
                icon: const Icon(Icons.add),
                label: const Text("ADD EXERCISE"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
