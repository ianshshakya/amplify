const test = require('node:test');
const assert = require('node:assert/strict');
const { SectionRanker, diversityFilter } = require('../src/services/HomeFeedEngine');

test('section ranker omits empty candidates and preserves strongest unique sections', () => {
  const ranked = SectionRanker.select([
    { type: 'TRENDING', score: 20 },
    { type: 'QUICK_PICKS', score: 100 },
    { type: 'TRENDING', score: 80 },
    { type: 'BECAUSE_YOU_LISTEN', score: 0 },
  ]);
  assert.deepEqual(ranked.map(section => section.type), ['QUICK_PICKS', 'TRENDING']);
});

test('diversity filter removes duplicate tracks and caps repeated artists softly', () => {
  const track = (id, artist) => ({ id, type: 'SONG', subtitle: artist, track: { videoId: id, artist } });
  const result = diversityFilter(
    [track('one', 'Artist A'), track('two', 'Artist A'), track('three', 'Artist A'), track('one', 'Artist A'), track('four', 'Artist B')],
    new Set(), new Map(),
  );
  assert.deepEqual(result.map(item => item.id), ['one', 'two', 'four']);
});
