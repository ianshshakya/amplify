/**
 * End-to-end dry-run: simulates exactly what TrackMatcher.match() now does.
 */
require('dotenv').config();
const mongoose = require('mongoose');

async function run() {
  await mongoose.connect(process.env.MONGO_URI);

  const TrackMatcher = require('./src/services/TrackMatcher');

  const simulatedYouTubeTracks = [
    {
      sourceTrackId: 'MJyKN-8UncM',
      title: 'Shayad - Love Aaj Kal | Kartik | Sara | Arushi | Pritam | Arijit Singh',
      artist: 'Sony Music India',
      artists: ['Sony Music India'],
      album: null,
      isrc: null,
      durationMs: 247000,
      thumbnailUrl: '',
      sourceUrl: 'https://www.youtube.com/watch?v=MJyKN-8UncM',
      playlistIds: ['LL'],
      source: 'youtube',
    }
  ];

  console.log('=== Running FIXED TrackMatcher on simulated YouTube track ===\n');

  const { results } = await TrackMatcher.matchBatch(simulatedYouTubeTracks);

  for (const r of results) {
    console.log(`Track:    "${r.track.title}" by "${r.track.artist}"`);
    console.log(`Status:   ${r.matchStatus}`);
    console.log(`Score:    ${r.confidenceScore}`);
    if (r.reviewCandidates?.length > 0) {
      console.log(`Top Candidate: "${r.reviewCandidates[0].title}" by "${r.reviewCandidates[0].artist}" (Score: ${r.reviewCandidates[0].confidenceScore})`);
    } else {
      console.log(`No review candidates returned.`);
    }
    if (r.amplifyVideoId) {
      console.log(`✅ Matched VideoID: ${r.amplifyVideoId}`);
    } else {
      console.log(`❌ Not matched`);
    }
  }

  mongoose.disconnect();
}

run().catch(console.error);
