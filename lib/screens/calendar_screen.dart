import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _supabase = Supabase.instance.client;
  // Removed multi-format view as month is standard for fitness
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  Set<DateTime> _workoutDays = {};
  int _weekStreak = 0;
  int _daysSinceLastWorkout = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchCalendarData();
  }

  Future<void> _fetchCalendarData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('workouts')
          .select('start_time')
          .eq('user_id', userId);

      final List data = response as List;
      Set<DateTime> dates = {};
      
      for (var row in data) {
        final date = DateTime.parse(row['start_time']);
        dates.add(DateTime(date.year, date.month, date.day));
      }

      setState(() {
        _workoutDays = dates;
        _calculateStats();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Calendar Error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    if (_workoutDays.isEmpty) {
      _daysSinceLastWorkout = 0;
      _weekStreak = 0;
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Calculate Rest Days (Days since last workout excluding today)
    final sortedDates = _workoutDays.toList()..sort();
    final lastWorkoutDate = sortedDates.last;
    
    // Calculate difference in days between last workout and today
    int diff = today.difference(lastWorkoutDate).inDays;
    // We only count full days that have passed (rest days between workouts)
    _daysSinceLastWorkout = diff > 0 ? diff : 0;

    // 2. Calculate Week Streak
    // A week streak counts how many consecutive weeks have at least one workout
    int consecutiveWeeks = 0;
    
    // Get the start of the current week (Monday)
    DateTime currentWeekMonday = today.subtract(Duration(days: today.weekday - 1));
    
    bool hasWorkoutInWeek = true;
    while (hasWorkoutInWeek) {
      DateTime weekSunday = currentWeekMonday.add(const Duration(days: 6));
      
      // Check if any workout exists between this Monday and Sunday
      bool workoutExists = _workoutDays.any((d) => 
        (d.isAtSameMomentAs(currentWeekMonday) || d.isAfter(currentWeekMonday)) && 
        (d.isAtSameMomentAs(weekSunday) || d.isBefore(weekSunday))
      );

      if (workoutExists) {
        consecutiveWeeks++;
        // Move back 7 days to check the previous week
        currentWeekMonday = currentWeekMonday.subtract(const Duration(days: 7));
      } else {
        hasWorkoutInWeek = false;
      }
    }
    _weekStreak = consecutiveWeeks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("CALENDAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStreakCards(),
                const SizedBox(height: 25),
                _buildCalendarCard(),
                const SizedBox(height: 20),
                _buildLegend(),
              ],
            ),
          ),
    );
  }

  Widget _buildStreakCards() {
    return Row(
      children: [
        Expanded(
          child: _statTile("WEEK STREAK", "$_weekStreak Weeks", Icons.local_fire_department, Colors.orange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statTile("REST DAYS", "$_daysSinceLastWorkout", Icons.king_bed, Colors.blueAccent),
        ),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


  Widget _buildCalendarCard() {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.now(),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,

          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
            leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
            rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
          ),

          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),

          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },

          eventLoader: (day) {
            final normalizedDay =
                DateTime(day.year, day.month, day.day);
            return _workoutDays.contains(normalizedDay)
                ? ['workout']
                : [];
          },

          calendarStyle: CalendarStyle(
            markerDecoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            defaultTextStyle:
                const TextStyle(color: Colors.white),
            weekendTextStyle:
                const TextStyle(color: Colors.white70),
            outsideDaysVisible: false,
          ),
        ),
      ),
    ),
  );
}


  Widget _buildLegend() {
  return ClipRRect(
    borderRadius: BorderRadius.circular(15),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "Workout Day",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

}