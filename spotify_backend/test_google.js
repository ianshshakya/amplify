require('dotenv').config();
const axios = require('axios');

async function testCredentials() {
  console.log('Testing Google Credentials...');
  
  if (!process.env.GOOGLE_CLIENT_ID || !process.env.GOOGLE_CLIENT_SECRET) {
    console.error('❌ GOOGLE_CLIENT_ID or GOOGLE_CLIENT_SECRET is missing from .env');
    process.exit(1);
  } else {
    console.log('✅ GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET are present');
  }

  if (!process.env.GOOGLE_API_KEY) {
    console.error('❌ GOOGLE_API_KEY is missing from .env');
    process.exit(1);
  }

  console.log('Testing GOOGLE_API_KEY against YouTube Data API...');
  try {
    const response = await axios.get(`https://www.googleapis.com/youtube/v3/search`, {
      params: {
        part: 'snippet',
        q: 'Never Gonna Give You Up',
        maxResults: 1,
        key: process.env.GOOGLE_API_KEY
      }
    });

    if (response.data && response.data.items) {
      console.log('✅ GOOGLE_API_KEY is valid! Successfully fetched data from YouTube.');
    } else {
      console.log('⚠️ GOOGLE_API_KEY was accepted but returned unexpected data.');
    }
  } catch (error) {
    console.error('❌ Failed to verify GOOGLE_API_KEY.');
    if (error.response) {
      console.error(`Status: ${error.response.status}`);
      console.error(JSON.stringify(error.response.data, null, 2));
    } else {
      console.error(error.message);
    }
    process.exit(1);
  }
}

testCredentials();
