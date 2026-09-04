require('dotenv').config();
const mongoose = require('mongoose');

async function testVideo() {
  await mongoose.connect(process.env.MONGO_URI);
  const User = require('./src/models/User');
  const { decryptToken } = require('./src/utils/crypto');
  
  const user = await User.findOne({ 'connectedServices.provider': 'youtube' });
  const ytService = user.connectedServices.find(s => s.provider === 'youtube');
  const accessToken = decryptToken(ytService.accessToken);
  
  const url = 'https://youtube.googleapis.com/youtube/v3/videos?part=snippet,contentDetails,topicDetails&id=MJyKN-8UncM';
  const res = await fetch(url, {
    headers: { 'Authorization': `Bearer ${accessToken}` }
  });
  
  const data = await res.json();
  console.log(JSON.stringify(data.items[0], null, 2));
  mongoose.disconnect();
}

testVideo().catch(console.error);
