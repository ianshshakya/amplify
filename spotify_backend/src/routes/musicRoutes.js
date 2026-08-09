const express = require('express');
const YTMusic = require('ytmusic-api');
const ytdl = require('@distube/ytdl-core');

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
        
      const artist = song.artists?.map(a => a.name).join(', ') || 'Unknown Artist';

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

    // Extract direct audio stream URL using ytdl-core
    const ytUrl = `https://www.youtube.com/watch?v=${videoId}`;
    const info = await ytdl.getInfo(ytUrl);
    
    // Choose the best audio format
    const audioFormats = ytdl.filterFormats(info.formats, 'audioonly');
    if (audioFormats.length === 0) {
      return res.status(404).json({ error: 'No audio streams found for this song' });
    }
    
    // Sort by highest bitrate
    audioFormats.sort((a, b) => (b.audioBitrate || 0) - (a.audioBitrate || 0));
    const bestFormat = audioFormats[0];

    // Get exact duration from ytdl info (in seconds)
    const duration = parseInt(info.videoDetails.lengthSeconds || '0', 10);

    res.json({ 
      streamUrl: bestFormat.url, 
      duration: duration
    });
  } catch (error) {
    console.error('Stream error:', error);
    res.status(500).json({ error: 'Failed to get stream URL' });
  }
});

module.exports = router;
