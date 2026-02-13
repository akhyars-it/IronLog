import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui'; // For blur effect

class WorkoutDetailsScreen extends StatefulWidget {
  final dynamic workout;
  final String username;
  final String? avatarPath;

  const WorkoutDetailsScreen({
    super.key,
    required this.workout,
    required this.username,
    this.avatarPath,
  });

  @override
  State<WorkoutDetailsScreen> createState() => _WorkoutDetailsScreenState();
}

class _WorkoutDetailsScreenState extends State<WorkoutDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;
    final start = DateTime.parse(workout['start_time']);
    final int duration = (workout['duration_seconds'] ?? 0) ~/ 60;
    final String? workoutPhoto = workout['photo_url'];

    // Group logs by exercise name
    final Map<String, List<dynamic>> groupedLogs = {};
    if (workout['set_logs'] != null) {
      for (var log in (workout['set_logs'] as List)) {
        final name = log['exercises']['name'];
        groupedLogs.putIfAbsent(name, () => []).add(log);
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "WORKOUT",
          style: TextStyle(
            letterSpacing: 1.5,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== User Info + Routine + Stats =====
            _glassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF1C1C1E),
                        backgroundImage: (widget.avatarPath != null && widget.avatarPath!.isNotEmpty)
                            ? NetworkImage(widget.avatarPath!)
                            : null,
                        child: (widget.avatarPath == null || widget.avatarPath!.isEmpty)
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.username,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(DateFormat('EEEE, MMM d, yyyy • HH:mm').format(start),
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Routine Name
                  Text(
                    workout['routine_name'] ?? "FullBody Workout",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _stat("Time", "${duration}m"),
                      _stat("Volume", "${(workout['total_volume'] ?? 0).toInt()}kg"),
                      _stat("Sets", "${workout['total_sets'] ?? 0}"),
                      _stat("Records", "${workout['records_broken'] ?? 6}"),
                    ],
                  ),
                ],
              ),
            ),

            // ===== Muscle Split =====
            _glassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Muscle Split",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Row(
                      children: [
                        Expanded(flex: 33, child: Container(height: 8, color: Colors.purple)),
                        Expanded(flex: 17, child: Container(height: 8, color: Colors.blue)),
                        Expanded(flex: 17, child: Container(height: 8, color: Colors.orange)),
                        Expanded(flex: 17, child: Container(height: 8, color: Colors.green)),
                        Expanded(flex: 16, child: Container(height: 8, color: Colors.red)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _splitLabel("Shoulders 33%", Colors.purple),
                      _splitLabel("Legs 17%", Colors.blue),
                      _splitLabel("Back 17%", Colors.orange),
                      _splitLabel("Chest 17%", Colors.green),
                      _splitLabel("Arms 16%", Colors.red),
                    ],
                  ),
                ],
              ),
            ),

            // ===== Exercises =====
            ...groupedLogs.entries.map((e) => _buildExercise(e.key, e.value)).toList(),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---
  Widget _stat(String label, String val) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(val,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      );

  Widget _splitLabel(String text, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      );

  Widget _buildExercise(String name, List<dynamic> logs) {
    double maxScore = 0;
    double allTimePR = 0;

    for (var log in logs) {
      double w = (log['weight'] as num).toDouble();
      int reps = log['reps'] as int;
      double score = w * reps;
      if (score > maxScore) maxScore = score;
      if (score > allTimePR) allTimePR = score;
    }

    return _glassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              name.toUpperCase(),
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...logs.asMap().entries.map((e) {
            final log = e.value;
            double w = (log['weight'] as num).toDouble();
            int reps = log['reps'] as int;
            double score = w * reps;

            bool isPR = score >= allTimePR;
            bool isTopSet = score == maxScore;

            List<Widget> badges = [];
            if (isPR) badges.add(_buildBadge("PR", Colors.red));
            if (isTopSet) badges.add(_buildBadge("TOP SET", Colors.orange.withOpacity(0.7)));

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(width: 30, child: Text("${e.key + 1}", style: const TextStyle(color: Colors.grey, fontSize: 16))),
                  Text("${w}kg × $reps",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Row(children: badges),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _glassContainer({
  required Widget child,
  EdgeInsets? padding,
  BorderRadius? radius,
  double blurX = 10,
  double blurY = 10,
  double opacity = 0.05,      // subtle background
  double borderOpacity = 0.08, // subtle edge
}) {
  return ClipRRect(
    borderRadius: radius ?? BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
      child: Container(
        padding: padding ?? const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          borderRadius: radius ?? BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(borderOpacity)),
        ),
        child: child,
      ),
    ),
  );
}

}
