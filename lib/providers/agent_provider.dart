import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/agent/gemini_agent_engine.dart';
import '../services/agent/local_agent_engine.dart';

/// Provides a configured LocalHeuristicAgentEngine (offline fallback).
final localEngineProvider = Provider<LocalHeuristicAgentEngine>((ref) {
  return LocalHeuristicAgentEngine();
});

/// Provides the cloud agent used for memory chat and processing.
final geminiEngineProvider = Provider<GeminiAgentEngine>((ref) {
  return GeminiAgentEngine();
});

/// Provides the processor for turning raw transcripts into structured memories.
final memoryProcessorProvider = Provider<GeminiMemoryProcessor>((ref) {
  return GeminiMemoryProcessor(ref.watch(geminiEngineProvider));
});
