import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// SummarizationService provides a simple wrapper for generating article
/// summaries. If no external API key/endpoint is configured, it falls back to
/// a local heuristic (first N sentences).
class SummarizationService {
  // TODO: allow configuring endpoint & key via SharedPreferences or secure store

  /// Fallback summarizer: take first [sentences] sentences.
  static String simpleSummarize(String content, {int sentences = 3}) {
    // Extract sentences using a pattern compatible with Dart's RegExp (no lookbehind)
    final sentenceRegExp = RegExp(r'[^.!?]+[.!?]?', multiLine: true);
    final matches = sentenceRegExp.allMatches(content).map((m) => m.group(0)?.trim()).whereType<String>().where((s) => s.isNotEmpty).toList();
    if (matches.isEmpty) {
      // fallback to first 200 chars
      return content.trim().substring(0, content.length < 200 ? content.length : 200).trim();
    }
    return matches.take(sentences).join(' ').trim();
  }

  /// Attempt an API summarization. Expects [endpoint] to accept JSON {"text": "..."}
  /// and return JSON {"summary": "..."}. If endpoint is null or the call fails,
  /// fallback to [simpleSummarize].
  static Future<String> summarizeWithApi(String content, {String? endpoint, String? apiKey}) async {
    // If endpoint/key not provided, try reading from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      endpoint ??= prefs.getString('summarizeEndpoint');
      apiKey ??= prefs.getString('summarizeApiKey');
    } catch (_) {}

    if (endpoint == null || endpoint.isEmpty) {
      return simpleSummarize(content);
    }

    try {
      final resp = await http.post(Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            if (apiKey != null && apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({'text': content}));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map && data['summary'] != null) return data['summary'].toString();
      }
    } catch (e) {
      // ignore and fallback
    }
    return simpleSummarize(content);
  }
}
