import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarWidget extends StatefulWidget {
  final String? url;
  final Function(String) onUpload;

  const AvatarWidget({super.key, this.url, required this.onUpload});

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget> {
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    // Pick image and compress to 80% to save storage space
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80, 
    );

    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final file = File(image.path);
      final userId = _supabase.auth.currentUser!.id;
      final fileExt = image.path.split('.').last;
      final fileName = '$userId.$fileExt'; 

      // 1. Upload to Storage (upsert: true overwrites the old file)
      await _supabase.storage.from('avatars').upload(
            fileName,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      // 2. Get Public URL
      final String publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(fileName);

      // 3. Update the profile table immediately
      await _supabase.from('profiles').update({
        'avatar_url': publicUrl,
      }).eq('id', userId);

      // 4. Update the UI
      widget.onUpload(publicUrl);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.blue,
          backgroundImage: widget.url != null ? NetworkImage(widget.url!) : null,
          child: _isLoading 
              ? const CircularProgressIndicator(color: Colors.white) 
              : (widget.url == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null),
        ),
        TextButton(
          onPressed: _isLoading ? null : _pickAndUploadImage,
          child: const Text('Change Profile Picture', style: TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }
}