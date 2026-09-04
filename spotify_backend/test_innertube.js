require('dotenv').config();
const mongoose = require('mongoose');

async function testInnerTube() {
  await mongoose.connect(process.env.MONGO_URI);
  const User = require('./src/models/User');
  const { decryptToken } = require('./src/utils/crypto');
  
  // Get the most recently connected YouTube user
  const user = await User.findOne({ 'connectedServices.provider': 'youtube' });
  if (!user) {
    console.log('No youtube user found in DB.');
    process.exit(1);
  }
  
  const ytService = user.connectedServices.find(s => s.provider === 'youtube');
  const accessToken = decryptToken(ytService.accessToken);
  
  console.log('Got access token, length:', accessToken.length);
  
  // InnerTube API call
  const url = 'https://music.youtube.com/youtubei/v1/browse?prettyPrint=false';
  
  // Try to get Liked Music
  // FLL is the browseId for Liked Music in YouTube Music
  const payload = {
    context: {
      client: {
        clientName: 'WEB_REMIX',
        clientVersion: '1.20240901.01.00',
        hl: 'en',
        gl: 'US'
      }
    },
    browseId: 'FLL'
  };
  
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'Origin': 'https://music.youtube.com',
        'Referer': 'https://music.youtube.com/'
      },
      body: JSON.stringify(payload)
    });
    
    if (response.ok) {
      const data = await response.json();
      console.log('Success! InnerTube responded with data.');
      // Find the tracks array
      const items = data.contents?.twoColumnBrowseResultsRenderer?.secondaryContents?.sectionListRenderer?.contents[0]?.musicPlaylistShelfRenderer?.contents || [];
      console.log(`Found ${items.length} items in FLL playlist.`);
      if (items.length > 0) {
        const first = items[0].musicResponsiveListItemRenderer;
        const title = first?.flexColumns[0]?.musicResponsiveListItemFlexColumnRenderer?.text?.runs[0]?.text;
        console.log(`First item title: ${title}`);
      }
    } else {
      const err = await response.text();
      console.error('InnerTube HTTP Error:', response.status, err);
    }
  } catch (err) {
    console.error('Fetch error:', err.message);
  }
  
  mongoose.disconnect();
}

testInnerTube();
