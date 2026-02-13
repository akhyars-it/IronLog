import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/exercise_model.dart';

class ExerciseDetailsScreen extends StatefulWidget {
  final Exercise exercise;
  const ExerciseDetailsScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailsScreen> createState() => _ExerciseDetailsScreenState();
}

class _ExerciseDetailsScreenState extends State<ExerciseDetailsScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _logs = [];
  bool _isLoading = true;

  // Stats
  double _bestWeight = 0;
  double _best1RM = 0;
  double _bestSessionVolume = 0;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final data = await _supabase
          .from('set_logs')
          .select('*, workouts(start_time)')
          .eq('exercise_id', widget.exercise.id)
          .order('created_at', ascending: true);

      final logs = data as List<dynamic>;

      // Logic: Calculate Personal Records
      double maxWeight = 0;
      double max1RM = 0;
      Map<String, double> sessionVolumes = {};

      for (var log in logs) {
        double w = (log['weight'] ?? 0).toDouble();
        int r = (log['reps'] ?? 0).toInt();
        String workoutId = log['workout_id'].toString();

        // 1. Best Weight
        if (w > maxWeight) maxWeight = w;

        // 2. Best 1RM (Brzycki Formula)
        if (r > 0) {
          double current1RM = w * (36 / (37 - r));
          if (current1RM > max1RM) max1RM = current1RM;
        }

        // 3. Track Session Volume
        sessionVolumes[workoutId] = (sessionVolumes[workoutId] ?? 0) + (w * r);
      }

      double maxVolume = sessionVolumes.isEmpty 
          ? 0 
          : sessionVolumes.values.reduce((a, b) => a > b ? a : b);

      setState(() {
        _logs = logs;
        _bestWeight = maxWeight;
        _best1RM = max1RM;
        _bestSessionVolume = maxVolume;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("History Error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(widget.exercise.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.blue))
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderTabs(),
                _buildGraphSection(),
                _buildPRSection(),
              ],
            ),
          ),
    );
  }

  Widget _buildHeaderTabs() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Primary: ${widget.exercise.primaryMuscle}", style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 20),
          const Text("SUMMARY", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          const Divider(color: Colors.blue, thickness: 2, endIndent: 300),
        ],
      ),
    );
  }

  Widget _buildGraphSection() {
    if (_logs.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text("No data tracked yet", style: TextStyle(color: Colors.grey))));
    }

    return Container(
      height: 220,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 0),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _logs.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), (e.value['weight'] ?? 0).toDouble());
              }).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPRSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text("Personal Records", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _prRow("Heaviest Weight", "${_bestWeight.toStringAsFixed(1)}kg"),
          _prRow("Best 1RM", "${_best1RM.toStringAsFixed(1)}kg"),
          _prRow("Best Session Volume", "${_bestSessionVolume.toStringAsFixed(1)}kg"),
        ],
      ),
    );
  }

  Widget _prRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 15)),
          Text(value, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}