import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'stats_screen.dart';
import 'exercise_library_screen.dart';
import 'calendar_screen.dart';
import 'edit_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _history = [];
          _isLoading = false;
        });
        return;
      }

      final List<dynamic> response = await _supabase
          .from('workouts')
          .select()
          .eq('user_id', user.id)
          .order('start_time', ascending: false)
          .limit(10);

      if (!mounted) return;

      setState(() {
        _history = response;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Dashboard fetch error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("APEX LOG"),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            )
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProfileSection(),
                    const SizedBox(height: 25),
                    _buildMenuGrid(),
                    const SizedBox(height: 35),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "WORKOUT HISTORY",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildHistoryList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileSection() {
    final email = _supabase.auth.currentUser?.email ?? "User";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue,
            child: Icon(Icons.person, size: 35, color: Colors.white),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Welcome back,",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  email.split('@').first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.grey),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _menuButton(
          "WORKOUT",
          Icons.play_arrow_rounded,
          Colors.blue,
          // Replace with your actual workout screen if different
          const DashboardScreen(),
        ),
        _menuButton(
          "STATISTICS",
          Icons.bar_chart_rounded,
          Colors.orange,
          const StatsScreen(),
        ),
        _menuButton(
          "EXERCISES",
          Icons.fitness_center_rounded,
          Colors.purple,
          const ExerciseLibraryScreen(),
        ),
        _menuButton(
          "CALENDAR",
          Icons.calendar_month_rounded,
          Colors.green,
          const CalendarScreen(),
        ),
      ],
    );
  }

  Widget _menuButton(
    String title,
    IconData icon,
    Color color,
    Widget destination,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => destination),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text(
          "No workouts logged yet",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final workout = _history[index] as Map<String, dynamic>;

        return Card(
          color: Colors.grey[900],
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(
              workout['routine_name'] ?? "Workout",
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              workout['start_time']
                      ?.toString()
                      .split('T')
                      .first ??
                  '',
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: Text(
              "${workout['total_volume'] ?? 0}kg",
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
