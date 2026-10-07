import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/conversation_provider.dart';
import '../widgets/conversation_tile.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deletedSessions = state.conversations.where((s) => s.isDeleted).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Recently Deleted'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          if (deletedSessions.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Empty Trash?'),
                    content: const Text('This will permanently delete all memories in the trash. This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(conversationProvider.notifier).emptyTrash();
                          Navigator.pop(ctx);
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Empty'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Empty', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: deletedSessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 64,
                    color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Trash is empty',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? const Color(0xFF888888) : const Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: deletedSessions.length,
              itemBuilder: (context, index) {
                final session = deletedSessions[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ConversationTile(
                    session: session,
                    isTrash: true, // We will add this flag
                    onRestore: () {
                      ref.read(conversationProvider.notifier).restoreSession(session.id);
                    },
                    onDeletePermanently: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete permanently?'),
                          content: const Text('This memory will be lost forever. This cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                ref.read(conversationProvider.notifier).deleteSessionPermanently(session.id);
                                Navigator.pop(ctx);
                              },
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
