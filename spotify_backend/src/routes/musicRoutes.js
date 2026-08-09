const express = require('express');
const YTMusic = require('ytmusic-api');

const router = express.Router();
const ytmusic = new YTMusic();
let ytmusicInitialized = false;

// Initialize YTMusic
async function initYTMusic() {
  if (!ytmusicInitialized) {
    await ytmusic.initialize();
    ytmusicInitialized = true;
  }
}

// 1. Search using YouTube Music
router.get('/search', async (req, res) => {
  try {
    const query = req.query.q;
    if (!query) {
      return res.status(400).json({ error: 'Missing search query' });
    }

    await initYTMusic();
    const searchResults = await ytmusic.searchSongs(query);

    const results = searchResults.map(song => {
      // Find the best quality thumbnail
      const thumbnails = song.thumbnails || [];
      const bestThumbnail = thumbnails.length > 0 
        ? thumbnails[thumbnails.length - 1].url 
        : '';
        
      const artist = song.artist?.name || 'Unknown Artist';

      return {
        videoId: song.videoId,
        title: song.name,
        artist: artist,
        thumbnailUrl: bestThumbnail,
        duration: song.duration,
      };
    });

    res.json(results);
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ error: 'Failed to search for songs.' });
  }
});

// 2. Stream using YouTube Music directly
router.get('/stream/:songId', async (req, res) => {
  try {
    const videoId = req.params.songId;
    if (!videoId) {
      return res.status(400).json({ error: 'Missing songId' });
    }

const youtubedl = require('youtube-dl-exec');

    // Extract direct audio stream URL using youtube-dl-exec (yt-dlp)
    const ytUrl = `https://www.youtube.com/watch?v=${videoId}`;
    const output = await youtubedl(ytUrl, {
      dumpSingleJson: true,
      format: 'bestaudio',
      noCheckCertificates: true,
      noWarnings: true,
      addHeader: ['referer:youtube.com', 'user-agent:Mozilla/5.0']
    });
    
    if (!output || !output.url) {
      return res.status(404).json({ error: 'No audio streams found for this song' });
    }

    res.json({ 
      streamUrl: output.url, 
      duration: output.duration || 0
    });
  } catch (error) {
    console.error('Stream error:', error);
    res.status(500).json({ error: 'Failed to get stream URL' });
  }
});

module.exports = router;
