// screens/facebook_live_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/facebook_live.dart';
import '../services/facebook_service.dart';

class FacebookLiveScreen extends StatefulWidget {
  const FacebookLiveScreen({super.key});

  @override
  State<FacebookLiveScreen> createState() => _FacebookLiveScreenState();
}

class _FacebookLiveScreenState extends State<FacebookLiveScreen> {
  final FacebookService _facebookService = FacebookService();
  late Future<List<FacebookLive>> _futureLiveVideos;
  bool _isRefreshing = false;
  bool _hasLiveNotification = false;

  @override
  void initState() {
    super.initState();
    _futureLiveVideos = _facebookService.getLiveVideos();
    _checkForLiveBroadcast();
  }

  Future<void> _checkForLiveBroadcast() async {
    try {
      final isLive = await _facebookService.isLiveNow();
      if (isLive && !_hasLiveNotification) {
        _showLiveNotification();
      }
      setState(() {
        _hasLiveNotification = isLive;
      });
    } catch (e) {
      print('Error checking live status: $e');
    }
  }

  void _showLiveNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Nation Online is LIVE now!'),
            ),
          ],
        ),
        backgroundColor: Colors.green[800],
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Watch',
          textColor: Colors.white,
          onPressed: () {
            _futureLiveVideos.then((videos) {
              final liveVideo = videos.firstWhere((video) => video.isLive);
              _watchLive(liveVideo);
            });
          },
        ),
      ),
    );
  }

  Future<void> _refreshVideos() async {
    setState(() => _isRefreshing = true);
    try {
      await _facebookService.getLiveVideos();
      setState(() {
        _futureLiveVideos = _facebookService.getLiveVideos();
      });
      await _checkForLiveBroadcast();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh: $e')),
      );
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  void _watchLive(FacebookLive liveVideo) async {
    final url = Uri.parse(liveVideo.videoUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Facebook video')),
      );
    }
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }

  String _formatViewCount(int views) {
    if (views < 1000) return '$views views';
    if (views < 1000000) return '${(views / 1000).toStringAsFixed(1)}K views';
    return '${(views / 1000000).toStringAsFixed(1)}M views';
  }

  Widget _buildLiveIndicator(bool isLive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLive ? Colors.red : Colors.grey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            isLive ? 'LIVE' : 'ENDED',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(FacebookLive liveVideo) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _watchLive(liveVideo),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    child: Image.network(
                      liveVideo.thumbnailUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_off, size: 50, color: Colors.grey[500]),
                              const SizedBox(height: 8),
                              Text(
                                'Thumbnail not available',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _buildLiveIndicator(liveVideo.isLive),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      liveVideo.isLive 
                        ? '${_formatViewCount(liveVideo.viewCount)} watching'
                        : _formatTimeAgo(liveVideo.broadcastTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    liveVideo.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (liveVideo.description.isNotEmpty)
                    Text(
                      liveVideo.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatViewCount(liveVideo.viewCount),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.facebook, size: 20, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Watch on Facebook',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facebook Live'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshVideos,
          ),
        ],
      ),
      body: FutureBuilder<List<FacebookLive>>(
        future: _futureLiveVideos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load live videos',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshVideos,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No live videos available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for live streams',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final liveVideos = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refreshVideos,
            child: ListView.builder(
              itemCount: liveVideos.length,
              itemBuilder: (context, index) {
                return _buildVideoCard(liveVideos[index]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _launchUrl('https://www.facebook.com/NationOnlineMw');
        },
        icon: const Icon(Icons.live_tv),
        label: const Text('Go to Page'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}