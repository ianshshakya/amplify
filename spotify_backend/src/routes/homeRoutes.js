const express = require('express');
const saavn = require('saavnapi').default;

const router = express.Router();

router.get('/', async (req, res) => {
  try {
    // Define the curated categories
    const categories = [
      { title: 'Top 50 India', query: 'Top 50 India' },
      { title: 'Bollywood Chartbusters', query: 'Bollywood Hits' },
      { title: 'Best of Arijit Singh', query: 'Arijit Singh' },
      { title: 'Trending Punjabi Hits', query: 'Punjabi Hits' }
    ];

    // Fetch all categories in parallel
    const promises = categories.map(async (cat) => {
      const response = await saavn.search.searchSongs({ query: cat.query, page: 1, limit: 10 });
      const songs = response.results || [];

      // Map JioSaavn results to our expected format
      const results = songs.map(song => {
        const thumbnail = song.image?.find(img => img.quality === '500x500')?.url 
                       || (song.image && song.image.length > 0 ? song.image[song.image.length - 1].url : '');
        const artist = song.artists?.primary?.map(a => a.name).join(', ') || 'Unknown Artist';

        return {
          videoId: song.id,
          title: song.name || song.title,
          artist: artist,
          thumbnailUrl: thumbnail,
          duration: song.duration,
        };
      });

      return {
        title: cat.title,
        songs: results
      };
    });

    const homeFeed = await Promise.all(promises);

    res.json(homeFeed);
  } catch (error) {
    console.error('Error fetching home feed:', error);
    res.status(500).json({ error: 'Failed to fetch home feed' });
  }
});

module.exports = router;
