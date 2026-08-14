const https = require('https');

let proxyCache = [];
let lastFetchTime = 0;
// Fetch every 1 hour (3600000 ms)
const CACHE_DURATION_MS = 60 * 60 * 1000;

async function fetchProxies() {
  return new Promise((resolve, reject) => {
    // We use a highly reliable public repository that constantly updates free proxies
    https.get('https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt', (res) => {
      let data = '';

      if (res.statusCode !== 200) {
        return reject(new Error(`Failed to fetch proxy list. Status Code: ${res.statusCode}`));
      }

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          // Split by newline and remove empty lines or invalid entries
          const proxies = data.split('\n')
            .map(p => p.trim())
            .filter(p => p.length > 5 && p.includes(':'));
            
          resolve(proxies);
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', (err) => {
      reject(err);
    });
  });
}

/**
 * Returns a random free HTTP proxy string like "http://ip:port"
 * Automatically refetches the list in the background if the cache expires.
 */
async function getRandomProxy() {
  const now = Date.now();
  
  // If cache is empty or expired, block and fetch fresh proxies
  if (proxyCache.length === 0 || (now - lastFetchTime) > CACHE_DURATION_MS) {
    console.log('[ProxyManager] Fetching fresh public proxy list...');
    try {
      const newProxies = await fetchProxies();
      if (newProxies.length > 0) {
        proxyCache = newProxies;
        lastFetchTime = now;
        console.log(`[ProxyManager] Loaded ${proxyCache.length} free proxies into cache.`);
      }
    } catch (err) {
      console.error('[ProxyManager] Failed to fetch proxies. Will use whatever is left in cache or fallback to no proxy.', err);
    }
  }

  if (proxyCache.length === 0) {
    return null;
  }

  // Pick a random proxy from the array
  const randomIndex = Math.floor(Math.random() * proxyCache.length);
  const rawProxy = proxyCache[randomIndex];
  
  return `http://${rawProxy}`;
}

module.exports = {
  getRandomProxy
};
