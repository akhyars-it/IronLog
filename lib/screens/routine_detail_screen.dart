import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise_model.dart';
import 'live_workout_screen.dart';
import 'edit_routine_screen.dart';
import 'dart:ui';

class RoutineDetailScreen extends StatefulWidget {
  final Map<String, dynamic> routine;

  const RoutineDetailScreen({super.key, required this.routine});

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  final _supabase = Supabase.instance.client;
  List<FlSpot> _volumeSpots = [];
  bool _isLoadingGraph = true;
  late Map<String, dynamic> _currentRoutine;

  @override
  void initState() {
    super.initState();
    _currentRoutine = widget.routine;
    _fetchRoutineHistory();
  }

  Future<void> _fetchRoutineHistory() async {
    try {
      final data = await _supabase
          .from('workouts')
          .select('total_volume, start_time')
          .eq('routine_name', _currentRoutine['title'])
          .order('start_time', ascending: true)
          .limit(10);

      final List<FlSpot> spots = [];
      for (int i = 0; i < data.length; i++) {
        double vol = (data[i]['total_volume'] as num).toDouble();
        spots.add(FlSpot(i.toDouble(), vol));
      }

      if (mounted) {
        setState(() {
          _volumeSpots = spots;
          _isLoadingGraph = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching graph data: $e");
      if (mounted) setState(() => _isLoadingGraph = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercises = (_currentRoutine['routine_exercises'] as List);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(_currentRoutine['title'], style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditRoutineScreen(routine: _currentRoutine),
                ),
              );
              
              if (updated == true && mounted) {
                // Refresh logic if needed, or pop back to workout hub
                Navigator.pop(context, true); 
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Volume Trend (Last 10 Sessions)", 
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.1)
            ),
            const SizedBox(height: 25), // Increased spacing for axis titles
            
            // GRAPH SECTION
            ClipRRect(
  borderRadius: BorderRadius.circular(20),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
    child: Container(
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: _isLoadingGraph
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            )
          : _volumeSpots.isEmpty
              ? _buildEmptyGraph()
              : _buildVolumeChart(),
    ),
  ),
),

            
            const SizedBox(height: 35),
            const Text(
              "Exercises", 
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 12),

            // EXERCISE LIST
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final ex = exercises[index]['exercises'];
                return Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.fitness_center,
              color: Colors.blue,
              size: 20,
            ),
          ),
          title: Text(
            ex['name'],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            "${ex['primary_muscle']} • ${ex['equipment'] ?? 'Bodyweight'}",
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ),
      ),
    ),
  ),
);

              },
            ),
            
            const SizedBox(height: 40),
            
            // CTA BUTTON
            SizedBox(
  width: double.infinity,
  height: 60,
  child: ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: InkWell(
        onTap: () {
          final List<Exercise> selectedExercises = exercises
              .map((re) => Exercise.fromJson(re['exercises']))
              .toList();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LiveWorkoutScreen(
                routineTitle: _currentRoutine['title'],
                initialExercises: selectedExercises,
              ),
            ),
          );
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.blue.withOpacity(0.5),
            ),
          ),
          child: const Text(
            "START WORKOUT",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ),
  ),
),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeChart() {
    return LineChart(
      LineChartData(
        // Grid setup
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white10,
            strokeWidth: 1,
          ),
        ),
        // Axis Title Setup
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 8,
                  child: Text(
                    "S${value.toInt() + 1}", // Session 1, Session 2...
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                // Only show every few values to keep it clean
                return Text(
                  "${value.toInt()}kg",
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _volumeSpots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
                radius: 4,
                color: Colors.blue,
                strokeWidth: 2,
                strokeColor: Colors.black,
              ),
            ),
            belowBarData: BarAreaData(
              show: true, 
              color: Colors.blue.withOpacity(0.1)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyGraph() {
  return ClipRRect(
    borderRadius: BorderRadius.circular(15),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined,
                  color: Colors.white24,
                  size: 40),
              const SizedBox(height: 8),
              const Text(
                "No workout data yet",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}