/**
 * test_intelligence.js
 * ====================
 * Quick test script to validate the Amplify Music Intelligence Layer.
 * Tests each playlist type, prints candidate counts, fallback levels,
 * final song counts, and the first 5 song titles.
 *
 * Usage: node test_intelligence.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const PlaylistIntelligence = require('./src/services/PlaylistIntelligence');
const CURATED_PLAYLISTS = require('./src/config/playlists');

const testCases = CURATED_PLAYLISTS.map(p => ({ id: p.id, config: p }));

async function runTest(testCase) {
  const { id, config } = testCase;
  const start = Date.now();
  
  try {
    const result = await PlaylistIntelligence.generate(config, null, {
      targetCount: 25,
      debugMode: false,
      forceRefresh: true,
    });

    const elapsed = ((Date.now() - start) / 1000).toFixed(1);
    const songs = result.songs || [];
    const meta = result.meta || {};

    const status = songs.length >= (config.intent && config.intent.purpose === 'charts' ? 20 : 10)
      ? '✅' : songs.length > 0 ? '⚠️' : '❌';

    console.log(`\n${status} [${id}] "${config.title}"`);
    console.log(`   Songs: ${songs.length} | Candidates: ${meta.candidateCount || '?'} | Validation: ${meta.validationScore || '?'}/100 | Time: ${elapsed}s`);
    if (meta.fallbackLevel > 0) {
      console.log(`   Fallback: Level ${meta.fallbackLevel} — ${meta.fallbackReason}`);
    }
    if (meta.validationIssues && meta.validationIssues.length > 0) {
      console.log(`   Issues: ${meta.validationIssues.join('; ')}`);
    }
    if (meta.validationWarnings && meta.validationWarnings.length > 0) {
      console.log(`   Warnings: ${meta.validationWarnings.join('; ')}`);
    }
    if (songs.length > 0) {
      console.log(`   Top songs:`);
      songs.slice(0, 5).forEach((s, i) => {
        console.log(`     ${i + 1}. ${s.title} — ${s.artist} (pop: ${songs[i]._debug ? Math.round(songs[i]._debug.popularity) : '?'})`);
      });
    }

    return { id, songCount: songs.length, passed: songs.length >= 10 };
  } catch (err) {
    console.log(`\n❌ [${id}] FAILED: ${err.message}`);
    return { id, songCount: 0, passed: false };
  }
}

async function main() {
  console.log('=== Amplify Intelligence Test ===\n');
  await mongoose.connect(process.env.MONGO_URI);
  console.log('MongoDB connected.\n');
  console.log(`Testing ${testCases.length} playlists...\n`);

  const results = [];
  for (const tc of testCases) {
    const result = await runTest(tc);
    results.push(result);
  }

  console.log('\n\n=== SUMMARY ===');
  const passed = results.filter(r => r.passed).length;
  const failed = results.filter(r => !r.passed);
  console.log(`Passed: ${passed}/${results.length}`);
  if (failed.length > 0) {
    console.log(`Failed: ${failed.map(r => r.id).join(', ')}`);
  }

  await mongoose.disconnect();
  process.exit(failed.length > 0 ? 1 : 0);
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
