import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../models/transcript.dart';
import '../screens/chat_screen.dart';
import '../services/proactive/proactive_service.dart';
import 'conversation_provider.dart';

/// Lazily initialized proactive notification service.
final proactiveServiceProvider = FutureProvider<ProactiveService>((ref) async {
  final svc = await ProactiveService.init(onTap: (sessionId) {
    final conversation = ref.read(conversationProvider);
    ConversationSession? session;
    try {
      session = conversation.conversations.firstWhere((s) => s.id == sessionId);
    } catch (_) {
      session = null;
    }
    if (session != null) {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => SessionDetailPage(session: session!),
        ),
      );
    }
  });
  return svc;
});
