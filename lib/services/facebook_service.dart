// services/facebook_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/facebook_live.dart';

class FacebookService {
  static const String _pageId = 'NationOnlineMw'; // Your Facebook page name
  static const String _pageUrl = 'https://www.facebook.com/NationOnlineMw';
  
  // Your actual Facebook Access Token
  static const String _accessToken = 'EAAUZBrji252gBPkgkBTf2MACaoziTn7yM7lYRNPLmaX6Aa7imywex9jdHw0IXke7WCvKmZBHTJLgqexov3KQCWnuYmv5SEavhZBgfnsBsb5J8gRI3UTTUnrlZCKgWe4HmcAzNhDyox7nUm4UfTG0gVGVIOFZAng8NLUuMCC4pNLUGfHvtqQTrxUz4IVXeJYXuP4dVSxjG14kokO2aDAXX1bLRazDNKaXgHBo7SVtGzBTOnMDQVhbkvb0JYgE957IDsXtnY3dCy9KnmnYYnCqOz4Hp9hcZD';
  
  Future<List<FacebookLive>> getLiveVideos() async {
    try {
      print('🔗 Fetching real videos from Nation Online Facebook page...');
      
      final response = await http.get(
        Uri.parse('https://graph.facebook.com/v19.0/$_pageId/videos?'
            'fields=id,title,description,permalink_url,created_time,views,length,live_status,thumbnails{uri},status&'
            'access_token=$_accessToken&'
            'limit=15'),
      );
      
      print('📡 Facebook API Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final videos = data['data'] ?? [];
        print('✅ Successfully fetched ${videos.length} real videos from Facebook');
        
        if (videos.isEmpty) {
          print('ℹ️ No videos found, using enhanced mock data');
          return _getEnhancedMockVideos();
        }
        
        return _parseFacebookResponse(data);
      } else {
        print('❌ Facebook API Error ${response.statusCode}: ${response.body}');
        print('🔄 Falling back to enhanced mock data');
        return _getEnhancedMockVideos();
      }
    } catch (e) {
      print('❌ Error fetching Facebook videos: $e');
      print('🔄 Falling back to enhanced mock data');
      return _getEnhancedMockVideos();
    }
  }

  List<FacebookLive> _parseFacebookResponse(Map<String, dynamic> data) {
    try {
      final List<dynamic> videos = data['data'] ?? [];
      final List<FacebookLive> parsedVideos = [];
      
      for (var video in videos) {
        try {
          // Get the best available thumbnail
          String thumbnailUrl = _getBestThumbnail(video['thumbnails']);
          
          // Determine if video is live
          bool isLive = video['live_status'] == 'LIVE' || video['status'] == 'LIVE';
          
          // Get video URL
          String videoUrl = video['permalink_url'] ?? 'https://www.facebook.com/watch/?v=${video['id']}';
          
          // Get view count (handle different possible field names)
          int viewCount = video['views'] ?? video['view_count'] ?? 0;
          
          final facebookLive = FacebookLive(
            id: video['id']?.toString() ?? '',
            title: video['title']?.toString() ?? 'Nation Online Video',
            description: video['description']?.toString() ?? '',
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl.isNotEmpty ? thumbnailUrl : _getDefaultThumbnail(video['title']?.toString() ?? 'Video'),
            broadcastTime: DateTime.parse(video['created_time']),
            viewCount: viewCount,
            isLive: isLive,
          );
          
          parsedVideos.add(facebookLive);
        } catch (e) {
          print('⚠️ Error parsing individual video: $e');
        }
      }
      
      print('📊 Parsed ${parsedVideos.length} videos successfully');
      return parsedVideos;
    } catch (e) {
      print('❌ Error parsing Facebook response: $e');
      return _getEnhancedMockVideos();
    }
  }

  String _getBestThumbnail(dynamic thumbnailsData) {
    try {
      if (thumbnailsData != null && thumbnailsData['data'] != null) {
        final thumbnails = thumbnailsData['data'] as List;
        if (thumbnails.isNotEmpty) {
          // Get the first (usually highest quality) thumbnail
          final thumbnail = thumbnails.first['uri'] ?? '';
          if (thumbnail.isNotEmpty) {
            print('🖼️ Found real thumbnail: $thumbnail');
          }
          return thumbnail;
        }
      }
    } catch (e) {
      print('⚠️ Error parsing thumbnails: $e');
    }
    return '';
  }

