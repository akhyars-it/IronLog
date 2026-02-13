import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _supabase = Supabase.instance.client;
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Controllers - Step 1
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  // Controllers - Step 2
  final _fullNameController = TextEditingController();
  String _gender = 'Male';
  DateTime? _birthDate;

  // Controllers - Step 3
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _bodyFatController = TextEditingController();

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _handleRegister();
    }
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleRegister() async {
    setState(() => _isLoading = true);
    try {
      // 1. Create Auth User
      final res = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = res.user;
      if (user != null) {
        // 2. Update the profile table (Supabase usually creates the row via trigger, so we 'update')
        await _supabase.from('profiles').insert({
  'id': user.id,
  'email': user.email,
  'username': _usernameController.text.trim(),
  'full_name': _fullNameController.text.trim(),
  'gender': _gender,
  'birth_date': _birthDate,
  'height': double.tryParse(_heightController.text),
  'current_weight': double.tryParse(_weightController.text),
  'target_weight': double.tryParse(_targetWeightController.text),
  'current_body_fat': double.tryParse(_bodyFatController.text),
});



        if (mounted) Navigator.pop(context); // Go back to AuthGate/Dashboard
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Create IronLog Account")),
      body: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: (_currentPage + 1) / 3,
            backgroundColor: Colors.white10,
            color: Colors.blue,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (v) => setState(() => _currentPage = v),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
              ],
            ),
          ),
          _buildNavigation(),
        ],
      ),
    );
  }

  // --- UI STEPS ---

  Widget _buildStep1() {
    return _buildPageWrapper(
      title: "Account Details",
      children: [
        _textField(_emailController, "Email", Icons.email),
        _textField(_passwordController, "Password", Icons.lock, obscure: true),
        _textField(_usernameController, "Username", Icons.person_outline),
      ],
    );
  }

  Widget _buildStep2() {
    return _buildPageWrapper(
      title: "Tell us about yourself",
      children: [
        _textField(_fullNameController, "Full Name", Icons.badge),
        const SizedBox(height: 20),
        const Text("Gender", style: TextStyle(color: Colors.grey)),
        Row(
          children: [
            _genderChip("Male"),
            const SizedBox(width: 10),
            _genderChip("Female"),
          ],
        ),
        const SizedBox(height: 20),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_birthDate == null ? "Select Birth Date" : DateFormat('yyyy-MM-dd').format(_birthDate!)),
          trailing: const Icon(Icons.calendar_today, color: Colors.blue),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _birthDate = picked);
          },
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return _buildPageWrapper(
      title: "Body Composition",
      children: [
        Row(
          children: [
            Expanded(child: _textField(_heightController, "Height (cm)", Icons.height, type: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _textField(_weightController, "Weight (kg)", Icons.monitor_weight, type: TextInputType.number)),
          ],
        ),
        _textField(_bodyFatController, "Body Fat % (Optional)", Icons.percent, type: TextInputType.number),
        _textField(_targetWeightController, "Target Weight (kg)", Icons.flag, type: TextInputType.number),
      ],
    );
  }

  // --- HELPERS ---

  Widget _buildPageWrapper({required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint, IconData icon, {bool obscure = false, TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: type,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.blue, size: 20),
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFF1C1C1E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _genderChip(String label) {
    bool isSelected = _gender == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (v) => setState(() => _gender = label),
      selectedColor: Colors.blue,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey),
    );
  }

  Widget _buildNavigation() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            TextButton(onPressed: _prevPage, child: const Text("Back"))
          else
            const SizedBox(),
          ElevatedButton(
            onPressed: _isLoading ? null : _nextPage,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40)),
            child: _isLoading 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
              : Text(_currentPage == 2 ? "Finish" : "Next"),
          ),
        ],
      ),
    );
  }
}