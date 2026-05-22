class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _expiryMap = {};

  void setMemoryCache<T>(String key, T value, {Duration? expiration}) {
    _memoryCache[key] = value;
    if (expiration != null) {
      _expiryMap[key] = DateTime.now().add(expiration);
    } else {
      _expiryMap.remove(key);
    }
  }

  T? getMemoryCache<T>(String key) {
    if (!_memoryCache.containsKey(key)) return null;
    
    final expiry = _expiryMap[key];
    if (expiry != null && DateTime.now().isAfter(expiry)) {
      _memoryCache.remove(key);
      _expiryMap.remove(key);
      return null;
    }
    
    return _memoryCache[key] as T?;
  }

  void clearMemoryCache() {
    _memoryCache.clear();
    _expiryMap.clear();
  }

  void removeMemoryCache(String key) {
    _memoryCache.remove(key);
    _expiryMap.remove(key);
  }
}
