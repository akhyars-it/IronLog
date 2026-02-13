import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'pr_screen.dart'; 
import 'dart:ui';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _selectedRange = '3M';

  int _totalWorkouts = 0;
  int _totalDuration = 0;
  double _totalVolume = 0;
  int _totalSetsGlobal = 0;

  Map<String, double> _muscleStats = {
    'Chest': 0, 'Back': 0, 'Shoulders': 0, 'Arms': 0, 'Legs': 0
  };
  
  Map<String, int> _dailySets = {}; 
  Map<String, Set<String>> _dailyMuscles = {}; 
  List<DateTime> _last7Days = [];
  int _selectedDayIndex = 6; 

  @override
  void initState() {
    super.initState();
    _generateDateList();
    _fetchAllStats();
  }

  void _generateDateList() {
    _last7Days = List.generate(7, (index) {
      return DateTime.now().subtract(Duration(days: 6 - index));
    });
  }

  Future<void> _fetchAllStats() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchWeeklyActivity(),
      _fetchMuscleDistribution(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchWeeklyActivity() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      final response = await _supabase
          .from('workouts')
          .select('''
            start_time,
            set_logs (
              exercises (
                primary_muscle
              )
            )
          ''')
          .eq('user_id', userId)
          .gte('start_time', _last7Days.first.toIso8601String());

      Map<String, int> tempDailySets = {for (var d in _last7Days) DateFormat('yyyy-MM-dd').format(d): 0};
      Map<String, Set<String>> tempDailyMuscles = {for (var d in _last7Days) DateFormat('yyyy-MM-dd').format(d): {}};

      for (var workout in response) {
        final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.parse(workout['start_time']));
        if (tempDailyMuscles.containsKey(dateKey)) {
          final logs = workout['set_logs'] as List<dynamic>;
          tempDailySets[dateKey] = tempDailySets[dateKey]! + logs.length;
          for (var log in logs) {
            final muscle = log['exercises']['primary_muscle']?.toString().toLowerCase();
            if (muscle != null) tempDailyMuscles[dateKey]!.add(muscle);
          }
        }
      }

      setState(() {
        _dailySets = tempDailySets;
        _dailyMuscles = tempDailyMuscles;
      });
    } catch (e) { debugPrint("Error: $e"); }
  }

  Future<void> _fetchMuscleDistribution() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final days = _selectedRange == '30D' ? 30 : 90;
      final startDate = DateTime.now().subtract(Duration(days: days));

      final workoutRes = await _supabase
          .from('workouts')
          .select('id, total_sets, total_volume, start_time, end_time')
          .eq('user_id', userId as Object)
          .gte('start_time', startDate.toIso8601String());

      int workoutsCount = 0;
      int dur = 0;
      double vol = 0;
      int s = 0;
      List<String> workoutIds = [];

      for (var row in workoutRes) {
        workoutsCount++;
        workoutIds.add(row['id'].toString());
        s += (row['total_sets'] as int? ?? 0);
        vol += (row['total_volume'] as num? ?? 0).toDouble();
        if (row['end_time'] != null) {
          dur += DateTime.parse(row['end_time']).difference(DateTime.parse(row['start_time'])).inMinutes;
        }
      }

      Map<String, double> updatedMuscles = {'Chest': 0, 'Back': 0, 'Shoulders': 0, 'Arms': 0, 'Legs': 0};

      if (workoutIds.isNotEmpty) {
        final logRes = await _supabase
            .from('set_logs')
            .select('exercises!inner(primary_muscle)')
            .filter('workout_id', 'in', '(${workoutIds.join(",")})');

        for (var row in logRes) {
          final muscle = row['exercises']['primary_muscle'];
          if (muscle != null && updatedMuscles.containsKey(muscle)) {
            updatedMuscles[muscle] = updatedMuscles[muscle]! + 1.0;
          }
        }
      }

      setState(() {
        _muscleStats = updatedMuscles;
        _totalWorkouts = workoutsCount;
        _totalDuration = dur;
        _totalVolume = vol;
        _totalSetsGlobal = s;
      });
    } catch (e) { debugPrint("Error: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("STATISTICS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined, color: Colors.orange, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PRScreen())),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.blue))
        : RefreshIndicator(
            onRefresh: _fetchAllStats,
            color: Colors.blue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSetsOverview(),
                  const SizedBox(height: 30),
                  const Text("MUSCLES WORKED", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  const SizedBox(height: 15),
                  _buildMuscleGrid(), // The high-performance heatmap replacement
                  const SizedBox(height: 30),
                  _buildWeeklyDaySelector(),
                  const SizedBox(height: 50),
                  _buildSectionHeader(),
                  _buildHevyRadarChart(),
                  const SizedBox(height: 50), 
                  _buildHevyStatsOverview(), 
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildMuscleGrid() {
    final dateKey = DateFormat('yyyy-MM-dd').format(_last7Days[_selectedDayIndex]);
    final musclesWorkedToday = _dailyMuscles[dateKey] ?? {};
    final allMuscles = ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs'];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: allMuscles.map((muscle) {
        bool isActive = musclesWorkedToday.any((m) => 
          m.contains(muscle.toLowerCase()) || muscle.toLowerCase().contains(m));

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue.withOpacity(0.15) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isActive ? Colors.blue.withOpacity(0.5) : Colors.white10),
          ),
          child: Text(
            muscle.toUpperCase(),
            style: TextStyle(
              color: isActive ? Colors.blue : Colors.grey.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSetsOverview() {
  String formattedDay = DateFormat('EEEE').format(_last7Days[_selectedDayIndex]).toUpperCase();
  final dateKey = DateFormat('yyyy-MM-dd').format(_last7Days[_selectedDayIndex]);
  int total = _dailySets[dateKey] ?? 0;

  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 25),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(
              "TOTAL SETS - $formattedDay",
              style: const TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1.1),
            ),
            const SizedBox(height: 10),
            Text(
              "$total",
              style: const TextStyle(
                color: Color(0xFFFFA500),
                fontSize: 42,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildWeeklyDaySelector() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: List.generate(7, (index) {
      bool isSelected = index == _selectedDayIndex;
      DateTime date = _last7Days[index];

      return GestureDetector(
        onTap: () => setState(() => _selectedDayIndex = index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(isSelected ? 0.1 : 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? Colors.blue.withOpacity(0.5) : Colors.transparent),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('E').format(date)[0],
                    style: TextStyle(
                        color: isSelected ? Colors.blue : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('d').format(date),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }),
  );
}

  Widget _buildSectionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Muscle distribution", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
  value: _selectedRange == '30D' ? '30 Days' : '3 Months',
  dropdownColor: const Color(0xFF1C1C1E),
  underline: const SizedBox(),
  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.blue, size: 20),
  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
  items: ['30 Days', '3 Months'].map((String value) {
    return DropdownMenuItem(
      value: value,
      child: Text(value),
    );
  }).toList(),
  onChanged: (String? newValue) {
    if (newValue != null) {
      setState(() {
        _selectedRange = newValue == '30 Days' ? '30D' : '3M';
      });
      _fetchMuscleDistribution();
    }
  },
),

          ],
        ),
        Text("Sets over last ${_selectedRange == '30D' ? '30 days' : '3 months'}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildHevyRadarChart() {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: AspectRatio(
          aspectRatio: 1.3,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              ticksTextStyle: const TextStyle(color: Colors.transparent),
              gridBorderData: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
              tickBorderData: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
              titleTextStyle: const TextStyle(color: Colors.grey, fontSize: 11),
              getTitle: (index, angle) {
                return RadarChartTitle(
                  text: ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs'][index % 5],
                );
              },
              dataSets: [
                RadarDataSet(
                  fillColor: Colors.blue.withOpacity(0.25),
                  borderColor: Colors.blue,
                  entryRadius: 3,
                  dataEntries: [
                    RadarEntry(value: _muscleStats['Chest'] ?? 0),
                    RadarEntry(value: _muscleStats['Back'] ?? 0),
                    RadarEntry(value: _muscleStats['Shoulders'] ?? 0),
                    RadarEntry(value: _muscleStats['Arms'] ?? 0),
                    RadarEntry(value: _muscleStats['Legs'] ?? 0),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}



  Widget _hevyStatItem(String value, String label) => Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Color(0xFFFFA500), fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );

  Widget _buildHevyStatsOverview() {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _hevyStatItem(_totalWorkouts.toString(), "Workouts"),
            _hevyStatItem("${(_totalDuration / 60).toStringAsFixed(1)}h", "Duration"),
            _hevyStatItem(
              _totalVolume >= 1000
                  ? "${(_totalVolume / 1000).toStringAsFixed(1)}k"
                  : _totalVolume.toInt().toString(),
              "kg Volume",
            ),
            _hevyStatItem(_totalSetsGlobal.toString(), "Sets"),
          ],
        ),
      ),
    ),
  );
}
}