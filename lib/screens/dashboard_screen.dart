import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'stats_screen.dart';
import 'exercise_library_screen.dart';
import 'calendar_screen.dart';
import 'edit_profile_screen.dart';
import 'workout_page.dart';
import 'workout_details_screen.dart';
import '../main.dart'; 
import 'dart:ui';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  String _fullName = "Loading...";
  String _bio = "";
  String _username = "";
  String? _avatarUrl; 
  int _setsThisWeek = 0;
  String _gender = "male";

  double _bmi = 0;
  double _ffmi = 0;
  double _currentWeight = 0;
  double _targetWeight = 0;
  double _benchRatio = 0; 
  double _maxBench = 0;
  double _bodyFat = 0;
  double _heightCm = 0;

  List<dynamic> _history = [];
  bool _showAllHistory = false;
  List<BarChartGroupData> _graphGroups = [];
  bool _isLoading = true;
  String _selectedMetric = 'Volume'; 
  String _selectedRange = '30 Days';     
  
  double _highlightedValue = 0;
  String _highlightedLabel = "Activity Tracking";

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
  if (!mounted) return;
  setState(() => _isLoading = true);

  try {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // --- Fetch profile ---
    final profileData = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    // --- Fetch workout history ---
    final historyResponse = await _supabase
        .from('workouts')
        .select('*, set_logs(weight, reps, exercises(name, category, primary_muscle))')
        .eq('user_id', user.id)
        .order('start_time', ascending: false);

    // --- Determine date range for graph ---
    final rangeDays = _selectedRange == '3 Months' ? 90 : 30;
    final startDate = DateTime.now().subtract(Duration(days: rangeDays));

    // --- Graph data ---
    final graphResponse = await _supabase
        .from('workouts')
        .select('start_time, total_volume, total_sets')
        .eq('user_id', user.id)
        .gte('start_time', startDate.toIso8601String());

    // --- Last bench session logic ---
    double maxBench = 0;
    final lastBenchWorkoutList = await _supabase
    .from('workouts')
    .select('id')
    .eq('user_id', user.id)
    .order('start_time', ascending: false)
    .limit(1);

if (lastBenchWorkoutList.isNotEmpty) {
  final lastWorkoutId = lastBenchWorkoutList[0]['id'];

  final lastBenchSet = await _supabase
      .from('set_logs')
      .select('weight, exercises!inner(name, category)')
      .eq('user_id', user.id)
      .eq('workout_id', lastWorkoutId)
      .eq('exercises.category', 'bench')
      .order('weight', ascending: false)
      .limit(1);

  if (lastBenchSet.isNotEmpty) {
    maxBench = (lastBenchSet[0]['weight'] as num).toDouble();
  }
}


    // --- Weekly sets ---
    int weeklySets = 0;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    for (var w in graphResponse) {
      final wDate = DateTime.parse(w['start_time']);
      if (wDate.isAfter(startOfWeek)) {
        weeklySets += (w['total_sets'] as int? ?? 0);
      }
    }

    // --- Profile metrics ---
    final double weight = (profileData['current_weight'] ?? 0).toDouble();
    final double hCm = (profileData['height'] ?? 0).toDouble();
    final double bFat = (profileData['current_body_fat'] ?? 0).toDouble();
    final double heightM = hCm / 100;

    if (mounted) {
      setState(() {
        _username = profileData['username'] ?? user.email?.split('@').first ?? "User";
        _fullName = profileData['full_name'] ?? "Fitness Athlete";
        _bio = profileData['bio'] ?? "";
        _avatarUrl = profileData['avatar_url'];
        _gender = profileData['gender'] ?? "male";

        _setsThisWeek = weeklySets;
        _history = historyResponse as List<dynamic>;
        _graphGroups = _generateGraphData(graphResponse as List<dynamic>, rangeDays);

        _currentWeight = weight;
        _heightCm = hCm;
        _bodyFat = bFat;
        _targetWeight = (profileData['target_weight'] ?? 0).toDouble();
        _maxBench = maxBench;

        if (heightM > 0 && weight > 0) {
          _bmi = weight / (heightM * heightM);
        }
        if (heightM > 0 && weight > 0 && _bodyFat > 0) {
          double lbm = weight * (1 - (_bodyFat / 100));
          _ffmi = lbm / (heightM * heightM);
        }
        if (_currentWeight > 0 && _maxBench > 0) {
          _benchRatio = _maxBench / _currentWeight;
        }

        _isLoading = false;
      });
    }
  } catch (e) {
    if (mounted) setState(() => _isLoading = false);
    print("Error fetching dashboard data: $e");
  }
}


  Future<void> _showBodyFatCalculator() async {
    final waistController = TextEditingController();
    final neckController = TextEditingController();
    final hipController = TextEditingController();

    await showDialog(
  context: context,
  builder: (context) {
    return Dialog(
      backgroundColor: Colors.transparent, // important for glass effect
      insetPadding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // blur intensity
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3), // semi-transparent overlay
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)), // optional subtle border
            ),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.straighten, color: Colors.blue, size: 30),
                  const SizedBox(height: 10),
                  const Text(
                    "Navy Seal Calculator",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "The U.S. Navy Method uses tape measurements to estimate body fat percentage with high reliability.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  
                  // Waist
                  TextField(
                    controller: waistController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Waist (cm)",
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Neck
                  TextField(
                    controller: neckController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Neck (cm)",
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  if (_gender == "female") ...[
                    const SizedBox(height: 15),
                    TextField(
                      controller: hipController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Hips (cm)",
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          double w = double.tryParse(waistController.text) ?? 0;
                          double n = double.tryParse(neckController.text) ?? 0;
                          double h = _heightCm;
                          double result = 0;
                          if (w > 0 && n > 0 && h > 0) {
                            if (_gender == "male") {
                              result = 495 / (1.0324 - 0.19077 * (math.log(w - n) / math.ln10) + 0.15456 * (math.log(h) / math.ln10)) - 450;
                            } else {
                              double hip = double.tryParse(hipController.text) ?? 0;
                              result = 495 / (1.29579 - 0.35004 * (math.log(w + hip - n) / math.ln10) + 0.22100 * (math.log(h) / math.ln10)) - 450;
                            }

                            await _supabase.from('profiles').update({
                              'current_body_fat': double.parse(result.toStringAsFixed(1)).clamp(3.0, 50.0),
                            }).eq('id', _supabase.auth.currentUser!.id);
                            if (mounted) Navigator.pop(context);
                            _fetchDashboardData();
                          }
                        },
                        child: const Text(
                          "Calculate & Update",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  },
);
  }

  void _showInfoDialog(String title, String content, {bool showCalc = false}) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: _glassContainer(
        radius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 15),
            Text(content,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.6),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (showCalc)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showBodyFatCalculator();
                },
                child: const Text("Open Calculator",
                    style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Got it",
                  style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    ),
  );
}


  // --- RESTORED ORIGINAL TEXT ---
  void _infoBMI() => _showInfoDialog("BMI", "Body Mass Index (BMI) is a simple tool using height and weight to estimate if you are in a healthy weight range. While important for general health risk assessment, it doesnt distinguish between muscle and fat. For lifters, it's best used as a baseline alongside FFMI.");
  void _infoFFMI() => _showInfoDialog("FFMI", "Fat-Free Mass Index (FFMI) measures muscle mass relative to your height. While BMI might label a muscular person as 'overweight', a high FFMI confirms that the weight is quality muscle. Tap the calculator to estimate your body fat using measurements.", showCalc: true);
  void _infoStrength() => _showInfoDialog("Strength", "This measures 'Relative Strength', how powerful you are for your size. We use the Bench Categories as the universal benchmark for upper-body integrity. A 1.0x ratio is equal to beching your own bodyweight and that's 'Strong'. 1.5x is 'Advanced' and 2.0x is 'Elite'.");
  void _infoGoal() => _showInfoDialog("Goal", "Goal tracks the distance between your current scale weight and your target. Ensure your progress is sustainable by aiming for a 0.5% - 1% change in your weight per week.");

  Widget _glassContainer({
  required Widget child,
  EdgeInsets? padding,
  BorderRadius? radius,
}) {
  return ClipRRect(
    borderRadius: radius ?? BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: radius ?? BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: child,
      ),
    ),
  );
}


  Widget _buildMetricLabel(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Icon(Icons.help_outline, color: Colors.grey.withOpacity(0.5), size: 12),
      ],
    );
  }

