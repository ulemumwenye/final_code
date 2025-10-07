import 'dart:async'; // Import for Timer
import 'package:cached_network_image/cached_network_image.dart'; // Added import
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/category.dart';
import '../models/post.dart';
import '../services/wordpress_service.dart';
import '../services/facebook_service.dart'; // Import Facebook service
import '../screens/post_detail_screen.dart';
import '../screens/post_search_delegate.dart';
import '../screens/facebook_live_screen.dart'; // Import the Facebook Live screen
import '../widgets/rotating_splash_image.dart'; // Import the new widget

class HomeScreen extends StatefulWidget {
  final bool darkMode;

  const HomeScreen({super.key, required this.darkMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Custom Decoration for TabBar indicator with pulsing glow
class _PulsingGlowIndicator extends Decoration {
  final Animation<double> animation;
  final Color borderColor;
  final double glowIntensity;

  const _PulsingGlowIndicator({
    required this.animation,
    this.borderColor = Colors.blue,
    this.glowIntensity = 0.5, // Max opacity for the glow
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _PulsingGlowPainter(this, onChanged, animation, glowIntensity);
  }
}

class _PulsingGlowPainter extends BoxPainter {
  final _PulsingGlowIndicator decoration;
  final Animation<double> animation;
  final double glowIntensity;

  _PulsingGlowPainter(
      this.decoration,
      VoidCallback? onChanged,
      this.animation,
      this.glowIntensity,
      ) : super(onChanged) {
    // Listen to the animation to trigger repaints
    animation.addListener(onChanged ?? () {});
  }

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & configuration.size!;
    final paint = Paint();

    // Draw the border line
    paint.color = decoration.borderColor;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0; // Thickness of the underline

    // Draw a simple underline
    final double underlineY = rect.bottom - 1.0; // Position of the underline
    canvas.drawLine(Offset(rect.left, underlineY), Offset(rect.right, underlineY), paint);

    // Draw the glow
    // The glow's opacity and blur will be animated
    final double currentGlowOpacity = animation.value * glowIntensity;
    final double currentGlowBlur = 5.0 + animation.value * 10.0; // Animate blur radius

    if (currentGlowOpacity > 0) {
      final glowPaint = Paint()
        ..color = decoration.borderColor.withOpacity(currentGlowOpacity)
        ..style = PaintingStyle.stroke // Can also be fill if preferred for glow shape
        ..strokeWidth = 3.0 // Make glow slightly thicker than the underline
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, currentGlowBlur); // Apply blur for glow effect

      // Draw the glow slightly offset or around the underline
      // For simplicity, drawing another line with blur. More complex shapes can be used.
      canvas.drawLine(Offset(rect.left, underlineY), Offset(rect.right, underlineY), glowPaint);
    }
  }
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin { // Changed to TickerProviderStateMixin
  final WordPressService _wordPressService = WordPressService();
  final FacebookService _facebookService = FacebookService(); // Facebook service instance
  late Future<List<Category>> _futureCategories;
  late Future<List<Post>> _featuredPostsFuture;
  final List<Post> _posts = [];
  final PageController _pageController = PageController(viewportFraction: 0.9);
  final ScrollController _scrollController = ScrollController(); // For back-to-top button
  late AnimationController _animationController; // For fade-in animations
  late Animation<double> _fadeAnimation; // For fade-in animations

  TabController? _tabController; // For category tabs
  late AnimationController _glowAnimationController; // For tab indicator glow
  late Animation<double> _glowAnimation; // For tab indicator glow

  List<Category> _mainCategoryList = []; // To store the filtered list of main categories

  bool _showPopularArticles = true; // For scroll-based visibility
  static const double _popularArticlesScrollThreshold = 200.0; // Threshold for hiding popular articles

  int _page = 1;
  bool _isLoading = false;
  int? _selectedCategoryId;
  String? _selectedCategoryName; // To store the name of the selected category
  int _selectedIndex = 0;
  int _currentPage = 0; // Used by PageView.onPageChanged to track current slider page
  Timer? _timer; // Timer for auto-slide
  List<Post> _currentFeaturedPosts = []; // Holds current featured posts for the slider
  bool _isLiveNow = false; // Track if Nation Online is currently live
  Timer? _liveCheckTimer; // Timer for checking live status

  @override
  void initState() {
    super.initState();
    _futureCategories = _wordPressService.fetchCategories().then((categories) {
      print('Fetched Categories: $categories'); // Debugging: Print fetched categories
      _setupTabController(categories); // Call setup for TabController
      // Set initial selected category based on the first tab
      if (_mainCategoryList.isNotEmpty) {
        _selectedCategoryId = _mainCategoryList[0].id;
        _selectedCategoryName = _mainCategoryList[0].name;
      }
      _loadPosts(); // Load posts for the initial category
      return categories;
    });

    _featuredPostsFuture = _fetchFeaturedPosts();
    _featuredPostsFuture.then((value) {
      if (mounted) {
        setState(() {
          _currentFeaturedPosts = value;
        });
        _startAutoSlide(); // Start timer only after featured posts are loaded
      }
    }).catchError((error) {
      print('Error fetching featured posts for timer: $error');
    });

    // Initialize fade animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _animationController.forward(); // Start the animation

    // Initialize glow animation controller
    _glowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Duration for one pulse cycle
    )..repeat(reverse: true); // Repeat the animation, reversing it each time

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowAnimationController, curve: Curves.easeInOut),
    );

    _scrollController.addListener(_handleScroll);
    
    // Start checking for live broadcasts (but less frequently to avoid false indicators)
    _startLiveStatusMonitoring();
  }

