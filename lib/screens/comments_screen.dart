import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  final int initialCommentCount;

  const CommentsScreen({
    super.key,
    required this.postId,
    required this.initialCommentCount,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
    // Add listener to rebuild UI when text changes
    _commentController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      print('Loading comments for post: ${widget.postId}');
      final response = await Supabase.instance.client
          .from('comments')
          .select('*, profiles(username, profile_image_url)')
          .eq('post_id', widget.postId)
          .order('created_at', ascending: false);

      print('Loaded ${(response as List).length} comments');
      setState(() {
        _comments = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading comments: $e');
      print('Error details: ${e.toString()}');
      setState(() => _isLoading = false);

      // Show error if table doesn't exist
      if (mounted && e.toString().contains('comments')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Comments table not set up. Please run the SQL setup in Supabase.',
            ),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final commentText = _commentController.text.trim();
      print('Submitting comment: $commentText');
      print('Post ID: ${widget.postId}');
      print('User ID: ${user.id}');

      // Try to insert comment
      final insertResult =
          await Supabase.instance.client.from('comments').insert({
            'post_id': widget.postId,
            'user_id': user.id,
            'content': commentText,
          }).select();

      print('Comment inserted successfully: $insertResult');

      // Try to update post comment count
      try {
        final currentPost =
            await Supabase.instance.client
                .from('posts')
                .select('comments')
                .eq('id', widget.postId)
                .single();

        final currentCount = currentPost['comments'] as int? ?? 0;

        await Supabase.instance.client
            .from('posts')
            .update({'comments': currentCount + 1})
            .eq('id', widget.postId);
      } catch (e) {
        print('Error updating comment count: $e');
        // Continue even if count update fails
      }

      _commentController.clear();
      print('Reloading comments...');
      await _loadComments();
      print('Comments reloaded. Total: ${_comments.length}');

      // Scroll to top to show new comment
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment posted successfully!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error submitting comment: $e');
      print('Error type: ${e.runtimeType}');
      if (mounted) {
        String errorMessage = 'Failed to post comment';

        if (e.toString().contains('comments') ||
            e.toString().contains('relation')) {
          errorMessage =
              'Comments table not set up. Please run the SQL setup in Supabase Dashboard.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 6),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Comments',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
      ),
      body: Column(
        children: [
          // Comments list
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: CircularProgressIndicator(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    )
                    : _comments.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.comment_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No comments yet',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to comment!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _comments.length,
                      separatorBuilder:
                          (_, __) => Divider(
                            height: 1,
                            color:
                                isDarkMode
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade300,
                          ),
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        final profile =
                            comment['profiles'] is Map
                                ? comment['profiles']
                                : <String, dynamic>{};
                        final username =
                            profile['username']?.toString() ?? 'Unknown';
                        final profileImage =
                            profile['profile_image_url']?.toString();
                        final content = comment['content']?.toString() ?? '';
                        final createdAt = comment['created_at']?.toString();

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    isDarkMode
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade200,
                                backgroundImage:
                                    profileImage != null &&
                                            profileImage.isNotEmpty
                                        ? NetworkImage(profileImage)
                                        : null,
                                child:
                                    profileImage == null || profileImage.isEmpty
                                        ? Icon(
                                          Icons.person,
                                          size: 22,
                                          color: Colors.grey,
                                        )
                                        : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        isDarkMode
                                            ? Colors.grey.shade900
                                            : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              username,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color:
                                                    isDarkMode
                                                        ? Colors.white
                                                        : Colors.black,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _getTimeAgo(createdAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        content,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.4,
                                          color:
                                              isDarkMode
                                                  ? Colors.grey.shade200
                                                  : Colors.grey.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),

          // Comment input
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
              border: Border(
                top: BorderSide(
                  color:
                      isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  width: 0.5,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                    child: const Icon(
                      Icons.person,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode
                                ? Colors.grey.shade900
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color:
                              isDarkMode
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _commentController,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submitComment(),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write a comment...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child:
                        _isSubmitting
                            ? Container(
                              width: 40,
                              height: 40,
                              padding: const EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.blue,
                              ),
                            )
                            : Material(
                              color:
                                  _commentController.text.trim().isEmpty
                                      ? Colors.grey.shade300
                                      : Colors.blue,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap:
                                    _commentController.text.trim().isEmpty
                                        ? null
                                        : _submitComment,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.send_rounded,
                                    color:
                                        _commentController.text.trim().isEmpty
                                            ? Colors.grey.shade600
                                            : Colors.white,
                                    size: 20,
                                  ),
                                ),
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

  String _getTimeAgo(String? timestamp) {
    if (timestamp == null) return 'now';
    try {
      final dateTime = DateTime.parse(timestamp);
      final difference = DateTime.now().difference(dateTime);
      if (difference.inDays > 0) return '${difference.inDays}d';
      if (difference.inHours > 0) return '${difference.inHours}h';
      if (difference.inMinutes > 0) return '${difference.inMinutes}m';
      return 'now';
    } catch (e) {
      return 'now';
    }
  }
}
