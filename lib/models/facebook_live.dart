// models/facebook_live.dart
class FacebookLive {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final DateTime broadcastTime;
  final int viewCount;
  final bool isLive;

  FacebookLive({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.broadcastTime,
    required this.viewCount,
    required this.isLive,
  });
}