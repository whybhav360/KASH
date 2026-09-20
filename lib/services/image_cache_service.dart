import 'dart:io';

/// In-memory cache for file existence checks to prevent main-thread disk I/O stalls
/// during frame rendering, list scrolling, and screen transition animations.
class ImageCacheService {
  static final Map<String, bool> _existenceCache = {};

  /// Checks if a file exists at the given path, caching the result in memory.
  static bool fileExists(String? path) {
    if (path == null || path.isEmpty) return false;
    return _existenceCache.putIfAbsent(path, () => File(path).existsSync());
  }

  /// Invalidate a single path in the cache (e.g., when an image is updated/deleted).
  static void invalidate(String? path) {
    if (path != null) {
      _existenceCache.remove(path);
    }
  }

  /// Clear the entire file existence cache.
  static void clear() {
    _existenceCache.clear();
  }
}
