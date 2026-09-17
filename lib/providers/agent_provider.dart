import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/agent/mistral_agent_engine.dart';
import 'settings_provider.dart';

/// Provides a configured MistralAgentEngine using the user's settings.
final mistralEngineProvider = Provider<MistralAgentEngine>((ref) {
  final settings = ref.watch(settingsProvider);
  return MistralAgentEngine(
    apiKey: settings.apiKey,
    model: settings.model,
  );
});

/// Provides the processor for turning raw transcripts into structured memories.
final memoryProcessorProvider = Provider<MemoryProcessor>((ref) {
  return MemoryProcessor(ref.watch(mistralEngineProvider));
});
