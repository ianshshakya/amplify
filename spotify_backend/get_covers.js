const mongoose = require('mongoose');
const DynamicPlaylist = require('./src/models/DynamicPlaylist');
require('dotenv').config();

async function getPlaylistCovers() {
  await mongoose.connect(process.env.MONGO_URI);
  
  const playlists = await DynamicPlaylist.find();
  const results = {};
  
  for (let p of playlists) {
    if (p.songs && p.songs.length > 0) {
      results[p.playlistId] = p.songs[0].thumbnailUrl;
    }
  }
  
  console.log(JSON.stringify(results, null, 2));
  mongoose.disconnect();
}

getPlaylistCovers();
