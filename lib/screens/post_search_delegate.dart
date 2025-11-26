import 'package:flutter/material.dart';
import '../models/post.dart';
import '../utils/html_utils.dart';

class PostSearchDelegate extends SearchDelegate {
  final List<Post> posts;

  PostSearchDelegate(this.posts);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = posts.where((post) => sanitizeForSearch(post.title).contains(query.toLowerCase())).toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(stripHtml(results[index].title)),
          onTap: () {
            close(context, results[index]);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = posts.where((post) => sanitizeForSearch(post.title).contains(query.toLowerCase())).toList();
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(stripHtml(suggestions[index].title)),
          onTap: () {
            query = stripHtml(suggestions[index].title);
          },
        );
      },
    );
  }
}
