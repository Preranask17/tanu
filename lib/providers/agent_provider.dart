import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/agent/gemini_agent_engine.dart';
import '../services/agent/local_agent_engine.dart';
import '../constants.dart';
import 'settings_provider.dart';

/// Provides a configured LocalHeuristicAgentEngine (offline fallback).
final localEngineProvider = Provider<LocalHeuristicAgentEngine>((ref) {
  return LocalHeuristicAgentEngine();
});

/// Provides the cloud agent used for memory chat and processing.
final geminiEngineProvider = Provider<GeminiAgentEngine>((ref) {
  final settingsKey = ref.watch(settingsProvider).geminiApiKey;
  return GeminiAgentEngine(
    apiKey: settingsKey.isNotEmpty ? settingsKey : kGeminiApiKey,
  );
});

/// Provides the processor for turning raw transcripts into structured memories.
final memoryProcessorProvider = Provider<GeminiMemoryProcessor>((ref) {
  return GeminiMemoryProcessor(ref.watch(geminiEngineProvider));
});
