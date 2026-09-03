/**
 * importRoutes.js
 * ===============
 * REST API endpoints for the Universal Music Library Import system.
 *
 * All routes require authentication (requireAuth middleware).
 * Provider OAuth callbacks use a stateless CSRF state token.
 *
 * Route map:
 *   GET  /providers               → List available providers
 *   POST /:provider/start         → Start import job
 *
 *   GET  /oauth/:provider         → Initiate OAuth (returns auth URL)
 *   GET  /oauth/:provider/callback → OAuth callback handler
 *
 *   GET  /jobs/:jobId             → Poll job status
 *   POST /jobs/:jobId/cancel      → Cancel a running job
 *   GET  /jobs/:jobId/review      → Get REVIEW_REQUIRED tracks
 *   POST /jobs/:jobId/review      → Submit user match selections
 *   GET  /history                 → List user's past import jobs
 *
 *   POST /file/:provider/history  → Upload listening history file
 *
 *   GET  /services                → List connected providers
 *   DELETE /services/:provider    → Disconnect provider
 */

const express = require('express');
const crypto  = require('crypto');
const requireAuth = require('../middleware/requireAuth');
const User    = require('../models/User');
const ImportJob = require('../models/ImportJob');
const ImportedTrack = require('../models/ImportedTrack');
const ImportWorker = require('../services/ImportWorker');
const SpotifyImporter = require('../services/importers/SpotifyImporter');
const YouTubeImporter = require('../services/importers/YouTubeImporter');
const { encryptToken, decryptToken } = require('../utils/crypto');

const router = express.Router();

// ─── OAuth Callback (Unprotected - called by Google/Spotify redirect) ───────
router.get('/oauth/:provider/callback', async (req, res) => {
  const { provider } = req.params;
  const { code, state, error } = req.query;

  // Handle user cancellation
  if (error) {
    return res.redirect(`amplify://import?status=cancelled&provider=${provider}&error=${encodeURIComponent(error)}`);
  }

  const ImporterClass = getImporterClass(provider);
  if (!ImporterClass) {
    return res.status(400).json({ message: `Unknown provider: ${provider}` });
  }

  try {
    // Decode and validate state
    const stateData = JSON.parse(Buffer.from(state, 'base64url').toString());
    const userId = stateData.userId;

    // Exchange code for tokens
    const { accessToken, refreshToken, expiresIn, scope } = await ImporterClass.exchangeCode(code);

    // Authenticate with the provider to get profile info
    const importer = new ImporterClass(accessToken);
    const profile = await importer.authenticate();

    // Encrypt tokens before storing
    const encryptedAccess  = encryptToken(accessToken);
    const encryptedRefresh = refreshToken ? encryptToken(refreshToken) : undefined;
    const expiresAt = new Date(Date.now() + expiresIn * 1000);

    // Upsert connected service
    const user = await User.findById(userId);
    const existingIdx = user.connectedServices.findIndex(s => s.provider === provider);

    const serviceData = {
      provider,
      accessToken: encryptedAccess,
      refreshToken: encryptedRefresh || user.connectedServices[existingIdx]?.refreshToken,
      expiresAt,
      scope,
      providerUserId: profile.userId,
      displayName: profile.displayName,
      connectedAt: new Date(),
    };

    if (existingIdx >= 0) {
      user.connectedServices[existingIdx] = serviceData;
    } else {
      user.connectedServices.push(serviceData);
    }
    await user.save();

    // Redirect back to the app with a success deeplink
    return res.redirect(`amplify://import?status=connected&provider=${provider}&displayName=${encodeURIComponent(profile.displayName)}`);

  } catch (err) {
    console.error(`[Import] OAuth callback error for ${provider}:`, err.message);
    return res.redirect(`amplify://import?status=error&provider=${provider}&error=${encodeURIComponent(err.message)}`);
  }
});

// ─── Protected Routes Below ──────────────────────────────────────────────────
router.use(requireAuth);

// ─── Helpers ─────────────────────────────────────────────────────────────────

function getImporterClass(provider) {
  if (provider === 'spotify') return SpotifyImporter;
  if (provider === 'youtube') return YouTubeImporter;
  return null;
}

async function getUserService(userId, provider) {
  const user = await User.findById(userId).select('connectedServices').lean();
  return user?.connectedServices?.find(s => s.provider === provider) || null;
}