  // Enhanced mock data that looks more realistic
  List<FacebookLive> _getEnhancedMockVideos() {
    print('🎭 Using enhanced mock data with realistic Nation Online content');
    return [
      FacebookLive(
        id: 'mock_1',
        title: 'Breaking News: National Developments',
        description: 'Latest updates on national affairs and important developments from around the country.',
        videoUrl: 'https://www.facebook.com/NationOnlineMw/videos',
        thumbnailUrl: 'https://placehold.co/600x400/1e3a8a/ffffff?text=Breaking+News&font=roboto',
        broadcastTime: DateTime.now().subtract(const Duration(hours: 3)),
        viewCount: 2450,
        isLive: false,
      ),
      FacebookLive(
        id: 'mock_2',
        title: 'Sports Roundup: Weekend Highlights',
        description: 'Comprehensive coverage of weekend sports events and match analysis.',
        videoUrl: 'https://www.facebook.com/NationOnlineMw/videos',
        thumbnailUrl: 'https://placehold.co/600x400/dc2626/ffffff?text=Sports+Highlights&font=roboto',
        broadcastTime: DateTime.now().subtract(const Duration(days: 1)),
        viewCount: 1870,
        isLive: false,
      ),
      FacebookLive(
        id: 'mock_3',
        title: 'Business & Economy Weekly Review',
        description: 'Analysis of market trends, economic indicators, and business news affecting our nation.',
        videoUrl: 'https://www.facebook.com/NationOnlineMw/videos',
        thumbnailUrl: 'https://placehold.co/600x400/059669/ffffff?text=Business+Review&font=roboto',
        broadcastTime: DateTime.now().subtract(const Duration(days: 2)),
        viewCount: 1560,
        isLive: false,
      ),
      FacebookLive(
        id: 'mock_4',
        title: 'Entertainment News Update',
        description: 'Latest in entertainment, celebrity news, and cultural events from across the nation.',
        videoUrl: 'https://www.facebook.com/NationOnlineMw/videos',
        thumbnailUrl: 'https://placehold.co/600x400/7c3aed/ffffff?text=Entertainment+News&font=roboto',
        broadcastTime: DateTime.now().subtract(const Duration(days: 3)),
        viewCount: 2890,
        isLive: false,
      ),
      FacebookLive(
        id: 'mock_5',
        title: 'Community Forum: Public Discussion',
        description: 'Interactive session discussing community issues and public concerns with experts.',
        videoUrl: 'https://www.facebook.com/NationOnlineMw/videos',
        thumbnailUrl: 'https://placehold.co/600x400/ea580c/ffffff?text=Community+Forum&font=roboto',
        broadcastTime: DateTime.now().subtract(const Duration(days: 4)),
        viewCount: 1320,
        isLive: false,
      ),
    ];
  }

  String _getDefaultThumbnail(String title) {
    // Generate themed placeholder based on content
    final colors = {
      'news': '1e3a8a',
      'sport': 'dc2626', 
      'business': '059669',
      'entertainment': '7c3aed',
      'community': 'ea580c',
      'default': '4b5563'
    };
    
    String color = colors['default']!;
    final lowerTitle = title.toLowerCase();
    
    if (lowerTitle.contains('news') || lowerTitle.contains('breaking')) {
      color = colors['news']!;
    } else if (lowerTitle.contains('sport')) {
      color = colors['sport']!;
    } else if (lowerTitle.contains('business') || lowerTitle.contains('economy')) {
      color = colors['business']!;
    } else if (lowerTitle.contains('entertainment') || lowerTitle.contains('celebrity')) {
      color = colors['entertainment']!;
    } else if (lowerTitle.contains('community') || lowerTitle.contains('forum')) {
      color = colors['community']!;
    }
    
    final displayTitle = title.length > 25 ? '${title.substring(0, 25)}...' : title;
    return 'https://placehold.co/600x400/$color/ffffff?text=${Uri.encodeComponent(displayTitle)}&font=roboto';
  }

  Future<bool> isLiveNow() async {
    try {
      final videos = await getLiveVideos();
      final liveVideos = videos.where((video) => video.isLive).toList();
      
      if (liveVideos.isNotEmpty) {
        print('🔴 LIVE BROADCAST DETECTED: ${liveVideos.length} live streams');
        return true;
      } else {
        print('⚫ No live broadcasts currently');
        return false;
      }
    } catch (e) {
      print('❌ Error checking live status: $e');
      return false;
    }
  }

  // Get only recent non-live videos
  Future<List<FacebookLive>> getRecentVideos() async {
    try {
      final videos = await getLiveVideos();
      final recentVideos = videos.where((video) => !video.isLive).toList();
      print('📹 Found ${recentVideos.length} recent videos');
      return recentVideos;
    } catch (e) {
      print('❌ Error getting recent videos: $e');
      return [];
    }
  }

  // Get only live videos
  Future<List<FacebookLive>> getLiveVideosOnly() async {
    try {
      final videos = await getLiveVideos();
      final liveVideos = videos.where((video) => video.isLive).toList();
      print('🎥 Found ${liveVideos.length} live videos');
      return liveVideos;
    } catch (e) {
      print('❌ Error getting live videos: $e');
      return [];
    }
  }

  String getPageUrl() {
    return _pageUrl;
  }

  // Get page profile picture
  Future<String> getPageProfilePicture() async {
    try {
      final response = await http.get(
        Uri.parse('https://graph.facebook.com/v19.0/$_pageId/picture?'
            'type=large&width=400&height=400&redirect=false&'
            'access_token=$_accessToken'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final url = data['data']['url'];
        print('🖼️ Found page profile picture: $url');
        return url;
      }
    } catch (e) {
      print('❌ Error fetching profile picture: $e');
    }
    
    return 'https://placehold.co/400x400/1e3a8a/ffffff?text=Nation+Online&font=roboto';
  }

  // Test the connection
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('https://graph.facebook.com/v19.0/$_pageId?'
            'fields=name&'
            'access_token=$_accessToken'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Facebook connection successful: ${data['name']}');
        return true;
      } else {
        print('❌ Facebook connection failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Facebook connection error: $e');
      return false;
    }
  }
}