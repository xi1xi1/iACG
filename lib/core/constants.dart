class AppConstants {
  // 分页设置
  static const int pageSize = 20;
  static const int defaultLimit = 20;

  // Storage Bucket 名称
  static const String avatarsBucket = 'avatars';
  static const String postImagesBucket = 'post-images';

  // 频道类型
  static const String channelCos = 'cos';
  static const String channelIsland = 'island';

  // 帖子状态
  static const String postStatusNormal = 'normal';
  static const String postStatusBanned = 'banned';

  // 可见性设置
  static const String visibilityPublic = 'public';
  static const String visibilityFollowers = 'followers';
  static const String visibilityPrivate = 'private';

  // 图片相关
  static const double postImageAspectRatio = 1.0;
  static const int maxImageCount = 9;

  // 默认头像
  static const String defaultAvatarUrl = 'https://via.placeholder.com/150';
}
