class SimpleCache {
  constructor(ttlSeconds = 3600) {
    this.cache = new Map();
    this.ttl = ttlSeconds * 1000;
  }

  get(key) {
    const item = this.cache.get(key);
    if (!item) return null;
    
    if (Date.now() > item.expiry) {
      this.cache.delete(key);
      return null;
    }
    
    return item.value;
  }

  set(key, value) {
    this.cache.set(key, {
      value: value,
      expiry: Date.now() + this.ttl
    });
  }

  delete(key) {
    this.cache.delete(key);
  }

  clear() {
    this.cache.clear();
  }
}

// Singleton instances for different data types
// Stream URLs expire after 1 hour to prevent stale CDN links
const streamCache = new SimpleCache(3600);

// Search results and playlists expire after 24 hours
const metadataCache = new SimpleCache(86400);

module.exports = {
  SimpleCache,
  streamCache,
  metadataCache
};
