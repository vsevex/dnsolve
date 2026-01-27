part of 'dnsolve.dart';

/// Statistics for DNS queries.
class DNSStatistics {
  DNSStatistics();

  /// Total number of queries made.
  int totalQueries = 0;

  /// Number of successful queries.
  int successfulQueries = 0;

  /// Number of failed queries.
  int failedQueries = 0;

  /// Total time spent on queries (in milliseconds).
  int totalTimeMs = 0;

  /// Average response time (in milliseconds).
  double get averageResponseTimeMs =>
      totalQueries > 0 ? totalTimeMs / totalQueries : 0.0;

  /// Success rate as a percentage.
  double get successRate =>
      totalQueries > 0 ? (successfulQueries / totalQueries) * 100 : 0.0;

  /// Records a query with its duration and success status.
  void recordQuery(Duration duration, bool success) {
    totalQueries++;
    if (success) {
      successfulQueries++;
    } else {
      failedQueries++;
    }
    totalTimeMs += duration.inMilliseconds;
  }

  /// Resets all statistics.
  void reset() {
    totalQueries = 0;
    successfulQueries = 0;
    failedQueries = 0;
    totalTimeMs = 0;
  }

  @override
  String toString() =>
      'DNSStatistics(total: $totalQueries, success: $successfulQueries, '
      'failed: $failedQueries, avgTime: ${averageResponseTimeMs.toStringAsFixed(2)}ms, '
      'successRate: ${successRate.toStringAsFixed(2)}%)';
}
