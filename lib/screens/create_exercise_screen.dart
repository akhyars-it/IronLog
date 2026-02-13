import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui'; // For blur effect
import '../models/exercise_model.dart';

class CreateExerciseScreen extends StatefulWidget {
  final Exercise? exercise; // pass this if editing

  const CreateExerciseScreen({super.key, this.exercise});

  @override
  State<CreateExerciseScreen> createState() => _CreateExerciseScreenState();
}

class _CreateExerciseScreenState extends State<CreateExerciseScreen> {
  late final TextEditingController _nameController;
  late String _selectedMuscle;
  late String _selectedEquipment;
  late String _selectedType;
  late String _selectedCategory;

  final List<String> _categories = [
    'bench', 'squat', 'deadlift', 'overhead_press', 'row', 'pull', 'push', 'other',
  ];
  final List<String> _muscles = ['Chest', 'Back', 'Shoulders', 'Legs', 'Arms', 'Core', 'Cardio'];
  final List<String> _equipment = ['Dumbbell', 'Barbell', 'Machine', 'Cable', 'Bodyweight', 'Kettlebell'];
  final Map<String, String> _typeLabels = {
    'reps_and_weight': 'Weight & Reps',
    'bodyweight_reps': 'Bodyweight Reps',
    'duration': 'Duration / Time',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.exercise?.name ?? '');
    _selectedMuscle = widget.exercise?.primaryMuscle ?? 'Chest';
    _selectedEquipment = widget.exercise?.equipment ?? 'Dumbbell';
    _selectedType = widget.exercise?.exerciseType ?? 'reps_and_weight';
    _selectedCategory = widget.exercise?.strengthCategory ?? 'other';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveExercise() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a name")),
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      if (widget.exercise != null) {
        await supabase.from('exercises').update({
          'name': name,
          'primary_muscle': _selectedMuscle,
          'equipment': _selectedEquipment,
          'exercise_type': _selectedType,
          'category': _selectedCategory,
          'is_custom': true,
        }).eq('id', widget.exercise!.id);
      } else {
        await supabase.from('exercises').insert({
          'name': name,
          'primary_muscle': _selectedMuscle,
          'equipment': _selectedEquipment,
          'exercise_type': _selectedType,
          'category': _selectedCategory,
          'user_id': user.id,
          'is_custom': true,
        });
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  /// ---------------- GLASS CONTAINER ----------------
  Widget _glassContainer({
    required Widget child,
    EdgeInsets? padding,
    BorderRadius? radius,
    double blurX = 10,
    double blurY = 10,
    double opacity = 0.05,
    double borderOpacity = 0.08,
  }) {
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(vertical: 8),
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

  /// ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.exercise != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(isEditing ? "Edit Exercise" : "New Custom Exercise"),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _glassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("What is the exercise called?", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: "e.g. Incline DB Flyes",
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _glassContainer(
              child: _buildDropdown(
                "Primary Muscle Group",
                _selectedMuscle,
                _muscles,
                (val) => setState(() => _selectedMuscle = val!),
              ),
            ),
            _glassContainer(
              child: _buildDropdown(
                "Equipment",
                _selectedEquipment,
                _equipment,
                (val) => setState(() => _selectedEquipment = val!),
              ),
            ),
            _glassContainer(
              child: _buildDropdown(
                "Strength Category",
                _selectedCategory,
                _categories,
                (val) => setState(() => _selectedCategory = val!),
              ),
            ),
            _glassContainer(
              child: _buildDropdown(
                "Tracking Type",
                _selectedType,
                _typeLabels.keys.toList(),
                (val) => setState(() => _selectedType = val!),
                itemLabels: _typeLabels,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveExercise,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isEditing ? "SAVE CHANGES" : "CREATE EXERCISE",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// ---------------- DROPDOWNS ----------------
  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged,
      {Map<String, String>? itemLabels}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: Colors.black87,
              style: const TextStyle(color: Colors.white),
              items: items
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(itemLabels != null ? itemLabels[e]! : e),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
