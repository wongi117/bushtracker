import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class WikipediaService {
  static const String _baseUrl = 'https://en.wikipedia.org/api/rest_v1';

  static Future<WikipediaArticle?> getNearbyArticle(
      double lat, double lon) async {
    try {
      final url = '$_baseUrl/page/geo/0/$lat/$lon';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WikipediaArticle(
          title: data['title'] ?? '',
          extract: data['extract'] ?? '',
          thumbnail: data['thumbnail']?['source'],
          pageUrl: data['content_urls']?['desktop']?['page'],
        );
      }
    } catch (e) {
      debugPrint('Wikipedia error: $e');
    }
    return null;
  }

  static Future<WikipediaArticle?> searchArticle(String query) async {
    try {
      const searchUrl = 'https://en.wikipedia.org/w/api.php';
      final searchParams = {
        'action': 'query',
        'list': 'search',
        'srsearch': query,
        'format': 'json',
        'origin': '*',
        'srlimit': '1',
      };

      final searchResponse = await http.get(
        Uri.parse(searchUrl).replace(queryParameters: searchParams),
      );

      if (searchResponse.statusCode == 200) {
        final searchData = json.decode(searchResponse.body);
        final results = searchData['query']?['search'] as List?;

        if (results != null && results.isNotEmpty) {
          final pageId = results.first['pageid'];
          return getArticleById(pageId);
        }
      }
    } catch (e) {
      debugPrint('Wikipedia search error: $e');
    }
    return null;
  }

  static Future<WikipediaArticle?> getArticleById(int pageId) async {
    try {
      final url = '$_baseUrl/page/summary/$pageId';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WikipediaArticle(
          title: data['title'] ?? '',
          extract: data['extract'] ?? '',
          thumbnail: data['thumbnail']?['source'],
          pageUrl: data['content_urls']?['desktop']?['page'],
        );
      }
    } catch (e) {
      debugPrint('Wikipedia article error: $e');
    }
    return null;
  }

  static Future<WikipediaArticle?> getPlaceInfo(String placeName) async {
    return searchArticle('$placeName Western Australia');
  }
}

class WikipediaArticle {
  final String title;
  final String extract;
  final String? thumbnail;
  final String? pageUrl;

  WikipediaArticle({
    required this.title,
    required this.extract,
    this.thumbnail,
    this.pageUrl,
  });
}

class WikipediaInfoSheet extends StatelessWidget {
  final WikipediaArticle article;

  const WikipediaInfoSheet({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5722).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.public,
                    color: Color(0xFFFF5722), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Wikipedia',
                style: TextStyle(
                  color: Color(0xFFFF5722),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            article.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (article.thumbnail != null)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(article.thumbnail!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            article.extract,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          if (article.pageUrl != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                // Open URL
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5722).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Read More on Wikipedia',
                    style: TextStyle(
                      color: Color(0xFFFF5722),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
