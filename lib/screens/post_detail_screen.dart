import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/post.dart';
import '../utils/html_utils.dart';
import '../services/settings_service.dart';
import '../services/summarization_service.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final SettingsService _settings = SettingsService();
  String? _summary;
  bool _isSummarizing = false;

  @override
  void initState() {
    super.initState();
    // If user opted in to auto-summarize, run summarization
    if (_settings.summarizeOnOpen.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateSummary());
    }
  }

  Future<void> _generateSummary() async {
    setState(() {
      _isSummarizing = true;
    });
    final s = await SummarizationService.summarizeWithApi(widget.post.content);
    if (mounted) {
      setState(() {
        _summary = s;
        _isSummarizing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Summary ready')));
    }
  }

  void _openSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Dark Mode'),
                  ValueListenableBuilder<bool>(
                    valueListenable: _settings.darkMode,
                    builder: (context, v, _) {
                      return Switch(
                        value: v,
                        onChanged: (newV) => _settings.setDarkMode(newV),
                      );
                    },
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Auto-summarize on open'),
                  ValueListenableBuilder<bool>(
                    valueListenable: _settings.summarizeOnOpen,
                    builder: (context, v, _) {
                      return Switch(
                        value: v,
                        onChanged: (newV) => _settings.setSummarizeOnOpen(newV),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Text('Font size')),
                  ValueListenableBuilder<double>(
                    valueListenable: _settings.fontScale,
                    builder: (context, scale, _) {
                      return Expanded(
                        flex: 2,
                        child: Slider(
                          min: 0.8,
                          max: 1.6,
                          divisions: 8,
                          value: scale,
                          onChanged: (v) => _settings.setFontScale(v),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSummarizing ? null : _generateSummary,
                      icon: const Icon(Icons.auto_fix_high),
                      label: Text(_isSummarizing ? 'Summarizing...' : 'Summarize Now'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(stripHtml(widget.post.title)),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      offset: Offset(0, 4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Image.network(
                  widget.post.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  height: 250,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      'assets/placeholder.png',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      height: 250,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20.0),
            Text(
              stripHtml(widget.post.title),
              style: const TextStyle(
                fontSize: 26.0,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Posted on ${widget.post.date}', // Assuming post.date is a valid field
              style: const TextStyle(
                fontSize: 14.0,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16.0),
            if (_summary != null) ...[
              Text('Summary', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(stripHtml(_summary!), style: const TextStyle(fontSize: 16.0)),
              const SizedBox(height: 16),
            ],
            ValueListenableBuilder<double>(
              valueListenable: _settings.fontScale,
              builder: (context, scale, _) {
                return Html(
                  data: widget.post.content,
                  style: {
                    "p": Style(
                      fontSize: FontSize(18.0 * scale),
                      lineHeight: LineHeight(1.6),
                      margin: Margins.only(bottom: 16.0),
                    ),
                    "img": Style(
                      width: Width.auto(),
                      height: Height.auto(),
                      display: Display.block,
                      margin: Margins.only(bottom: 16.0),
                    ),
                  },
                  extensions: [
                    TagExtension(
                      tagsToExtend: {"img"},
                      builder: (context) {
                        final String? imageUrl = context.attributes['src'];
                        if (imageUrl != null) {
                          return GestureDetector(
                            onTap: () => launchUrl(Uri.parse(imageUrl)),
                            child: Image.network(imageUrl, fit: BoxFit.cover),
                          );
                        }
                        return Container(); // Empty if no image
                      },
                    ),
                  ],
                  onAnchorTap: (url, attributes, element) {
                    if (url != null) {
                      launchUrl(Uri.parse(url));
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _openSettingsSheet,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
