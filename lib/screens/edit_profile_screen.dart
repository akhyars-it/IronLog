import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui'; // For blur
import 'avatar_widget.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _supabase = Supabase.instance.client;

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _bodyFatController = TextEditingController();

  DateTime? _selectedDate;
  String _selectedGender = 'Male';
  String? _avatarUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _bodyFatController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase.from('profiles').select().eq('id', userId).maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _nameController.text = data['full_name'] ?? '';
          _usernameController.text = data['username'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _avatarUrl = data['avatar_url'];
          _selectedGender = data['gender'] ?? 'Male';
          _heightController.text = (data['height'] ?? '').toString();
          _weightController.text = (data['current_weight'] ?? '').toString();
          _targetWeightController.text = (data['target_weight'] ?? '').toString();
          _bodyFatController.text = (data['current_body_fat'] ?? '').toString();
          if (data['birth_date'] != null) _selectedDate = DateTime.parse(data['birth_date']);
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  Future<void> _updateProfile() async {
    if (_usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Username is required")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = _supabase.auth.currentUser!.id;

      await _supabase.from('profiles').upsert({
        'id': userId,
        'full_name': _nameController.text.trim(),
        'username': _usernameController.text.trim().toLowerCase(),
        'bio': _bioController.text.trim(),
        'gender': _selectedGender,
        'birth_date': _selectedDate?.toIso8601String(),
        'avatar_url': _avatarUrl,
        'height': double.tryParse(_heightController.text),
        'current_weight': double.tryParse(_weightController.text),
        'target_weight': double.tryParse(_targetWeightController.text),
        'current_body_fat': double.tryParse(_bodyFatController.text),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated!")),
        );
        Navigator.pop(context);
      }
    } on PostgrestException catch (e) {
      String message = e.message;
      if (e.code == '23505') message = "Username already taken!";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      debugPrint("Error updating profile: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// ---------------- GLASS CONTAINER ----------------
  Widget _glassContainer({
    required Widget child,
    EdgeInsets? padding,
    BorderRadius? radius,
    double blurX = 10,
    double blurY = 10,
    double opacity = 0.05,
    double borderOpacity = 0.08,
  }) {
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: radius ?? BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(borderOpacity)),
          ),
          child: child,
        ),
      ),
    );
  }

  /// ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                ),
              ),
            )
          else
            IconButton(onPressed: _updateProfile, icon: const Icon(Icons.check, color: Colors.blue, size: 28))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: AvatarWidget(
                url: _avatarUrl,
                onUpload: (url) => setState(() => _avatarUrl = url),
              ),
            ),
            const SizedBox(height: 30),

            /// ---------------- BASIC INFORMATION ----------------
            _glassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "BASIC INFORMATION",
                    style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  _buildFieldWithDivider("Full Name", _nameController),
                  _buildFieldWithDivider("Username", _usernameController),
                  _buildFieldWithDivider("Bio", _bioController, maxLines: 3),
                ],
              ),
            ),

            /// ---------------- PHYSICAL METRICS ----------------
            _glassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "PHYSICAL METRICS",
                    style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  _buildRowFieldWithDivider(
                    _buildFieldWithDivider("Height (cm)", _heightController, isNumber: true),
                    _buildFieldWithDivider("Weight (kg)", _weightController, isNumber: true),
                  ),
                  _buildRowFieldWithDivider(
                    _buildFieldWithDivider("Goal Weight (kg)", _targetWeightController, isNumber: true),
                    _buildFieldWithDivider("Body Fat %", _bodyFatController, isNumber: true),
                  ),
                ],
              ),
            ),

            /// ---------------- PERSONAL DETAILS ----------------
            _glassContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "PERSONAL DETAILS",
                    style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 10),
                  _glassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    blurX: 8,
                    blurY: 8,
                    opacity: 0.03,
                    borderOpacity: 0.05,
                    child: _buildSelectionGroup(
                      "Gender",
                      _selectedGender,
                      ['Male', 'Female', 'Other'],
                      (val) => setState(() => _selectedGender = val!),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _glassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    blurX: 8,
                    blurY: 8,
                    opacity: 0.03,
                    borderOpacity: 0.05,
                    child: _buildDatePicker(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  /// ---------------- FIELDS ----------------
  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? DateTime(2000),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.blue,
                  onPrimary: Colors.white,
                  surface: Color(0xFF1C1C1E),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDate == null ? "Select Date" : DateFormat('MMMM dd, yyyy').format(_selectedDate!),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const Icon(Icons.calendar_today, color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldWithDivider(String label, TextEditingController controller,
      {int maxLines = 1, bool isNumber = false}) {
    return Column(
      children: [
        _buildEditField(label, controller, maxLines: maxLines, isNumber: isNumber),
        const Divider(color: Color.fromARGB(0, 255, 255, 255), height: 1),
      ],
    );
  }

  Widget _buildEditField(String label, TextEditingController controller,
      {int maxLines = 1, bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
        ),
      ),
    );
  }

  Widget _buildSelectionGroup(String label, String value, List<String> options, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1C1C1E),
          underline: Container(height: 1, color: Colors.white10),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildRowFieldWithDivider(Widget left, Widget right) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 15),
        Expanded(child: right),
      ],
    );
  }
}
