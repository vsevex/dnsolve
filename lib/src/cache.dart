part of 'dnsolve.dart';

/// A simple TTL-based cache for DNS responses.
class _DNSCache {
  _DNSCache({this.maxSize = 100});

  final int maxSize;
  final Map<String, _CacheEntry> _cache = {};

  /// Gets a cached response if it exists and hasn't expired.
  ResolveResponse? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.expiresAt.isBefore(DateTime.now())) {
      _cache.remove(key);
      return null;
    }

    return entry.response;
  }

  /// Stores a response in the cache with TTL.
  void put(String key, ResolveResponse response) {
    if (_cache.length >= maxSize) {
      // Remove oldest entry
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }

    // Use minimum TTL from records, or default to 60 seconds
    int ttl = 60;
    if (response.answer?.records != null &&
        response.answer!.records!.isNotEmpty) {
      ttl = response.answer!.records!
          .map((r) => r.ttl)
          .reduce((a, b) => a < b ? a : b);
    }

    _cache[key] = _CacheEntry(
      response: response,
      expiresAt: DateTime.now().add(Duration(seconds: ttl)),
    );
  }

  /// Clears the cache.
  void clear() {
    _cache.clear();
  }

  /// Returns the current cache size.
  int get size => _cache.length;
}

class _CacheEntry {
  const _CacheEntry({
    required this.response,
    required this.expiresAt,
  });

  final ResolveResponse response;
  final DateTime expiresAt;
}