async function getDecryptedToken(userId, provider) {
  const service = await getUserService(userId, provider);
  if (!service) return null;

  // Check if token is expired; attempt refresh
  if (service.expiresAt && new Date(service.expiresAt) < new Date()) {
    const ImporterClass = getImporterClass(provider);
    if (!ImporterClass || !service.refreshToken) return null;

    const decryptedRefresh = decryptToken(service.refreshToken);
    try {
      const { accessToken, expiresIn } = await ImporterClass.refreshToken(decryptedRefresh);
      const encryptedNew = encryptToken(accessToken);
      const expiresAt = new Date(Date.now() + expiresIn * 1000);

      await User.updateOne(
        { _id: userId, 'connectedServices.provider': provider },
        { $set: { 'connectedServices.$.accessToken': encryptedNew, 'connectedServices.$.expiresAt': expiresAt } }
      );

      return accessToken;
    } catch (err) {
      return null; // Token refresh failed
    }
  }

  return decryptToken(service.accessToken);
}

// ─── Available Providers ────────────────────────────────────────────────────

router.get('/providers', (req, res) => {
  res.json([
    {
      id: 'spotify',
      name: 'Spotify',
      description: 'Import playlists, saved library, and listening history from Spotify.',
      features: ['playlists', 'library', 'recent_history', 'file_history'],
      configured: !!(process.env.SPOTIFY_CLIENT_ID && process.env.SPOTIFY_CLIENT_SECRET),
    },
    {
      id: 'youtube',
      name: 'YouTube Music',
      description: 'Import YouTube playlists and liked videos. History available via Takeout export.',
      features: ['playlists', 'liked_videos', 'file_history'],
      configured: !!(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET),
      limitation: 'YouTube Music does not have a dedicated API. Only YouTube playlists are accessible.',
    },
  ]);
});

// ─── OAuth Flow ──────────────────────────────────────────────────────────────

router.get('/oauth/:provider', (req, res) => {
  const { provider } = req.params;
  const ImporterClass = getImporterClass(provider);

  if (!ImporterClass) {
    return res.status(400).json({ message: `Unknown provider: ${provider}` });
  }

  // Generate CSRF state token: userId + random bytes
  const state = Buffer.from(JSON.stringify({
    userId: req.userId,
    nonce: crypto.randomBytes(16).toString('hex'),
  })).toString('base64url');

  const authUrl = ImporterClass.buildAuthUrl(state);
  res.json({ authUrl, state });
});



// ─── Import Job Management ───────────────────────────────────────────────────

router.post('/:provider/start', async (req, res) => {
  const { provider } = req.params;
  const ImporterClass = getImporterClass(provider);

  if (!ImporterClass) {
    return res.status(400).json({ message: `Unknown provider: ${provider}` });
  }

  const accessToken = await getDecryptedToken(req.userId, provider);
  if (!accessToken) {
    return res.status(401).json({
      message: `${provider} is not connected or token expired. Please reconnect.`,
      code: 'NOT_CONNECTED',
    });
  }

  try {
    const importer = new ImporterClass(accessToken);
    const job = await ImportJob.create({
      userId: req.userId,
      provider,
      status: 'QUEUED',
    });

    // Fire and forget — process asynchronously
    setImmediate(() => {
      ImportWorker.run(job._id.toString(), importer)
        .catch(err => console.error('[Import] Worker error:', err.message));
    });

    res.status(202).json({
      importJobId: job._id,
      status: 'QUEUED',
      message: 'Import started. Poll /api/import/jobs/:id for progress.',
    });
  } catch (err) {
    console.error(`[Import] Failed to start import for ${provider}:`, err.message);
    res.status(500).json({ message: 'Failed to start import job.' });
  }
});

router.get('/jobs/:jobId', async (req, res) => {
  try {
    const job = await ImportJob.findOne({
      _id: req.params.jobId,
      userId: req.userId,
    }).lean();

    if (!job) {
      return res.status(404).json({ message: 'Import job not found.' });
    }

    res.json(job);
  } catch (err) {
    res.status(500).json({ message: 'Failed to fetch job status.' });
  }
});

router.post('/jobs/:jobId/cancel', async (req, res) => {
  try {
    const result = await ImportJob.updateOne(
      { _id: req.params.jobId, userId: req.userId, status: { $nin: ['COMPLETED', 'FAILED', 'CANCELLED'] } },
      { $set: { status: 'CANCELLED', completedAt: new Date() } }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'Job not found or already completed.' });
    }

    res.json({ message: 'Import cancelled.' });
  } catch (err) {
    res.status(500).json({ message: 'Failed to cancel job.' });
  }
});

// ─── Review ──────────────────────────────────────────────────────────────────

