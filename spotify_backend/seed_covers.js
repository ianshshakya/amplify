const mongoose = require('mongoose');
const PlaylistIntelligence = require('./src/services/PlaylistIntelligence');
const DynamicPlaylist = require('./src/models/DynamicPlaylist');
const CURATED_PLAYLISTS = require('./src/config/playlists');
require('dotenv').config();

async function seedCovers() {
  await mongoose.connect(process.env.MONGO_URI);
  console.log('Connected to MongoDB');

  for (const config of CURATED_PLAYLISTS) {
    try {
      const dbPlaylist = await DynamicPlaylist.findOne({ playlistId: config.id });
      // We check if it has a generic saavncdn URL that we know is a fallback.
      // Or just if songs array is empty.
      if (!dbPlaylist || !dbPlaylist.songs || dbPlaylist.songs.length === 0) {
        console.log(`Generating playlist ${config.id}...`);
        const result = await PlaylistIntelligence.generate(config, null, { targetCount: 15, forceRefresh: true });
        
        if (result.songs && result.songs.length > 0) {
          const firstThumb = result.songs[0].thumbnailUrl;
          await DynamicPlaylist.findOneAndUpdate(
            { playlistId: config.id },
            {
              title: config.title,
              description: config.description,
              thumbnailUrl: firstThumb,
              songs: result.songs,
              updatedAt: new Date(),
            },
            { upsert: true }
          );
          console.log(`Saved thumbnail ${firstThumb} for ${config.id}`);
        } else {
          console.log(`Failed to get songs for ${config.id}`);
        }
      } else {
        console.log(`Playlist ${config.id} already has ${dbPlaylist.songs.length} songs. Thumb: ${dbPlaylist.thumbnailUrl}`);
      }
    } catch (err) {
      console.error(`Error with ${config.id}:`, err.message);
    }
  }

  console.log('Done.');
  process.exit(0);
}

seedCovers();
