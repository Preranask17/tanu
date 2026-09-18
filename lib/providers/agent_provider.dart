import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/agent/local_agent_engine.dart';

/// Provides a configured LocalHeuristicAgentEngine.
final localEngineProvider = Provider<LocalHeuristicAgentEngine>((ref) {
  return LocalHeuristicAgentEngine();
});

/// Provides the processor for turning raw transcripts into structured memories.
final memoryProcessorProvider = Provider<MemoryProcessor>((ref) {
  return MemoryProcessor(ref.watch(localEngineProvider));
});
