# How to Implement Photo & Video Messaging

## Step 1: Add Dependencies

First, add these packages to your `pubspec.yaml`:

```yaml
dependencies:
  image_picker: ^1.0.7  # For selecting images/videos
  video_player: ^2.8.2   # For playing videos in chat
  photo_view: ^0.14.0    # For fullscreen image viewing
```

Then run:
```bash
flutter pub get
```

## Step 2: Update Messaging Service

Add this method to `lib/services/messaging_service.dart`:

```dart
Future<void> sendMediaMessage({
  required String conversationId,
  required String receiverId,
  required String mediaUrl,
  required String messageType, // 'image' or 'video'
  String caption = '',
}) async {
  final currentUser = _client.auth.currentUser;
  if (currentUser == null) throw Exception('Not authenticated');

  await _client.from('messages').insert({
    'conversation_id': conversationId,
    'sender_id': currentUser.id,
    'receiver_id': receiverId,
    'message_text': caption,
    'message_type': messageType,
    'media_url': mediaUrl,
    'is_read': false,
  });

  // Update conversation's last message
  await _client.from('conversations').update({
    'last_message': caption.isEmpty ? '📷 Photo' : caption,
    'last_message_at': DateTime.now().toUtc().toIso8601String(),
    'last_message_sender_id': currentUser.id,
  }).eq('id', conversationId);
}
```

## Step 3: Add Media Selection UI

Update `chat_screen.dart` to add attachment button. Add this in the input field Row (around line 432):

```dart
Row(
  children: [
    // Add THIS before the Expanded TextField:
    IconButton(
      icon: Icon(Icons.attach_file),
      onPressed: _showMediaOptions,
    ),
    Expanded(
      child: Container(
        // ... existing TextField code
      ),
    ),
    // ... existing send button
  ],
)
```

## Step 4: Implement Media Picker Methods

Add these methods to `_ChatScreenState`:

```dart
Future<void> _showMediaOptions() async {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('Photo from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: Icon(Icons.camera_alt),
            title: Text('Take Photo'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: Icon(Icons.video_library),
            title: Text('Video from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickVideo(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: Icon(Icons.videocam),
            title: Text('Record Video'),
            onTap: () {
              Navigator.pop(context);
              _pickVideo(ImageSource.camera),
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _pickImage(ImageSource source) async {
  final picker = ImagePicker();
  final XFile? image = await picker.pickImage(source: source);
  
  if (image != null) {
    _sendMediaMessage(image.path, 'image');
  }
}

Future<void> _pickVideo(ImageSource source) async {
  final picker = ImagePicker();
  final XFile? video = await picker.pickVideo(source: source);
  
  if (video != null) {
    _sendMediaMessage(video.path, 'video');
  }
}

Future<void> _sendMediaMessage(String filePath, String type) async {
  setState(() => _isSending = true);
  
  try {
    // Upload to Cloudinary
    final cloudinaryService = CloudinaryService();
    String mediaUrl;
    
    if (type == 'image') {
      mediaUrl = await cloudinaryService.uploadImage(File(filePath));
    } else {
      mediaUrl = await cloudinaryService.uploadVideo(File(filePath));
    }
    
    // Send message with media URL
    await _messagingService.sendMediaMessage(
      conversationId: widget.conversationId,
      receiverId: widget.otherUserId,
      mediaUrl: mediaUrl,
      messageType: type,
      caption: '', // Can add caption input later
    );
    
    // Reload messages
    final latestMessages = await _messagingService.getMessages(
      widget.conversationId,
    );
    
    if (mounted) {
      setState(() {
        _messages = latestMessages;
      });
      _scrollToBottom();
    }
  } catch (e) {
    print('Error sending media: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isSending = false);
    }
  }
}
```

## Step 5: Update Message Bubble to Display Media

Replace the `_buildMessageBubble` content section (around line 547) with:

```dart
child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Show media if present
    if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty)
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: message.messageType == 'image'
            ? GestureDetector(
                onTap: () => _viewFullImage(message.mediaUrl!),
                child: Image.network(
                  message.mediaUrl!,
                  width: 200,
                  fit: BoxFit.cover,
                ),
              )
            : _buildVideoPlayer(message.mediaUrl!),
      ),
    
    // Show text if present
    if (message.messageText.isNotEmpty)
      Padding(
        padding: EdgeInsets.only(
          top: message.mediaUrl != null ? 8 : 0,
        ),
        child: Text(
          message.messageText,
          style: TextStyle(
            fontSize: 15,
            color: isSentByMe
                ? Colors.white
                : (isDarkMode ? Colors.white : Colors.black87),
          ),
        ),
      ),
    
    // Show read status
    if (isSentByMe && message.isRead)
      // ... existing read status widget
  ],
),
```

## Step 6: Add Helper Methods

Add these helper methods:

```dart
void _viewFullImage(String imageUrl) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: PhotoView(
            imageProvider: NetworkImage(imageUrl),
          ),
        ),
      ),
    ),
  );
}

Widget _buildVideoPlayer(String videoUrl) {
  return Container(
    width: 200,
    height: 200,
    color: Colors.black,
    child: Center(
      child: IconButton(
        icon: Icon(Icons.play_circle_outline, size: 64, color: Colors.white),
        onPressed: () {
          // Navigate to fullscreen video player
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerScreen(videoUrl: videoUrl),
            ),
          );
        },
      ),
    ),
  );
}
```

## Step 7: Create Video Player Screen

Create `lib/screens/video_player_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
        },
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}
```

## Step 8: Add Required Imports

Add these imports to `chat_screen.dart`:

```dart
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:photo_view/photo_view.dart';
import '../services/cloudinary_service.dart';
import 'video_player_screen.dart';
```

## That's It!

You now have full photo and video messaging in your chat! 🎉

### Features:
✅ Send photos from camera or gallery
✅ Send videos from camera or gallery  
✅ View photos fullscreen
✅ Play videos with controls
✅ Upload progress indication
✅ Dark mode support

### Next Enhancements (Optional):
- Add caption input before sending
- Show upload progress bar
- Video thumbnails in chat
- Download media option
- Delete media option
