import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/cloudinary_service.dart';
import '../services/supabase_service.dart';
import '../services/content_provider.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _uploadStory() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      print('_uploadStory: Starting story upload process...');
      
      // Ensure anonymous authentication before upload
      print('_uploadStory: Ensuring authentication...');
      final supabaseService = SupabaseService();
      await supabaseService.signInAnonymously();
      print('_uploadStory: Authentication successful');
      
      // Upload to Cloudinary
      print('_uploadStory: Uploading image to Cloudinary...');
      final imageUrl = await _cloudinaryService.uploadStory(_selectedImage!);
      print('_uploadStory: Story uploaded to Cloudinary: $imageUrl');

      // Create story in Supabase
      print('_uploadStory: Creating story in Supabase...');
      await supabaseService.createStory(imageUrl);
      print('_uploadStory: Story created in Supabase');

      // Refresh stories
      print('_uploadStory: Refreshing content provider...');
      await Provider.of<ContentProvider>(context, listen: false).refreshData();
      print('_uploadStory: Content refreshed');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      print('_uploadStory: ERROR - $e');
      print('_uploadStory: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload story: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Story',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_selectedImage != null)
            TextButton(
              onPressed: _isUploading ? null : _uploadStory,
              child: _isUploading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      )
                      : const Text(
                        'Share',
                        style: TextStyle(
                        color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
        ],
      ),
      body: _selectedImage == null
          ? Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  const Icon(
                    Icons.add_photo_alternate,
                    size: 80,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create Your Story',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share a moment with your friends',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildActionButton(
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        onTap: _pickImage,
                      ),
                      const SizedBox(width: 24),
                      _buildActionButton(
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        onTap: _takePhoto,
                      ),
                    ],
                  ),
                ],
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                      padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImage,
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            label: const Text(
                              'Change',
                              style: TextStyle(color: Colors.white),
                            ),
                        style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isUploading ? null : _uploadStory,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.send, color: Colors.white),
                            label: Text(
                              _isUploading ? 'Uploading...' : 'Share Story',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                    ),
                  ),
          ],
                ),
      ),
    );
  }
}