Future<void> _showEditWorkoutDialog(Map<String, dynamic> workout) async {
  DateTime start = DateTime.parse(workout['start_time']);
  DateTime end = workout['end_time'] != null 
      ? DateTime.parse(workout['end_time']) 
      : start.add(const Duration(hours: 1));

  DateTime selectedDate = start;
  TimeOfDay startTime = TimeOfDay.fromDateTime(start);
  TimeOfDay endTime = TimeOfDay.fromDateTime(end);

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Manage Workout Log",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Workout Date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    radius: 16,
                    child: Icon(Icons.calendar_today, size: 16, color: Colors.white),
                  ),
                  title: const Text(
                    "Workout Date",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    DateFormat('MMMM dd, yyyy').format(selectedDate),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2022),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setDialogState(() => selectedDate = d);
                  },
                ),
                SizedBox(height: 10),

                // Workout Duration
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    radius: 16,
                    child: Icon(Icons.access_time, size: 16, color: Colors.white),
                  ),
                  title: const Text(
                    "Workout Duration",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    "${startTime.format(context)} to ${endTime.format(context)}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () async {
                    final t1 = await showTimePicker(context: context, initialTime: startTime);
                    if (t1 != null) {
                      final t2 = await showTimePicker(context: context, initialTime: endTime);
                      if (t2 != null) setDialogState(() {
                        startTime = t1;
                        endTime = t2;
                      });
                    }
                  },
                ),
                SizedBox(height: 10),
                // Delete Entire Log
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    radius: 16,
                    child: Icon(Icons.delete_forever, size: 16, color: Colors.white),
                  ),
                  title: const Text(
                    "Delete Entire Log",
                    style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: const Color(0xFF1C1C1E),
                        title: const Text("Are you sure?"),
                        content: const Text("This workout log and all sets will be deleted forever."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text("Delete", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _supabase.from('workouts').delete().eq('id', workout['id']);
                      if (mounted) Navigator.pop(context);
                      _fetchDashboardData();
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () async {
                // Save Changes
                final newStart = DateTime(
                  selectedDate.year, 
                  selectedDate.month, 
                  selectedDate.day, 
                  startTime.hour, 
                  startTime.minute,
                );

                var finalEnd = DateTime(
                  selectedDate.year, 
                  selectedDate.month, 
                  selectedDate.day, 
                  endTime.hour, 
                  endTime.minute,
                );

                if (finalEnd.isBefore(newStart)) {
                  finalEnd = finalEnd.add(const Duration(days: 1));
                }

                await _supabase.from('workouts').update({
                  'start_time': newStart.toIso8601String(),
                  'end_time': finalEnd.toIso8601String(),
                  'duration_seconds': finalEnd.difference(newStart).inSeconds,
                }).eq('id', workout['id']);

                if (mounted) {
                  Navigator.pop(context);
                  await _fetchDashboardData();
                }
              },
              child: const Text("Save Changes"),
            ),
          ],
        );
      },
    ),
  );
}

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: false,
      title: Text(_username,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent, size: 24),
          onPressed: () async {
            await _supabase.auth.signOut();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => MyApp()),
                  (route) => false);
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
          onPressed: () async {
            await Navigator.push(
                context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
            _fetchDashboardData();
          },
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: _isLoading
    ? const Center(child: CircularProgressIndicator(color: Colors.blue))
    : RefreshIndicator(
        color: Colors.blue,
        backgroundColor: const Color(0xFF1C1C1E),
        onRefresh: _fetchDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- User Info ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: const Color(0xFF1C1C1E),
                        backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                        child: _avatarUrl == null
                            ? const Icon(Icons.person, color: Colors.grey, size: 45)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fullName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          if (_bio.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(_bio,
                                style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text("$_setsThisWeek SETS THIS WEEK",
                                style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- Metric Cards: BMI / FFMI / Strength / Goal ---
              // --- Combined Metrics (Glass Container) ---
              // --- BMI, FFMI, STRENGTH, GOAL SECTION ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: _glassContainer(
                  child: Column( // Use Column here to stack the Row and the Progress Bar
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                        
                          // BMI
                          GestureDetector(
                            onTap: _infoBMI,
                            child: Column(
                              children: [
                                _buildMetricLabel("BMI"),
                                const SizedBox(height: 5),
                               Text(_bmi.toStringAsFixed(1),
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(_getBMICategory(_bmi),
                                  style: const TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),

                          // FFMI
                          GestureDetector(
                            onTap: _infoFFMI,
                            child: Column(
                              children: [
                                _buildMetricLabel("FFMI"),
                                const SizedBox(height: 5),
                                Text(_ffmi > 0 ? _ffmi.toStringAsFixed(1) : "--",
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(_bodyFat > 0 ? "${_bodyFat.toStringAsFixed(1)}% FAT" : "CALCULATE",
                                  style: const TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),

                          // STRENGTH
                          GestureDetector(
                            onTap: _infoStrength,
                            child: Column(
                              children: [
                                _buildMetricLabel("STRENGTH"),
                                const SizedBox(height: 5),
                                Text(_benchRatio > 0 ? "${_benchRatio.toStringAsFixed(2)}x" : "--",
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const Text("BENCH/BW",
                                  style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),

                         // GOAL
                          GestureDetector(
                            onTap: _infoGoal,
                            child: Column(
                              children: [
                                _buildMetricLabel("GOAL"),
                                const SizedBox(height: 5),
                                Text("${_targetWeight.toInt()}kg",
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text("${(_targetWeight - _currentWeight).abs().toStringAsFixed(1)}kg LEFT",
                                  style: TextStyle(
                                    color: _targetWeight > _currentWeight ? Colors.orange : Colors.green,
                                    fontSize: 9,
                                  fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Progress Bar
                      Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3), // Slightly transparent black for glass look
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: _targetWeight > 0 ? (_currentWeight / _targetWeight).clamp(0.0, 1.0) : 0,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.cyanAccent]),
                                    borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // --- Weekly Graph ---
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
                  child: _glassContainer(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                      // ===== Header Row ===== 
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _highlightedLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _selectedMetric == 'Volume'
                                      ? "Weekly Training Volume (kg)"
                                      : "Weekly Total Sets",
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                            ),
                
                            // ===== Glass-Like Dropdown =====
DropdownButtonHideUnderline(
  child: DropdownButton<String>(
    value: _selectedRange,
    dropdownColor: const Color(0xFF1C1C1E), // menu color
    icon: const Icon(
      Icons.keyboard_arrow_down,
      color: Colors.blue,
      size: 18,
    ),
    style: const TextStyle(
      color: Colors.blue,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    ),
    items: ['30 Days', '3 Months'].map((range) {
      return DropdownMenuItem<String>(
        value: range,
        child: Text(range),
      );
    }).toList(),
    onChanged: (val) {
      if (val != null) {
        setState(() => _selectedRange = val);
        _fetchDashboardData();
      }
    },
  ),
),


                          ],
                        ),

                        const SizedBox(height: 20),

                        // ===== Bar Chart =====
                        SizedBox(
                          height: 180,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: _graphGroups.isEmpty ? 100 : null,
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      "${rod.toY.toInt()}",
                                      const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                ),
                                touchCallback: (event, response) {
                                 if (response != null && response.spot != null) {
                                    setState(() {
                                      _highlightedValue =
                                      response.spot!.touchedRodData.toY;

                                      int weeksAgo =
                                        (_graphGroups.length - 1) -
                                        response.spot!.touchedBarGroupIndex;

                                      _highlightedLabel =
                                        weeksAgo == 0
                                          ? "Current Week"
                                          : "$weeksAgo Weeks Ago";
                                    });
                                  }
                                },
                              ),

                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (val, meta) {
                                      if (val % 2 != 0) {
                                        return const SizedBox();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          "W${val.toInt()}",
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 10,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (val, meta) {
                                      return Text(
                                        val >= 1000
                                          ? "${(val / 1000).toStringAsFixed(0)}k"
                                          : val.toInt().toString(),
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (v) {
                                  return FlLine(
                                    color: Colors.white.withOpacity(0.05),
                                    strokeWidth: 1,
                                  );
                                },
                              ),
                              
                              borderData: FlBorderData(show: false),
                              barGroups: _graphGroups,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ===== Metric Chips =====
                        Row(
                          children: [
                          _buildMetricChip('Volume'),
                          const SizedBox(width: 10),
                          _buildMetricChip('Sets'),
                        ],
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Navigation Tiles --- 
                Padding( 
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 15), 
                    child: GridView.count( 
                      shrinkWrap: true, 
                      physics: const NeverScrollableScrollPhysics(), 
                      crossAxisCount: 2, 
                      crossAxisSpacing: 12, 
                      mainAxisSpacing: 12, 
                      childAspectRatio: 2.4, 
                      children: [ 
                        _buildNavTile( 
                          "Statistics", Icons.analytics_outlined, const StatsScreen(), Colors.blue), 
                        _buildNavTile( 
                          "Exercises", Icons.fitness_center_rounded, const ExerciseLibraryScreen(),Colors.orange), 
                        _buildNavTile( 
                          "Start Workout", Icons.play_circle_fill, const WorkoutPage(), Colors.green), 
                        _buildNavTile( 
                            "Calendar", Icons.calendar_month_rounded, const CalendarScreen(), Colors.purple), 
                     ],
                    ),
                  ), 
                  // --- Training History --- 
                  Padding( 
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 15), 
                    child: Row( 
                      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                      children: [ 
                        const Text(
                          "TRAINING HISTORY", 
                          style: TextStyle( 
                            color: Colors.white, 
                            fontSize: 14, 
                            fontWeight: FontWeight.w900, 
                            letterSpacing: 1.5
                          )
                        ), 
                        
                        if (_history.length > 3) 
                        GestureDetector( 
                          onTap: () => setState(() => _showAllHistory = !_showAllHistory), 
                            child: Container( 
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                              decoration: BoxDecoration( 
                                border: Border.all(color: Colors.blue), 
                                borderRadius: BorderRadius.circular(15)), 
                                child: Text(
                                  _showAllHistory ? "SHOW LESS" : "SEE ALL", 
                                  style: const TextStyle( 
                                    color: Colors.blue, 
                                    fontSize: 10, 
                                    fontWeight: FontWeight.bold
                                  )
                                ), 
                            ),
                        ), 
                      ], 
                    ),
                  ), 
                    
                  _buildHistoryListView(), 
                  const SizedBox(height: 100),
              ]
            ),
          ),
        ),
    );
  } 

  Widget _buildNavTile(String title, IconData icon, Widget screen, Color color) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      borderRadius: BorderRadius.circular(20),
      child: _glassContainer(
        padding: const EdgeInsets.symmetric(vertical: 18),
        radius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }


  Widget _buildMetricChip(String label) {
  bool isSelected = _selectedMetric == label;

  return GestureDetector(
    onTap: () {
      setState(() => _selectedMetric = label);
      _fetchDashboardData();
    },
    child: Stack(
      children: [

        // Base glass
        _glassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          radius: BorderRadius.circular(20),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Blue glow overlay if selected
        if (isSelected)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 8,
                  )
                ],
              ),
            ),
          ),
      ],
    ),
  );
}


  Widget _buildHistoryListView() {
    final items = _showAllHistory ? _history : _history.take(3).toList();
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text("No workouts logged yet. Start training!", style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: items.length,
  itemBuilder: (context, index) {
    final workout = items[index];
    final start = DateTime.parse(workout['start_time']);
    final endString = workout['end_time'];
    final String? workoutNote = workout['notes'];

    int duration = (workout['duration_seconds'] ?? 0) ~/ 60;
    if (duration == 0 && endString != null) {
      final end = DateTime.parse(endString);
      duration = end.difference(start).inMinutes;
    }

    Map<String, int> exerciseSummary = {};
    for (var log in workout['set_logs'] ?? []) {
      if (log['exercises'] != null) {
        String name = log['exercises']['name'];
        exerciseSummary[name] = (exerciseSummary[name] ?? 0) + 1;
      }
    }
    final summaryList = exerciseSummary.entries.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _glassContainer(
            padding: const EdgeInsets.all(0),
            radius: BorderRadius.circular(28),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkoutDetailsScreen(
                    workout: workout,
                    username: _username,
                    avatarPath: _avatarUrl,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// HEADER
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: _avatarUrl != null
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          backgroundColor: const Color(0xFF1C1C1E),
                          child: _avatarUrl == null
                              ? const Icon(Icons.person,
                                  size: 12, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              DateFormat('EEEE, MMM dd').format(start),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.more_horiz,
                              color: Colors.grey),
                          onPressed: () =>
                              _showEditWorkoutDialog(workout),
                        ),
                      ],
                    ),
                  ),

                  /// BODY
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        /// Workout Title
                        Text(
                          workout['routine_name'] ?? "Custom Workout",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),

                        /// Notes
                        if (workoutNote != null &&
                            workoutNote.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            workoutNote,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        /// Mini Stats
                        Row(
                          children: [
                            _buildMiniStat(
                                Icons.timer_outlined, "$duration MIN"),
                            const SizedBox(width: 20),
                            _buildMiniStat(
                                Icons.fitness_center_outlined,
                                "${(workout['total_volume'] ?? 0).toInt()} KG"),
                            const SizedBox(width: 20),
                            _buildMiniStat(
                                Icons.reorder_rounded,
                                "${workout['total_sets'] ?? 0} SETS"),
                          ],
                        ),

                        const SizedBox(height: 18),

                        /// Exercise Summary (Top 3)
                        ...summaryList.take(3).map(
                          (e) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.add_task_rounded,
                                  color: Colors.blue,
                                  size: 14,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "${e.value}x ${e.key}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        /// If More Than 3 Exercises
                        if (summaryList.length > 3)
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 4),
                            child: Text(
                              "AND ${summaryList.length - 3} MORE EXERCISES...",
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        /// Bottom Divider
        const Divider(
          color: Color.fromARGB(0, 255, 255, 255),
          thickness: 8,
          height: 0,
        ),
      ],
    );
  },
);

  }

  Widget _buildMiniStat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, VoidCallback onInfo) {
  return Expanded(
    child: _glassContainer(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      radius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onInfo,
                child: Icon(Icons.help_outline,
                    color: Colors.grey.withOpacity(0.7), size: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}


  List<BarChartGroupData> _generateGraphData(List<dynamic> data, int days) {
    int numWeeks = (days / 7).ceil();
    Map<int, double> weeklyData = {for (int i = 0; i < numWeeks; i++) i: 0};
    for (var workout in data) {
      final date = DateTime.parse(workout['start_time']);
      final weekIndex = (DateTime.now().difference(date).inDays / 7).floor();
      
      if (weekIndex >= 0 && weekIndex < numWeeks) {
        double val = _selectedMetric == 'Volume' 
            ? (workout['total_volume'] ?? 0).toDouble() 
            : (workout['total_sets'] ?? 0).toDouble();
        weeklyData[weekIndex] = weeklyData[weekIndex]! + val;
      }
    }

    return weeklyData.entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value == 0 ? 10 : entry.value,
            color: entry.key == 0 ? Colors.blue : Colors.blue.withOpacity(0.3),
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList().reversed.toList();
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return "UNDERWEIGHT";
    if (bmi < 25) return "HEALTHY";
    if (bmi < 30) return "OVERWEIGHT";
    return "OBESE";
  }
}
