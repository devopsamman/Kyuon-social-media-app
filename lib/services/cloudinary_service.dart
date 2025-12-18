import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  // Cloudinary credentials
  static const String cloudName = 'dmcinze7b';
  static const String uploadPreset =
      'story_images'; // Universal preset for all uploads

  late final CloudinaryPublic cloudinary;

  CloudinaryService() {
    cloudinary = CloudinaryPublic(cloudName, uploadPreset, cache: false);
  }

  /// Upload image to Cloudinary
  Future<String> uploadImage(File imageFile) async {
    try {
      print('Uploading image to Cloudinary...');
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path, folder: 'kyuon/posts'),
      );
      print('Image uploaded successfully: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      print('Error uploading image: $e');
      if (e.toString().contains('400')) {
        throw Exception(
          'Upload failed: Please check your Cloudinary upload preset configuration. The "story_images" preset must allow image uploads.',
        );
      }
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }

  /// Upload video to Cloudinary
  Future<String> uploadVideo(File videoFile) async {
    try {
      print('Uploading video to Cloudinary...');
      print('Video file path: ${videoFile.path}');
      print('File size: ${await videoFile.length()} bytes');

      // Check file size (Cloudinary free tier has limits)
      final fileSize = await videoFile.length();
      if (fileSize > 100 * 1024 * 1024) {
        // 100MB limit
        throw Exception(
          'Video file is too large (${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB). Please use a video smaller than 100MB.',
        );
      }

      // Use the same preset as images - it should work for videos too
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          videoFile.path,
          resourceType: CloudinaryResourceType.Video,
          folder: 'kyuon/reels',
        ),
      );

      print('Video uploaded successfully: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      print('Error uploading video: $e');

      // Provide specific error messages
      if (e.toString().contains('400')) {
        throw Exception(
          'Upload failed: The upload preset "story_images" needs to be configured to allow video uploads in your Cloudinary dashboard. '
          'Go to Settings → Upload → Upload presets → story_images → Enable "unsigned" and set resource types to "Image and Video".',
        );
      } else if (e.toString().contains('413')) {
        throw Exception('Video file is too large. Please use a smaller video.');
      } else if (e.toString().contains('timeout')) {
        throw Exception(
          'Upload timed out. Please check your internet connection and try again.',
        );
      }

      throw Exception('Failed to upload video: ${e.toString()}');
    }
  }

  /// Upload story image
  Future<String> uploadStory(File imageFile) async {
    try {
      print('Uploading story to Cloudinary...');
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path, folder: 'kyuon/stories'),
      );
      print('Story uploaded successfully: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      print('Error uploading story: $e');
      if (e.toString().contains('400')) {
        throw Exception(
          'Upload failed: Please check your Cloudinary upload preset configuration.',
        );
      }
      throw Exception('Failed to upload story: ${e.toString()}');
    }
  }
}
