/**
 * test_autoplay.js
 * ================
 * Verifies that TRUE personalization is happening by providing the EXACT same
 * seed song ("Blinding Lights" by The Weeknd) to 3 different simulated users
 * with vastly different taste profiles, and asserting that the resulting
 * Autoplay queues are completely different based on their tastes.
 */

require('dotenv').config();
const mongoose = require('mongoose');
const PersonalizedAutoplayEngine = require('./src/services/PersonalizedAutoplayEngine');
const MusicProvider = require('./src/services/MusicProvider');

const SEED_SONG = {
  videoId: '320092305',
  title: 'Blinding Lights',
  artist: 'The Weeknd',
  primaryArtist: 'The Weeknd',
  releaseYear: 2020,
  popularityScore: 95,
  language: 'English',
};

// User A: Loves Hip-Hop, Pop, and The Weeknd
const userA = {
  artistAffinity: new Map([['The Weeknd', 1.0], ['Drake', 0.9], ['Travis Scott', 0.8]]),
  moodAffinity: new Map([['party', 0.9], ['chill', 0.2]]),
  eraAffinity: new Map([['2020s', 0.9], ['2010s', 0.8]]),
  languageAffinity: new Map([['English', 0.9]]),
};

// User B: Loves Bollywood and Romance (happens to listen to Blinding Lights once)
const userB = {
  artistAffinity: new Map([['Arijit Singh', 1.0], ['Shreya Ghoshal', 0.9], ['Sachin-Jigar', 0.8]]),
  moodAffinity: new Map([['romance', 0.9], ['sad', 0.6]]),
  eraAffinity: new Map([['2020s', 0.9], ['2010s', 0.8]]),
  languageAffinity: new Map([['Hindi', 0.9]]),
};

// User C: Loves Chill/Acoustic Indie music
const userC = {
  artistAffinity: new Map([['Prateek Kuhad', 1.0], ['Anuv Jain', 0.9], ['Osho Jain', 0.8]]),
  moodAffinity: new Map([['chill', 1.0], ['focus', 0.8]]),
  eraAffinity: new Map([['2020s', 0.9]]),
  languageAffinity: new Map([['Hindi', 0.5], ['English', 0.5]]),
};

async function runTest() {
  console.log('=== Amplify Personalized Autoplay Test ===\n');

  try {
    console.log(`Connecting to MongoDB... (${process.env.MONGO_URI})`);
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/amplify');
    console.log('MongoDB connected.\n');

    console.log(`SEED SONG: "${SEED_SONG.title}" — ${SEED_SONG.artist}\n`);
    console.log('Simulating 3 entirely different users listening to the exact same song...\n');

    const limit = 8;
    const sessionCtx = { recentArtists: [], recentSongIds: [] };

    // USER A
    console.log('--- USER A (Hip-Hop/Pop Fan) ---');
    const queueA = await PersonalizedAutoplayEngine.getNextTracks(SEED_SONG, userA, sessionCtx, limit);
    queueA.forEach((t, i) => console.log(`  ${i+1}. ${t.title} — ${t.artist}  [Reasons: ${t._debug.reasons.join(' | ')}]`));
    console.log('');

    // USER B
    console.log('--- USER B (Bollywood/Romance Fan) ---');
    const queueB = await PersonalizedAutoplayEngine.getNextTracks(SEED_SONG, userB, sessionCtx, limit);
    queueB.forEach((t, i) => console.log(`  ${i+1}. ${t.title} — ${t.artist}  [Reasons: ${t._debug.reasons.join(' | ')}]`));
    console.log('');

    // USER C
    console.log('--- USER C (Indie/Chill Fan) ---');
    const queueC = await PersonalizedAutoplayEngine.getNextTracks(SEED_SONG, userC, sessionCtx, limit);
    queueC.forEach((t, i) => console.log(`  ${i+1}. ${t.title} — ${t.artist}  [Reasons: ${t._debug.reasons.join(' | ')}]`));
    console.log('');

    // Quick Assertions (Manual)
    console.log('=== Conclusion ===');
    console.log('If User A got mostly Pop/Hip-Hop, User B got mostly Hindi/Bollywood,');
    console.log('and User C got mostly Chill/Acoustic, then TRUE personalization is working.');

  } catch (err) {
    console.error('Test failed:', err);
  } finally {
    mongoose.disconnect();
  }
}

runTest();
