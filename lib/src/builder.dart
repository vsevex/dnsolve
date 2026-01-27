part of 'dnsolve.dart';

/// A builder for creating [DNSolve] instances with custom configuration.
class DNSolveBuilder {
  http.Client? _client;
  bool _enableCache = false;
  int _cacheMaxSize = 100;
  bool _enableStatistics = false;
  int _maxRetries = 0;
  Duration _retryDelay = const Duration(milliseconds: 500);

  /// Sets a custom HTTP client.
  DNSolveBuilder withClient(http.Client client) {
    _client = client;
    return this;
  }

  /// Enables or disables response caching.
  DNSolveBuilder withCache({bool enable = true, int maxSize = 100}) {
    _enableCache = enable;
    _cacheMaxSize = maxSize;
    return this;
  }

  /// Enables or disables query statistics tracking.
  DNSolveBuilder withStatistics({bool enable = true}) {
    _enableStatistics = enable;
    return this;
  }

  /// Sets the maximum number of retries for failed queries.
  DNSolveBuilder withRetries(int maxRetries) {
    _maxRetries = maxRetries;
    return this;
  }

  /// Sets the delay between retries.
  DNSolveBuilder withRetryDelay(Duration delay) {
    _retryDelay = delay;
    return this;
  }

  /// Builds and returns a configured [DNSolve] instance.
  DNSolve build() => DNSolve(
        client: _client,
        enableCache: _enableCache,
        cacheMaxSize: _cacheMaxSize,
        enableStatistics: _enableStatistics,
        maxRetries: _maxRetries,
        retryDelay: _retryDelay,
      );
}
