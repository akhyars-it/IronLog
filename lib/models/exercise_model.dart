class Exercise {
  final String id;
  final String name;
  final String equipment;
  final String primaryMuscle;
  final String exerciseType;
  final String? imageUrl;
  final bool isCustom;
  final String? strengthCategory; // 🔥 NEW

  Exercise({
    required this.id,
    required this.name,
    required this.equipment,
    required this.primaryMuscle,
    required this.exerciseType,
    this.imageUrl,
    this.isCustom = false,
    this.strengthCategory, // 🔥 NEW
  });

  // Converts Supabase Map to Exercise Object
  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] ?? 'Unnamed Exercise',
      equipment: json['equipment'] ?? 'None',
      primaryMuscle: json['primary_muscle'] ?? 'Other',
      exerciseType: json['exercise_type'] ?? 'reps_and_weight',
      imageUrl: json['image_url'],
      isCustom: json['is_custom'] as bool? ?? false,
      strengthCategory: json['strength_category'], // 🔥 map column
    );
  }

  // Converts Exercise to Map for Supabase
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'equipment': equipment,
      'primary_muscle': primaryMuscle,
      'exercise_type': exerciseType,
      'image_url': imageUrl,
      'is_custom': isCustom,
      'strength_category': strengthCategory, // 🔥 include when saving
    };
  }
}
