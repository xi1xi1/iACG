class Post {
  final String id;
  final String title;
  final String? content;
  final String channel;
  final String authorId;
  final Map<String, dynamic>? author;
  final List<dynamic>? postMedia;
  final List<dynamic>? tags;
  final int likeCount;
  final int favoriteCount;
  final int commentCount;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.title,
    this.content,
    required this.channel,
    required this.authorId,
    this.author,
    this.postMedia,
    this.tags,
    required this.likeCount,
    required this.favoriteCount,
    required this.commentCount,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      content: json['content'],
      channel: json['channel'],
      authorId: json['author_id'],
      author: json['author'],
      postMedia: json['post_media'],
      tags: json['tags'],
      likeCount: json['like_count'] ?? 0,
      favoriteCount: json['favorite_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
