import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  // Cloudinary credentials
  static const String cloudName = 'dmcinze7b';
  static const String uploadPreset = 'story_images'; // For posts and stories
  static const String reelsPreset = 'reels_video'; // For reels videos

  late final CloudinaryPublic cloudinary;

  CloudinaryService() {
    cloudinary = CloudinaryPublic(cloudName, uploadPreset, cache: false);
  }

  /// Upload image to Cloudinary
  Future<String> uploadImage(File imageFile) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path, folder: 'kyuon/posts'),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Upload video to Cloudinary
  Future<String> uploadVideo(File videoFile) async {
    try {
      final cloudinaryReels = CloudinaryPublic(
        cloudName,
        reelsPreset,
        cache: false,
      );
      CloudinaryResponse response = await cloudinaryReels.uploadFile(
        CloudinaryFile.fromFile(
          videoFile.path,
          folder: 'kyuon/reels',
          resourceType: CloudinaryResourceType.Video,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  /// Upload story image
  Future<String> uploadStory(File imageFile) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path, folder: 'kyuon/stories'),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Failed to upload story: $e');
    }
  }
}
