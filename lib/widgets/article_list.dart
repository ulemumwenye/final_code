import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/article.dart';
import '../screens/article_detail_screen.dart';
import '../utils/html_utils.dart';

class ArticleList extends StatelessWidget {
  final List<Article> articles;

  const ArticleList({super.key, required this.articles});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: SizedBox(
              width: 120,
              height: 150,
              child: CachedNetworkImage(
                imageUrl: article.imageUrl,
                width: 120,
                height: 150,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(width: 120, height: 150, color: Colors.white),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 120,
                  height: 150,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
          ),
          title: Text(stripHtml(article.title)),
          subtitle: Text(stripHtml(article.description)),
          trailing: Text(article.publishedAt),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArticleDetailScreen(article: article),
              ),
            );
          },
        );
      },
    );
  }
}