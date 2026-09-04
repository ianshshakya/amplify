require('dotenv').config();
const mongoose = require('mongoose');

async function testFilter() {
  await mongoose.connect(process.env.MONGO_URI);
  const User = require('./src/models/User');
  const { decryptToken } = require('./src/utils/crypto');
  
  const user = await User.findOne({ 'connectedServices.provider': 'youtube' });
  const ytService = user.connectedServices.find(s => s.provider === 'youtube');
  const accessToken = decryptToken(ytService.accessToken);
  
  const testIds = [
    'MJyKN-8UncM', // Shayad (Music video)
    'jNQXAC9IVRw', // Me at the zoo (First YouTube video, non-music)
    'kJQP7kiw5Fk'  // Despacito (Music video)
  ];

  const url = `https://youtube.googleapis.com/youtube/v3/videos?part=snippet,topicDetails&id=${testIds.join(',')}`;
  
  try {
    const res = await fetch(url, { headers: { 'Authorization': `Bearer ${accessToken}` } });
    const data = await res.json();
    
    for (const item of data.items || []) {
      console.log(`\n=== ${item.snippet.title} ===`);
      console.log(`CategoryId: ${item.snippet.categoryId}`);
      console.log(`Channel: ${item.snippet.channelTitle}`);
      console.log(`Topics:`, item.topicDetails?.topicCategories || 'None');
    }
  } catch (e) {
    console.error(e);
  }
  
  mongoose.disconnect();
}

testFilter().catch(console.error);
