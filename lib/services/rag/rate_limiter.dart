import 'dart:async';

/// Simple leaky-bucket rate limiter: guarantees at least [minGap] between calls.
class RateLimiter {
  RateLimiter(this.minGap);

  final Duration minGap;
  Future<void> _last = Future.value();

  Future<T> run<T>(Future<T> Function() fn) async {
    final prev = _last;
    final completer = Completer<void>();
    _last = completer.future;

    try {
      await prev;
    } catch (_) {}

    await Future.delayed(minGap);
    try {
      return await fn();
    } finally {
      completer.complete();
    }
  }
}

/// Parses a Gemini 429 error body for `retryDelay` (seconds), defaults to 5s.
Duration? retryDelayFromBody(String body) {
  final match = RegExp(r'"retryDelay":\s*"(\d+)s"').firstMatch(body);
  if (match != null) return Duration(seconds: int.parse(match.group(1)!));
  return null;
}
