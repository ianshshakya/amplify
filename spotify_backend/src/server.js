require('dotenv').config();
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const connectDB = require('./config/db');

const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const playlistRoutes = require('./routes/playlistRoutes');
const musicRoutes = require('./routes/musicRoutes');
const homeRoutes = require('./routes/homeRoutes');
const analyticsRoutes = require('./routes/analyticsRoutes');
const recommendationRoutes = require('./routes/recommendationRoutes');
const appRoutes = require('./routes/appRoutes');

const app = express();
app.set('trust proxy', 1);

app.use(cors());
app.use(express.json());

// Basic protection against brute-force login/register attempts.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  message: { message: 'Too many attempts, please try again later.' },
});

// Protect heavy generation routes from abuse
const apiLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 40, // max 40 requests per minute
  message: { message: 'Rate limit exceeded, please slow down.' },
});

app.use('/api/auth', authLimiter, authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/playlists', apiLimiter, playlistRoutes);
app.use('/api/music', musicRoutes);
app.use('/api/home', homeRoutes);
app.use('/api/analytics', analyticsRoutes);
app.use('/api/recommendations', apiLimiter, recommendationRoutes);
app.use('/api/app', appRoutes);

app.get('/api/health', (req, res) => res.json({ status: 'ok' }));

// Fallback error handler so unexpected errors don't crash the process
// or leak stack traces to the client.
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ message: 'Internal server error' });
});

const PORT = process.env.PORT || 5000;
const HOST = process.env.HOST || '0.0.0.0';

async function startServer() {
  await connectDB();

  app.listen(PORT, HOST, () => console.log(`Server running on http://${HOST}:${PORT}`));
}

startServer();
