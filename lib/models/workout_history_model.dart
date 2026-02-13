class WorkoutHistory {
  final String id;
  final String routineName;
  final DateTime startTime;
  final DateTime? endTime;
  final double totalVolume;
  final int totalSets;
  // Added: To store the actual sets performed in this workout
  final List<SetEntry>? sets; 

  WorkoutHistory({
    required this.id,
    required this.routineName,
    required this.startTime,
    this.endTime,
    required this.totalVolume,
    required this.totalSets,
    this.sets,
  });

  factory WorkoutHistory.fromJson(Map<String, dynamic> json) {
    return WorkoutHistory(
      id: json['id'] as String,
      routineName: json['routine_name'] ?? 'Custom Workout',
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      // Fix: Supabase might return an int or double, .toDouble() handles both
      totalVolume: (json['total_volume'] ?? 0).toDouble(),
      totalSets: json['total_sets'] ?? 0,
      // Parse nested set logs if they were included in the query
      sets: json['set_logs'] != null
          ? (json['set_logs'] as List).map((i) => SetEntry.fromJson(i)).toList()
          : null,
    );
  }
}

// Sub-model to handle the individual set data within history
class SetEntry {
  final String exerciseName;
  final double weight;
  final int reps;

  SetEntry({required this.exerciseName, required this.weight, required this.reps});

  factory SetEntry.fromJson(Map<String, dynamic> json) {
    return SetEntry(
      // Handles the joined 'exercises' table name
      exerciseName: json['exercises']?['name'] ?? 'Unknown Exercise',
      weight: (json['weight'] ?? 0).toDouble(),
      reps: json['reps'] ?? 0,
    );
  }
}