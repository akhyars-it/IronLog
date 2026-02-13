import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_profile_screen.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profileData;
  int _workoutCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileAndStats();
  }

  Future<void> _loadProfileAndStats() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch Profile Data
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      // Fetch Workout Count (Fixed Supabase Syntax)
      final workoutsResponse = await _supabase
          .from('workouts')
          .select('id')
          .eq('user_id', userId);
      
      final count = (workoutsResponse as List).length;

      if (mounted) {
        setState(() {
          _profileData = profile;
          _workoutCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: Colors.blue),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              );
              _loadProfileAndStats();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _showLogoutDialog(),
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfileAndStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildAvatar(),
                    const SizedBox(height: 15),
                    
                    Text(
                      _profileData?['full_name'] ?? "Apex User",
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "@${_profileData?['username'] ?? 'username'}",
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 15),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _profileData?['bio'] ?? "No bio set yet. Tap edit to add one!",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildProfileStat("$_workoutCount", "Workouts"),
                        _buildProfileStat("7", "Day Streak"),
                        _buildProfileStat("Elite", "Status"),
                      ],
                    ),
                    
                    const SizedBox(height: 40),
                    const Divider(color: Colors.white10, indent: 40, endIndent: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: const CircleAvatar(
        radius: 55,
        backgroundColor: Colors.black,
        child: Icon(Icons.person, size: 60, color: Colors.blue),
      ),
    );
  }

  Widget _buildProfileStat(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.1)),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Logout", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to sign out?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: _signOut, child: const Text("Logout", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }
}