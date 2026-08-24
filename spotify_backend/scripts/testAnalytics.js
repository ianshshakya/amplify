require('dotenv').config();
const mongoose = require('mongoose');
const AnalyticsService = require('../src/services/AnalyticsService');
const SongStatistic = require('../src/models/SongStatistic');
const ListeningEvent = require('../src/models/ListeningEvent');

async function runTest() {
  console.log('Connecting to MongoDB...');
  await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/spotify_clone');
  console.log('Connected.');

  // Mock User ID
  const testUserId = new mongoose.Types.ObjectId();

  // Mock Song
  const mockSong = {
    videoId: 'test_song_123',
    title: 'Test Song Analytics',
    artist: 'Test Artist',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    durationMs: 200000,
    source: 'saavn'
  };

  console.log('\n--- Sending PLAY Event ---');
  await AnalyticsService.processEvent({
    song: mockSong,
    eventType: 'PLAY',
    durationPlayedMs: 5000,
    sessionId: 'session_1'
  }, testUserId);

  console.log('--- Sending COMPLETE Event ---');
  await AnalyticsService.processEvent({
    song: mockSong,
    eventType: 'COMPLETE',
    completionPercent: 100,
    sessionId: 'session_1'
  }, testUserId);

  console.log('--- Sending LIKE Event ---');
  await AnalyticsService.processEvent({
    song: mockSong,
    eventType: 'LIKE'
  }, testUserId);

  console.log('\n--- Verifying Database ---');
  
  const events = await ListeningEvent.find({ songId: 'test_song_123' });
  console.log(`Found ${events.length} listening events in DB.`);
  events.forEach(e => console.log(` - Event: ${e.eventType}`));

  const stats = await SongStatistic.findOne({ songId: 'test_song_123' });
  if (stats) {
    console.log(`\nAggregated Statistics for ${stats.songId}:`);
    console.log(` - Lifetime Plays: ${stats.lifetimePlays}`);
    console.log(` - Lifetime Completions: ${stats.lifetimeCompletions}`);
    console.log(` - Lifetime Likes: ${stats.lifetimeLikes}`);
    console.log(` - Popularity Score: ${stats.popularityScore}`); // Play(1) + Complete(2) + Like(3) = 6
  } else {
    console.log('No statistics found!');
  }

  // Cleanup
  console.log('\nCleaning up test data...');
  await ListeningEvent.deleteMany({ songId: 'test_song_123' });
  await SongStatistic.deleteMany({ songId: 'test_song_123' });
  
  await mongoose.disconnect();
  console.log('Done.');
}

runTest().catch(err => {
  console.error(err);
  process.exit(1);
});
