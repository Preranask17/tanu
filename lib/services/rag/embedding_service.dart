import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../constants.dart';
import 'rate_limiter.dart';

/// Embeds text with Gemini's embedding API for the RAG pipeline.
class EmbeddingService {
  EmbeddingService({
    String? apiKey,
    this.model = kGeminiEmbeddingModel,
  }) : apiKey = apiKey ?? kGeminiApiKey;

  final String apiKey;
  final String model;
  final _limiter = RateLimiter(Duration(milliseconds: kGeminiMinGapEmbedMs));

  static String get _batchEndpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/$kGeminiEmbeddingModel:batchEmbedContents';

  /// Embed documents (chunks being indexed).
  Future<List<List<double>>> embedDocuments(List<String> texts) =>
      _embed(texts, taskType: 'RETRIEVAL_DOCUMENT');

  /// Embed a single user query.
  Future<List<double>> embedQuery(String text) async {
    final out = await _embed([text], taskType: 'RETRIEVAL_QUERY');
    return out.first;
  }

  Future<List<List<double>>> _embed(List<String> texts, {required String taskType}) async {
    if (texts.isEmpty) return const [];
    final body = jsonEncode({
      'requests': texts
          .map((t) => {
                'model': 'models/$model',
                'content': {
                  'parts': [
                    {'text': t},
                  ],
                },
                'taskType': taskType,
                'outputDimensionality': kEmbeddingDims,
              })
          .toList(),
    });

    final response = await _limiter.run(() async {
      var r = await http
          .post(
            Uri.parse('$_batchEndpoint?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 45));
      // One graceful retry on 429 using Gemini's retryDelay.
      if (r.statusCode == 429) {
        final wait = retryDelayFromBody(r.body) ?? const Duration(seconds: 5);
        await Future.delayed(wait);
        r = await http
            .post(
              Uri.parse('$_batchEndpoint?key=$apiKey'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 45));
      }
      return r;
    });

    if (response.statusCode != 200) {
      throw Exception('Embedding API returned ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final embeddings = decoded['embeddings'] as List<dynamic>? ?? const [];
    return embeddings
        .map((e) => (e['values'] as List<dynamic>)
            .map((v) => (v as num).toDouble())
            .toList())
        .toList();
  }
}
