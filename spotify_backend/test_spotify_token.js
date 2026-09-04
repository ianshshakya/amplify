require('dotenv').config();
const axios = require('axios');

async function testSpotifyToken() {
  const params = new URLSearchParams({
    grant_type: 'authorization_code',
    code: 'fake_code_123',
    redirect_uri: process.env.SPOTIFY_REDIRECT_URI,
  });

  const credentials = Buffer.from(
    `${process.env.SPOTIFY_CLIENT_ID}:${process.env.SPOTIFY_CLIENT_SECRET}`
  ).toString('base64');

  try {
    const res = await axios.post('https://accounts.spotify.com/api/token', params.toString(), {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': `Basic ${credentials}`,
      },
    });
    console.log(res.data);
  } catch (err) {
    console.error('Error status:', err.response?.status);
    console.error('Error data:', err.response?.data);
  }
}

testSpotifyToken();