router.get('/jobs/:jobId/review', async (req, res) => {
  try {
    const page = parseInt(req.query.page || '1', 10);
    const limit = 20;

    const tracks = await ImportedTrack.find({
      importJobId: req.params.jobId,
      userId: req.userId,
      matchStatus: 'REVIEW_REQUIRED',
      userReviewed: false,
    })
    .skip((page - 1) * limit)
    .limit(limit)
    .lean();

    const total = await ImportedTrack.countDocuments({
      importJobId: req.params.jobId,
      userId: req.userId,
      matchStatus: 'REVIEW_REQUIRED',
      userReviewed: false,
    });

    res.json({ tracks, total, page, pages: Math.ceil(total / limit) });
  } catch (err) {
    res.status(500).json({ message: 'Failed to fetch review tracks.' });
  }
});

router.post('/jobs/:jobId/review', async (req, res) => {
  /**
   * Body: { reviews: [{ importedTrackId, selectedVideoId }] }
   * selectedVideoId: null = skip (mark unavailable)
   */
  try {
    const { reviews } = req.body;
    if (!Array.isArray(reviews)) {
      return res.status(400).json({ message: 'reviews must be an array.' });
    }

    const ops = reviews.map(r => ({
      updateOne: {
        filter: {
          _id: r.importedTrackId,
          importJobId: req.params.jobId,
          userId: req.userId,
        },
        update: {
          $set: {
            userReviewed: true,
            userSelection: r.selectedVideoId || null,
            amplifyVideoId: r.selectedVideoId || null,
            matchStatus: r.selectedVideoId ? 'MATCHED' : 'UNAVAILABLE',
          },
        },
      },
    }));

    await ImportedTrack.bulkWrite(ops);
    res.json({ message: `${reviews.length} tracks reviewed.` });
  } catch (err) {
    res.status(500).json({ message: 'Failed to submit reviews.' });
  }
});

// ─── Import History ──────────────────────────────────────────────────────────

router.get('/history', async (req, res) => {
  try {
    const jobs = await ImportJob.find({ userId: req.userId })
      .sort({ startedAt: -1 })
      .limit(10)
      .lean();

    res.json(jobs);
  } catch (err) {
    res.status(500).json({ message: 'Failed to fetch import history.' });
  }
});

// ─── File Import (Listening History) ─────────────────────────────────────────

router.post('/file/:provider/history', async (req, res) => {
  const { provider } = req.params;
  const ImporterClass = getImporterClass(provider);

  if (!ImporterClass) {
    return res.status(400).json({ message: `Unknown provider: ${provider}` });
  }

  try {
    const fileData = req.body.fileContent; // base64-encoded JSON
    if (!fileData) {
      return res.status(400).json({ message: 'fileContent (base64 JSON) is required.' });
    }

    const buffer = Buffer.from(fileData, 'base64');
    const importer = new ImporterClass(null); // No token needed for file parsing
    const events = await importer.parseHistoryFile(buffer);

    const sourceType = `${provider}_import`;
    await ImportWorker.writeHistoryFileEvents(req.userId, events, sourceType);

    res.json({
      message: `Imported ${events.length} listening history records from ${provider}.`,
      count: events.length,
    });
  } catch (err) {
    console.error('[Import] File history error:', err.message);
    res.status(400).json({ message: err.message || 'Failed to parse history file.' });
  }
});

// ─── Connected Services ───────────────────────────────────────────────────────

router.get('/services', async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('connectedServices').lean();
    const services = (user?.connectedServices || []).map(s => ({
      provider:      s.provider,
      displayName:   s.displayName,
      connectedAt:   s.connectedAt,
      expiresAt:     s.expiresAt,
    }));
    res.json(services);
  } catch (err) {
    res.status(500).json({ message: 'Failed to fetch connected services.' });
  }
});

router.delete('/services/:provider', async (req, res) => {
  const { provider } = req.params;
  try {
    // Attempt to revoke the token on the provider's side
    const accessToken = await getDecryptedToken(req.userId, provider);
    if (accessToken) {
      const ImporterClass = getImporterClass(provider);
      if (ImporterClass) {
        const importer = new ImporterClass(accessToken);
        await importer.revokeToken(accessToken).catch(() => {}); // best-effort
      }
    }

    // Remove from User document
    await User.updateOne(
      { _id: req.userId },
      { $pull: { connectedServices: { provider } } }
    );

    res.json({ message: `${provider} disconnected. Imported playlists and library data are preserved.` });
  } catch (err) {
    res.status(500).json({ message: 'Failed to disconnect provider.' });
  }
});

module.exports = router;
