import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:ui';


class PRScreen extends StatefulWidget {
  const PRScreen({super.key});

  @override
  State<PRScreen> createState() => _PRScreenState();
}

class _PRScreenState extends State<PRScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _records = [];
  
  String? _expandedExerciseName;
  List<FlSpot> _chartData = [];
  List<String> _chartDates = [];

  @override
  void initState() {
    super.initState();
    _fetchPRs();
  }

  Future<void> _fetchPRs() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch ALL logs for this user, ordered by weight descending
      final response = await _supabase
          .from('set_logs')
          .select('''
            weight, 
            reps, 
            created_at,
            exercises!inner (
              id, 
              name, 
              primary_muscle
            )
          ''')
          .eq('user_id', user.id)
          .order('weight', ascending: false);

      // 2. Logic to filter for the HEAVIEST set per exercise
      final Map<String, dynamic> bestReps = {};
      
      for (var row in response as List) {
        final exerciseName = row['exercises']['name'];
        
        if (!bestReps.containsKey(exerciseName)) {
          // First time seeing this exercise = Heaviest weight (due to sorting)
          bestReps[exerciseName] = row;
        } else {
          // If weights are equal, take the one with more reps
          if (row['weight'] == bestReps[exerciseName]['weight'] && 
              row['reps'] > bestReps[exerciseName]['reps']) {
            bestReps[exerciseName] = row;
          }
        }
      }

      setState(() {
        _records = bestReps.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("PR Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchExerciseHistory(String exerciseId, String exerciseName) async {
    try {
      final user = _supabase.auth.currentUser;
      final response = await _supabase
          .from('set_logs')
          .select('weight, created_at')
          .eq('user_id', user!.id)
          .eq('exercise_id', exerciseId)
          .order('created_at', ascending: true);

      List<FlSpot> spots = [];
      List<String> dates = [];
      
      final data = response as List;
      for (int i = 0; i < data.length; i++) {
        double w = (data[i]['weight'] as num).toDouble();
        DateTime dt = DateTime.parse(data[i]['created_at']);
        spots.add(FlSpot(i.toDouble(), w));
        dates.add(DateFormat('MMM d').format(dt));
      }

      setState(() {
        _expandedExerciseName = exerciseName;
        _chartData = spots;
        _chartDates = dates;
      });
    } catch (e) {
      debugPrint("History Fetch Error: $e");
    }
  }

  double _calculate1RM(double weight, int reps) {
    if (reps <= 1) return weight;
    return weight * (1 + (reps / 30)); // Using Epley Formula for 1RM
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("PERSONAL RECORDS", 
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _records.isEmpty 
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _records.length,
                itemBuilder: (context, index) {
                  final record = _records[index];
                  final name = record['exercises']['name'];
                  final id = record['exercises']['id'].toString();
                  final bool isExpanded = _expandedExerciseName == name;

                  return GestureDetector(
                    onTap: () {
                      if (isExpanded) {
                        setState(() => _expandedExerciseName = null);
                      } else {
                        _fetchExerciseHistory(id, name);
                      }
                    },
                    child: AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  margin: const EdgeInsets.only(bottom: 16),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isExpanded
                ? Colors.blue.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          children: [
            _buildHeader(record, name),
            if (isExpanded) _buildChartSection(),
            if (!isExpanded) _buildStatsRow(record),
          ],
        ),
      ),
    ),
  ),
),

                  );
                },
              ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, color: Colors.white24, size: 60),
          const SizedBox(height: 16),
          const Text("No PRs found yet", style: TextStyle(color: Colors.grey)),
          const Text("Complete a workout to see your progress!", 
            style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> record, String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.toUpperCase(), 
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              Text(record['exercises']['primary_muscle'] ?? "Unknown", 
                style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Icon(
          _expandedExerciseName == name ? Icons.keyboard_arrow_up : Icons.bar_chart_rounded,
          color: _expandedExerciseName == name ? Colors.blue : Colors.white24,
        ),
      ],
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> record) {
    final double weight = (record['weight'] as num).toDouble();
    final int reps = record['reps'] as int;
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _statBlock("MAX WEIGHT", "${weight % 1 == 0 ? weight.toInt() : weight} kg"),
            _statBlock("REPS", "$reps"),
            _statBlock("EST. 1RM", "${_calculate1RM(weight, reps).toInt()} kg"),
          ],
        ),
      ],
    );
  }

  Widget _buildChartSection() {
    return Column(
      children: [
        const SizedBox(height: 20),
        SizedBox(
          height: 150,
          child: _chartData.isEmpty 
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) 
            : LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _chartData,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
                    ),
                  ],
                ),
              ),
        ),
      ],
    );
  }

  Widget _statBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}