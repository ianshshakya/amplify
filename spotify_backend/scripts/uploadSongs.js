require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const mm = require('music-metadata');
const mongoose = require('mongoose');

// Import DB config and Model
const connectDB = require('../src/config/db');
const CreatorSong = require('../src/models/CreatorSong');

// Removed S3Client - we will use native fetch for better Archive.org compatibility

const BUCKET_NAME = process.env.ARCHIVE_BUCKET_NAME; // e.g., 'ansh-creator-music-2026'
const SONGS_DIR = path.join(__dirname, '../my_songs');

async function processAndUploadSongs() {
  if (!process.env.ARCHIVE_ACCESS_KEY || !process.env.ARCHIVE_SECRET_KEY || !BUCKET_NAME) {
    console.error("Missing Archive.org credentials or bucket name in .env");
    process.exit(1);
  }

  await connectDB();
  console.log(`Connected to DB. Starting upload pipeline to Archive.org Item: ${BUCKET_NAME}...`);

  if (!fs.existsSync(SONGS_DIR)) {
    console.error(`Folder not found: ${SONGS_DIR}`);
    process.exit(1);
  }

  const files = fs.readdirSync(SONGS_DIR);
  
  for (const file of files) {
    if (!file.endsWith('.mp3') && !file.endsWith('.m4a') && !file.endsWith('.wav')) {
      continue;
    }

    const filePath = path.join(SONGS_DIR, file);
    console.log(`\nProcessing: ${file}`);

    try {
      // 1. Extract Metadata
      const metadata = await mm.parseFile(filePath);
      const title = metadata.common.title || path.parse(file).name;
      const artist = metadata.common.artist || "Unknown Artist";
      const durationSeconds = metadata.format.duration || 0;
      
      console.log(` - Extracted: ${title} by ${artist} (${Math.round(durationSeconds)}s)`);

      // 2. Upload to Archive.org via native fetch
      console.log(` - Uploading to Archive.org...`);
      const fileBuffer = fs.readFileSync(filePath);
      
      const uploadUrl = `https://s3.us.archive.org/${BUCKET_NAME}/${encodeURIComponent(file)}`;
      
      const response = await fetch(uploadUrl, {
        method: 'PUT',
        headers: {
          'Authorization': `LOW ${process.env.ARCHIVE_ACCESS_KEY}:${process.env.ARCHIVE_SECRET_KEY}`,
          'x-amz-auto-make-bucket': '1',
          'Content-Type': 'audio/mpeg'
        },
        body: fileBuffer
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Archive HTTP Error ${response.status}: ${errorText}`);
      }
      
      console.log(` - Upload successful!`);

      // 3. Save to MongoDB
      // Archive.org direct link format: https://archive.org/download/{bucket-name}/{filename}
      const streamUrl = `https://archive.org/download/${BUCKET_NAME}/${encodeURIComponent(file)}`;
      
      // Use the filename as a unique videoId for the flutter app to track
      const videoId = `creator_${file.replace(/[^a-zA-Z0-9]/g, '')}`;

      await CreatorSong.findOneAndUpdate(
        { videoId: videoId },
        {
          title: title,
          artist: artist,
          streamUrl: streamUrl,
          duration: Math.round(durationSeconds),
          // thumbnailUrl: 'DEFAULT_COVER_URL' // You can add custom cover art logic here
        },
        { upsert: true, new: true }
      );
      
      console.log(` - Saved to database!`);

      // Add a 2 second delay to prevent Archive.org from rate-limiting/blocking us
      await new Promise(r => setTimeout(r, 2000));

    } catch (err) {
      console.error(` - Error processing ${file}:`, err.message);
      if (err.$response && err.$response.body) {
        // Try to read the raw HTML response stream
        try {
          const chunks = [];
          for await (let chunk of err.$response.body) {
            chunks.push(chunk);
          }
          const rawHtml = Buffer.concat(chunks).toString('utf8');
          console.error(`\nRAW ARCHIVE.ORG ERROR:`);
          console.error(rawHtml);
        } catch (e) {
          console.error('Could not parse raw response body.');
        }
      }
    }
  }

  console.log("\nPipeline finished!");
  mongoose.disconnect();
}

processAndUploadSongs();
