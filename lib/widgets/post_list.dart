import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/post.dart';
import '../screens/post_detail_screen.dart';
import '../utils/html_utils.dart';

class PostList extends StatelessWidget {
  final List<Post> posts;

  const PostList({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: SizedBox(
              width: 120,
              height: 150,
              child: CachedNetworkImage(
                imageUrl: post.imageUrl,
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
          title: Text(stripHtml(post.title)),
          subtitle: Text(stripHtml(post.excerpt)),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(post: post),
              ),
            );
          },
        );
      },
    );
  }
}