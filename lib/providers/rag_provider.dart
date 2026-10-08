import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/agent_provider.dart';
import '../providers/settings_provider.dart';
import '../constants.dart';
import '../services/rag/embedding_service.dart';
import '../services/rag/memory_indexer.dart';
import '../services/rag/rag_service.dart';
import '../services/rag/vector_store.dart';

final embeddingServiceProvider = Provider<EmbeddingService>((ref) {
  final settingsKey = ref.watch(settingsProvider).geminiApiKey;
  return EmbeddingService(
    apiKey: settingsKey.isNotEmpty ? settingsKey : kGeminiApiKey,
  );
});

/// Lazily opened SQLite vector store; kept alive for the app lifetime.
final vectorStoreProvider = FutureProvider<VectorStore>((ref) async {
  final store = await VectorStore.open();
  ref.onDispose(store.dispose);
  return store;
});

final memoryIndexerProvider = FutureProvider<MemoryIndexer>((ref) async {
  final store = await ref.watch(vectorStoreProvider.future);
  return MemoryIndexer(ref.watch(embeddingServiceProvider), store);
});

final ragServiceProvider = FutureProvider<RagService>((ref) async {
  final store = await ref.watch(vectorStoreProvider.future);
  return RagService(
    ref.watch(embeddingServiceProvider),
    store,
    ref.watch(geminiEngineProvider),
  );
});
