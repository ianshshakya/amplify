require('dotenv').config();
const mongoose = require('mongoose');
const ImportedTrack = require('./src/models/ImportedTrack');

async function run() {
  await mongoose.connect(process.env.MONGO_URI);
  
  const User = require('./src/models/User');
  const YouTubeImporter = require('./src/services/importers/YouTubeImporter');
  const TrackMatcher = require('./src/services/TrackMatcher');
  
  const users = await User.find({ 'connectedServices.provider': 'youtube' });
  if (users.length === 0) {
    console.log('No users connected to YouTube.');
    mongoose.disconnect(); return;
  }
  
  let validImporter = null;
  for (const user of users) {
    const ytService = user.connectedServices.find(s => s.provider === 'youtube');
    const importer = new YouTubeImporter(ytService.accessToken);
    try {
      await importer.authenticate(); // Check if valid
      validImporter = importer;
      console.log(`Found active YouTube connection for user ${user._id}`);
      break;
    } catch (e) {
      console.log(`Token expired for user ${user._id}`);
    }
  }
  
  if (!validImporter) {
    console.log("No valid tokens found.");
    mongoose.disconnect(); return;
  }
  
  const importer = validImporter;
  
  try {
    const { tracks } = await importer.getLibrary(null, 5);
    console.log(`Found ${tracks.length} tracks in Liked Videos:`);
    
    const { results } = await TrackMatcher.matchBatch(tracks);
    
    for (const r of results) {
      console.log(`\nOriginal: ${r.track.title} by ${r.track.artist}`);
      console.log(`Status:   ${r.matchStatus} (Score: ${r.confidenceScore})`);
      if (r.reviewCandidates && r.reviewCandidates.length > 0) {
        console.log(`Top Candidate: ${r.reviewCandidates[0].title} by ${r.reviewCandidates[0].artist} (ID: ${r.reviewCandidates[0].videoId})`);
      } else {
        console.log(`No candidates found on JioSaavn.`);
      }
    }
  } catch (err) {
    console.log("Error:", err.message);
  }
  
  mongoose.disconnect();
}

run().catch(console.error);
