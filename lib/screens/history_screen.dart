import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/workout_history_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _supabase = Supabase.instance.client;
  List<WorkoutHistory> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // LOGIC FIX: Joined query to get workouts AND the exercises inside them
      // This matches the nested structure in our updated WorkoutHistory model
      final data = await _supabase
          .from('workouts')
          .select('''
            *,
            set_logs (
              weight,
              reps,
              exercises (name)
            )
          ''')
          .eq('user_id', userId)
          .order('start_time', ascending: false);
      
      if (mounted) {
        setState(() {
          _history = (data as List).map((e) => WorkoutHistory.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Workout History"),
        actions: [
          IconButton(onPressed: _fetchHistory, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchHistory,
            child: _history.isEmpty 
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final workout = _history[index];
                    return _buildWorkoutPost(workout);
                  },
                ),
          ),
    );
  }

  Widget _buildWorkoutPost(WorkoutHistory workout) {
    String formattedDate = DateFormat('EEEE, MMM d • h:mm a').format(workout.startTime);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workout.routineName, 
                style: const TextStyle(color: Colors.blue, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPostStat(Icons.timer_outlined, _getDuration(workout)),
                _buildPostStat(Icons.fitness_center, "${workout.totalVolume.toInt()} kg"),
                _buildPostStat(Icons.format_list_bulleted, "${workout.totalSets} sets"),
              ],
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Colors.white10),
            ),

            // Requirement #9: Preview of exercises performed
            if (workout.sets != null && workout.sets!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: workout.sets!.take(3).map((set) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    "• ${set.exerciseName}: ${set.reps} reps @ ${set.weight}kg",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                )).toList(),
              ),
            
            if (workout.sets != null && workout.sets!.length > 3)
              const Text("...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildPostStat(IconData icon, String val) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[800]),
          const SizedBox(height: 16),
          const Text("No workouts logged yet.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  String _getDuration(WorkoutHistory workout) {
    if (workout.endTime == null) return "--";
    final diff = workout.endTime!.difference(workout.startTime);
    return "${diff.inMinutes}m";
  }
}