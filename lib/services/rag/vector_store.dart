import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite_vector/sqlite_vector.dart';

import '../../constants.dart';

/// One indexed chunk of memory text with provenance.
class MemoryChunk {
  const MemoryChunk({
    required this.id,
    required this.sessionId,
    required this.text,
    required this.startMs,
  });

  final String id;
  final String sessionId;
  final String text;
  final int startMs;
}

/// A chunk matched against a query, with its distance (lower = closer).
class ScoredChunk {
  const ScoredChunk({required this.chunk, required this.distance});

  final MemoryChunk chunk;
  final double distance;
}

/// SQLite + sqlite-vector storage for transcript chunks.
class VectorStore {
  VectorStore._(this._db);

  final Database _db;

  static bool _extensionLoaded = false;

  static Future<VectorStore> open() async {
    if (!_extensionLoaded) {
      sqlite3.loadSqliteVectorExtension();
      _extensionLoaded = true;
    }
    final dir = await getApplicationSupportDirectory();
    final db = sqlite3.open(p.join(dir.path, 'tanu_vec.db'));
    final store = VectorStore._(db);
    store._migrate();
    return store;
  }

  void _migrate() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS chunks (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        text TEXT NOT NULL,
        start_ms INTEGER NOT NULL DEFAULT 0,
        embedding BLOB
      )
    ''');
    _db.execute(
        "SELECT vector_init('chunks', 'embedding', 'type=FLOAT32,dimension=$kEmbeddingDims')");
  }

  void upsertChunks(List<MemoryChunk> chunks, List<List<double>> vectors) {
    assert(chunks.length == vectors.length);
    _db.execute('BEGIN');
    try {
      final stmt = _db.prepare(
        'INSERT OR REPLACE INTO chunks (id, session_id, text, start_ms, embedding) VALUES (?, ?, ?, ?, vector_as_f32(?))',
      );
      final del = _db.prepare('DELETE FROM chunks WHERE id = ?');
      for (var i = 0; i < chunks.length; i++) {
        del.execute([chunks[i].id]);
        stmt.execute([
          chunks[i].id,
          chunks[i].sessionId,
          chunks[i].text,
          chunks[i].startMs,
          jsonEncode(vectors[i]),
        ]);
      }
      stmt.dispose();
      del.dispose();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// k-nearest chunks, optionally scoped to one session.
  List<ScoredChunk> query(List<double> vector, int topK, {String? sessionId}) {
    final scanK = sessionId == null ? topK : topK * 8;
    final rows = _db.select('''
      SELECT c.id, c.session_id, c.text, c.start_ms, v.distance
      FROM chunks AS c
      JOIN vector_full_scan('chunks', 'embedding', vector_as_f32(?), $scanK) AS v
        ON c.rowid = v.rowid
      ORDER BY v.distance ASC
    ''', [jsonEncode(vector)]);

    final out = <ScoredChunk>[];
    for (final row in rows) {
      if (sessionId != null && row['session_id'] != sessionId) continue;
      out.add(ScoredChunk(
        chunk: MemoryChunk(
          id: row['id'] as String,
          sessionId: row['session_id'] as String,
          text: row['text'] as String,
          startMs: row['start_ms'] as int,
        ),
        distance: (row['distance'] as num).toDouble(),
      ));
      if (out.length >= topK) break;
    }
    return out;
  }

  void deleteSession(String sessionId) {
    _db.execute('DELETE FROM chunks WHERE session_id = ?', [sessionId]);
  }

  int get chunkCount {
    final rs = _db.select('SELECT COUNT(*) AS n FROM chunks');
    return rs.first['n'] as int;
  }

  void dispose() => _db.dispose();
}