  void _startLiveStatusMonitoring() {
    // Don't check immediately to avoid false LIVE indicators
    _liveCheckTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      _checkLiveStatus();
    });
  }

  Future<void> _checkLiveStatus() async {
    try {
      final isLive = await _facebookService.isLiveNow();
      // Only update if state actually changed to avoid unnecessary rebuilds
      if (mounted && isLive != _isLiveNow) {
        setState(() {
          _isLiveNow = isLive;
        });
        if (isLive) {
          print('🔴 LIVE broadcast detected!');
        }
      }
    } catch (e) {
      print('Error checking live status: $e');
      // On error, assume not live to avoid false indicators
      if (mounted && _isLiveNow) {
        setState(() {
          _isLiveNow = false;
        });
      }
    }
  }

  void _handleScroll() {
    if (_scrollController.offset > _popularArticlesScrollThreshold && _showPopularArticles) {
      setState(() {
        _showPopularArticles = false;
      });
    } else if (_scrollController.offset <= _popularArticlesScrollThreshold && !_showPopularArticles) {
      setState(() {
        _showPopularArticles = true;
      });
    }
  }

  void _setupTabController(List<Category> allCategories) {
    final mainCategoryNames = ['News', 'National Sports', 'Feature', 'Entertainment', 'Business'];
    // Filter categories and store them
    _mainCategoryList = allCategories.where((category) => mainCategoryNames.contains(category.name)).toList();

    if (_mainCategoryList.isNotEmpty) {
      _tabController = TabController(length: _mainCategoryList.length, vsync: this);
      _tabController!.addListener(() {
        if (_tabController!.indexIsChanging) {
          // Tab selection is changing
        } else {
          // Tab selection has completed
          final selectedIndex = _tabController!.index;
          _onCategorySelected(_mainCategoryList[selectedIndex].id, _mainCategoryList[selectedIndex].name);
        }
      });
      // Set initial selected category ID and name here if not already set
      if (_selectedCategoryId == null && _mainCategoryList.isNotEmpty) {
        _selectedCategoryId = _mainCategoryList[0].id;
        _selectedCategoryName = _mainCategoryList[0].name;
      }
    }
    // Ensure UI rebuilds after _tabController is initialized
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    _pageController.dispose(); // Dispose the PageController
    _scrollController.removeListener(_handleScroll); // Remove scroll listener
    _scrollController.dispose(); // Dispose the ScrollController
    _animationController.dispose(); // Dispose the AnimationController
    _tabController?.dispose(); // Dispose the TabController
    _glowAnimationController.dispose(); // Dispose the Glow AnimationController
    _liveCheckTimer?.cancel(); // Cancel live status timer
    super.dispose();
  }

  void _startAutoSlide() {
    _timer?.cancel(); // Cancel any existing timer

    // Guard: Do not start if posts are empty, controller not ready, or no pages.
    if (_currentFeaturedPosts.isEmpty || !_pageController.hasClients || _pageController.page == null) {
      return;
    }

    final itemCount = _currentFeaturedPosts.length;
    if (itemCount == 0) return; // Should be caught by _currentFeaturedPosts.isEmpty already

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_pageController.hasClients || _pageController.page == null) { // Check again inside timer
        timer.cancel();
        return;
      }
      final int currentPageIndex = _pageController.page!.round();
      final int nextPage = (currentPageIndex + 1) % itemCount;

      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 300), // Smoother transition
        curve: Curves.easeInOut,
      );
      // _currentPage is updated by PageView.onPageChanged, so no setState here for _currentPage
    });
  }

  Future<List<Post>> _fetchFeaturedPosts() async {
    return _wordPressService.fetchPosts(
      categoryId: 25, // Fetch posts only from category 25
      page: 1,
      perPage: 5, // Fetch 5 featured posts
    );
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);

    try {
      final newPosts = await _wordPressService.fetchPosts(
        categoryId: _selectedCategoryId,
        page: _page,
        perPage: 10, // Fetch 10 posts per page
      );

      setState(() {
        _posts.addAll(newPosts);
        _page++;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load posts: $e')),
      );
    }
  }

  void _onCategorySelected(int categoryId, String categoryName) {
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedCategoryName = categoryName; // Keep track of the name
      _posts.clear();
      _page = 1;
      _loadPosts();
    });
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        // Scroll to the top of the page
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        break;
      case 1:
        _launchUrl('https://youtube.com');
        break;
      case 2:
        _launchUrl('https://podcasts.com');
        break;
      case 3:
        // Navigate to Facebook Live screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FacebookLiveScreen()),
        );
        break;
      case 4:
        _showSocialMediaPopup();
        break;
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $urlString')),
      );
    }
  }

  void _showSocialMediaPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Follow Us'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Image.asset('assets/facebook.png', width: 24, height: 24),
                title: const Text('Facebook'),
                onTap: () {
                  _launchUrl('https://facebook.com/NationOnlineMw');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Image.asset('assets/twitter.png', width: 24, height: 24),
                title: const Text('Twitter'),
                onTap: () {
                  _launchUrl('https://twitter.com');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Image.asset('assets/instagram.png', width: 24, height: 24),
                title: const Text('Instagram'),
                onTap: () {
                  _launchUrl('https://instagram.com');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Image.asset('assets/tik-tok.png', width: 24, height: 24),
                title: const Text('TikTok'),
                onTap: () {
                  _launchUrl('https://tiktok.com');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Image.asset('assets/whatsapp.png', width: 24, height: 24),
                title: const Text('WhatsApp'),
                onTap: () {
                  _launchUrl('https://whatsapp.com');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedSlider(List<Post> posts) { // `posts` here is _currentFeaturedPosts
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollStartNotification && notification.dragDetails != null) {
          // User started dragging
          _timer?.cancel();
        } else if (notification is ScrollEndNotification) {
          // User stopped dragging, restart timer
          _startAutoSlide();
        }
        return true; // Continue bubbling notification
      },
      child: SizedBox(
        height: 200,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: posts.length, // Use the passed 'posts' which is _currentFeaturedPosts
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index; // This is fine for the dots indicator
                });
              },
              itemBuilder: (context, index) {
                final post = posts[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrl,
                      fit: BoxFit.cover,
                      memCacheHeight: (200 * MediaQuery.of(context).devicePixelRatio).round(),
                      memCacheWidth: ((MediaQuery.of(context).size.width * 0.9) * MediaQuery.of(context).devicePixelRatio).round(),
                      placeholder: (context, url) => const Center(child: RotatingSplashImage(size: 40.0)),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 10,
              child: Row(
                children: List.generate(posts.length, (index) { // Use posts.length for dots
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.5),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabBar(List<Category> categories) {
    // Uses _mainCategoryList which is now a state variable, populated by _setupTabController
    if (_tabController == null || _mainCategoryList.isEmpty) {
      // Show a loader or an empty container while categories are being fetched and processed
      return Container(height: 60, child: const Center(child: RotatingSplashImage(size: 30.0)));
    }

    // Debugging: Print the fetched and filtered categories
    // print('All Categories in buildCategoryTabBar: $categories'); // categories parameter is no longer directly used here for tabs
    print('Main Category List for Tabs: $_mainCategoryList');


    return Container(
      height: 60, // Adjust as needed
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true, // Good for potentially many categories
        labelColor: Colors.blue, // Color of the text for selected tab
        unselectedLabelColor: Colors.black54, // Color of the text for unselected tabs
        indicator: _PulsingGlowIndicator(
          animation: _glowAnimation,
          borderColor: Colors.blue, // Customize as needed
        ),
        tabs: _mainCategoryList.map((Category category) {
          return Tab(text: category.name);
        }).toList(),
        onTap: (index) {
          // The listener on _tabController already handles this,
          // but if specific onTap logic is needed immediately, it can go here.
          // _onCategorySelected(_mainCategoryList[index].id, _mainCategoryList[index].name);
        },
      ),
    );
  }

  Widget _buildPopularArticles(List<Post> posts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Popular Articles',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
                ),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrl,
                      width: 120,
                      height: double.infinity, // Height is determined by parent SizedBox (150)
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const SizedBox(
                        width: 120,
                        height: 150, // Match the SizedBox height for popular articles
                        child: Center(child: RotatingSplashImage(size: 30.0)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 120,
                        height: 150, // Match the SizedBox height
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.error, color: Colors.grey, size: 30.0)),
                      ),
                      memCacheHeight: (150 * MediaQuery.of(context).devicePixelRatio).round(),
                      memCacheWidth: (120 * MediaQuery.of(context).devicePixelRatio).round(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerEffect() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 0.8,
      ),
      padding: const EdgeInsets.all(8.0),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            child: Container(color: Colors.white),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(text: 'Nation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
              TextSpan(text: ' Online', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
        ),
        actions: [
          // Live indicator badge - Only show when actually live
          if (_isLiveNow)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FacebookLiveScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Animated pulsing dot for live indicator
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: PostSearchDelegate(_posts));
            },
          ),
          TextButton(
            onPressed: () {
              _launchUrl('https://mwnation.com/epaper/membership/');
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red, // Red background
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6), // Slightly rounded corners
              ),
            ),
            child: const Text(
              'Sign In',
              style: TextStyle(
                color: Colors.white, // White text
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: FutureBuilder<List<Category>>(
          future: _futureCategories,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: RotatingSplashImage(size: 40.0));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No categories found.'));
            }
            final allCategories = snapshot.data!;
            // Use _mainCategoryList to determine which categories are already in the TabBar
            final mainCategoryNamesInTabs = _mainCategoryList.map((c) => c.name).toList();
            final drawerCategories = allCategories.where((category) => !mainCategoryNamesInTabs.contains(category.name)).toList();

            // Debugging: Print the drawer categories
            print('Drawer Categories: $drawerCategories');

            return ListView.builder(
              itemCount: drawerCategories.length,
              itemBuilder: (context, index) {
                final category = drawerCategories[index];
                return ListTile(
                  title: Text(category.name),
                  onTap: () {
                    // Find if this category is one of the main categories (it shouldn't be by this logic)
                    // Or if you want to switch tabs from drawer:
                    int tabIndex = _mainCategoryList.indexWhere((c) => c.id == category.id);
                    if (tabIndex != -1) {
                      _tabController?.animateTo(tabIndex);
                      _onCategorySelected(category.id, category.name);
                    } else {
                      // Handle selection of a non-main category (e.g., load its posts directly)
                      _onCategorySelected(category.id, category.name);
                    }
                    Navigator.pop(context); // Close the drawer
                  },
                );
              },
            );
          },
        ),
      ),
      // FIXED: Only show rotating splash image, removed duplicate static image
      body: _isLoading && _posts.isEmpty
          ? const Center(
              child: RotatingSplashImage(size: 80.0),
            )
          : Column(
        children: [
          FutureBuilder<List<Post>>(
            future: _featuredPostsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 200, child: Center(child: RotatingSplashImage(size: 50.0)));
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load featured posts. Please try again.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _featuredPostsFuture = _fetchFeaturedPosts();
                          });
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
              return _buildFeaturedSlider(snapshot.data!);
            },
          ),
          FutureBuilder<List<Category>>(
            future: _futureCategories,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: RotatingSplashImage(size: 40.0));
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load categories. Please try again.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _futureCategories = _wordPressService.fetchCategories();
                          });
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
              return _buildCategoryTabBar(snapshot.data!);
            },
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SizeTransition(sizeFactor: animation, child: child);
            },
            child: _showPopularArticles
                ? _buildPopularArticles(_posts.length >= 5 ? _posts.sublist(0, 5) : _posts)
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _posts.clear();
                  _page = 1;
                  _featuredPostsFuture = _fetchFeaturedPosts(); // Refresh featured posts
                });
                await _loadPosts();
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: CachedNetworkImage(
                                imageUrl: post.imageUrl,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const SizedBox(
                                  height: 150, // Match image height
                                  width: double.infinity,
                                  child: Center(child: RotatingSplashImage(size: 40.0)),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 150, // Match image height
                                  width: double.infinity,
                                  color: Colors.grey[200],
                                  child: const Center(child: Icon(Icons.error, color: Colors.grey, size: 40.0)),
                                ),
                                memCacheHeight: (150 * MediaQuery.of(context).devicePixelRatio).round(),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    post.excerpt,
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
                                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Oct 10, 2023', // Replace with actual post date
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(Icons.person, size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Author Name', // Replace with actual author name
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
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
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: 'Youtube'),
          BottomNavigationBarItem(icon: Icon(Icons.mic), label: 'Podcasts'),
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Streams'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            },
            child: const Icon(Icons.arrow_upward),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _posts.clear();
                _page = 1;
              });
              _loadPosts();
            },
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}