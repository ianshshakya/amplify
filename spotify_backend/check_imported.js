require('dotenv').config();
const mongoose = require('mongoose');
const ImportedTrack = require('./src/models/ImportedTrack');

async function run() {
  await mongoose.connect(process.env.MONGO_URI);
  
  const User = require('./src/models/User');
  
  const result = await User.updateMany(
    {},
    { $pull: { likedSongs: { title: { $in: [null, undefined] } } } }
  );
  
  console.log(`Cleaned up corrupted liked songs. Modified ${result.modifiedCount} users.`);
  
  mongoose.disconnect();
}

run().catch(console.error);
