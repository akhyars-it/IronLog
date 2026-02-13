import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise_model.dart';
import 'exercise_library_screen.dart';

class EditRoutineScreen extends StatefulWidget {
  final Map<String, dynamic> routine;

  const EditRoutineScreen({super.key, required this.routine});

  @override
  State<EditRoutineScreen> createState() => _EditRoutineScreenState();
}

class _EditRoutineScreenState extends State<EditRoutineScreen> {
  final _supabase = Supabase.instance.client;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  List<Exercise> _selectedExercises = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.routine['title']);
    _descController = TextEditingController(text: widget.routine['description'] ?? "");
    
    // Map existing exercises from the routine data structure
    _selectedExercises = (widget.routine['routine_exercises'] as List)
        .map((re) => Exercise.fromJson(re['exercises']))
        .toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// Deletes the routine after a confirmation dialog
  Future<void> _deleteRoutine() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Delete Routine?", style: TextStyle(color: Colors.white)),
        content: const Text("This action cannot be undone.", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("DELETE", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      await _supabase.from('routines').delete().eq('id', widget.routine['id']);
      if (mounted) {
        // Pop twice to go back to the main routine list, not the detail screen
        Navigator.of(context).pop(); 
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _updateRoutine() async {
    if (_titleController.text.trim().isEmpty || _selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title and at least one exercise required")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final routineId = widget.routine['id'];

      // 1. Update the routine header
      await _supabase.from('routines').update({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
      }).eq('id', routineId);

      // 2. Clear existing exercise links for this routine
      await _supabase.from('routine_exercises').delete().eq('routine_id', routineId);

      // 3. Re-insert the updated exercise list with proper ordering
      final List<Map<String, dynamic>> routineExercises = [];
      for (int i = 0; i < _selectedExercises.length; i++) {
        routineExercises.add({
          'routine_id': routineId,
          'exercise_id': _selectedExercises[i].id,
          'order_index': i,
        });
      }

      await _supabase.from('routine_exercises').insert(routineExercises);

      if (mounted) {
        Navigator.pop(context, true); // Return true to trigger UI refresh
      }
    } catch (e) {
      debugPrint("Error updating routine: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("Edit Routine", style: TextStyle(fontSize: 18)),
        actions: [
          if (!_isSaving)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _deleteRoutine,
            ),
          const SizedBox(width: 8),
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else
            TextButton(
              onPressed: _updateRoutine,
              child: const Text("SAVE", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: Column(
        children: [
          // HEADER INPUTS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: "Routine Title", 
                    hintStyle: TextStyle(color: Colors.white24), 
                    border: InputBorder.none
                  ),
                ),
                TextField(
                  controller: _descController,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: "Description (optional)", 
                    hintStyle: TextStyle(color: Colors.white24), 
                    border: InputBorder.none
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, thickness: 1),

          // REORDERABLE EXERCISE LIST
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                child: child, // Prevents white flash during drag
              ),
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx -= 1;
                  final item = _selectedExercises.removeAt(oldIdx);
                  _selectedExercises.insert(newIdx, item);
                });
              },
              children: [
                for (int i = 0; i < _selectedExercises.length; i++)
                  ListTile(
                    key: ValueKey("${_selectedExercises[i].id}_$i"),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: const Icon(Icons.drag_handle, color: Colors.white24),
                    title: Text(_selectedExercises[i].name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    subtitle: Text(_selectedExercises[i].primaryMuscle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 22),
                      onPressed: () => setState(() => _selectedExercises.removeAt(i)),
                    ),
                  ),
              ],
            ),
          ),
          
          // BOTTOM BUTTON
          _addExerciseButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _addExerciseButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OutlinedButton.icon(
        onPressed: () async {
          final Exercise? result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ExerciseLibraryScreen(isSelectionMode: true)),
          );
          if (result != null) {
            setState(() => _selectedExercises.add(result));
          }
        },
        icon: const Icon(Icons.add, size: 18),
        label: const Text("ADD EXERCISE", style: TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue, 
          side: const BorderSide(color: Colors.blue),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}