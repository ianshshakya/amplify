require('dotenv').config();
const mongoose = require('mongoose');

async function checkImportStats() {
  await mongoose.connect(process.env.MONGO_URI);
  
  const ImportJob = require('./src/models/ImportJob');
  const ImportedTrack = require('./src/models/ImportedTrack');
  const User = require('./src/models/User');
  
  const latestJob = await ImportJob.findOne().sort({ createdAt: -1 });
  console.log('Latest Job:', {
    status: latestJob.status,
    totalItems: latestJob.totalItems,
    matchedItems: latestJob.matchedItems,
    reviewItems: latestJob.reviewItems,
    unavailableItems: latestJob.unavailableItems,
  });
  
  const unavail = await ImportedTrack.find({ importJobId: latestJob._id, matchStatus: 'UNAVAILABLE' }).limit(5);
  console.log('\nSample UNAVAILABLE tracks:');
  unavail.forEach(t => console.log(`- ${t.title} by ${t.artist}`));

  const review = await ImportedTrack.find({ importJobId: latestJob._id, matchStatus: 'REVIEW_REQUIRED' }).limit(5);
  console.log('\nSample REVIEW_REQUIRED tracks:');
  review.forEach(t => console.log(`- ${t.title} by ${t.artist}`));

  mongoose.disconnect();
}

checkImportStats().catch(console.error);
