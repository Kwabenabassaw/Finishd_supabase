const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

const db = admin.firestore();
const fcm = admin.messaging();

// TMDB API Key (Replace with your actual key if different, or use environment config)
const TMDB_API_KEY = "829afd9e186fc15a71a6dfe50f3d00ad"; 
const TMDB_BASE_URL = "https://api.themoviedb.org/3";

/**
 * 1. Daily Trending Movies Notification
 * Runs every 24 hours (e.g., at 10:00 AM)
 */
exports.sendDailyTrending = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async (context) => {
    try {
      console.log("Fetching daily trending movies...");

      // 1. Fetch from TMDB
      const response = await axios.get(
        `${TMDB_BASE_URL}/trending/movie/day?api_key=${TMDB_API_KEY}`
      );
      const movies = response.data.results.slice(0, 10); // Top 10

      if (movies.length === 0) {
        console.log("No trending movies found.");
        return null;
      }

      // 2. Save to Firestore
      const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
      await db
        .collection("notifications")
        .doc("daily_trending")
        .collection("dates")
        .doc(today)
        .set({
          date: today,
          movies: movies,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      console.log(`Saved ${movies.length} movies for ${today}.`);

      // 3. Send Push Notification to 'trending' topic
      const topMovie = movies[0];
      const payload = {
        notification: {
          title: "🔥 Daily Trending Movies",
          body: `Check out today's top movies including "${topMovie.title}"!`,
        },
        data: {
          type: "trending",
          date: today,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        topic: "trending",
      };

      await fcm.send(payload);
      console.log("Sent daily trending notification.");

      return null;
    } catch (error) {
      console.error("Error in sendDailyTrending:", error);
      return null;
    }
  });

/**
 * 2. Check for New TV Episodes
 * Runs every 6 hours
 */
exports.checkTVUpdates = functions.pubsub
  .schedule("every 6 hours")
  .onRun(async (context) => {
    try {
      console.log("Checking for new TV episodes...");

      // 1. Get all unique TV shows being watched
      // NOTE: This can be expensive at scale. For production, consider a separate 'active_shows' collection.
      const usersSnapshot = await db.collection("users").get();
      
      const updatesToSend = []; // Array of promises

      for (const userDoc of usersSnapshot.docs) {
        const uid = userDoc.id;
        const watchingRef = userDoc.ref.collection("watching");
        const watchingSnapshot = await watchingRef.get();

        if (watchingSnapshot.empty) continue;

        // Get user's device tokens
        const tokensSnapshot = await userDoc.ref.collection("deviceTokens").get();
        if (tokensSnapshot.empty) continue;
        
        const tokens = tokensSnapshot.docs.map(doc => doc.data().token);

        for (const showDoc of watchingSnapshot.docs) {
          const showData = showDoc.data();
          const tvId = showData.id || showData.tmdbId; // Ensure we have ID
          
          if (!tvId) continue;

          // Check cache or fetch fresh data
          // We'll fetch fresh for simplicity here, but caching is recommended
          const showDetails = await getTVDetails(tvId);
          
          if (!showDetails || !showDetails.last_episode_to_air) continue;

          const lastEp = showDetails.last_episode_to_air;
          const lastAirDate = new Date(lastEp.air_date);
          const now = new Date();
          
          // Check if aired in the last 7 hours (since we run every 6h + buffer)
          const diffHours = (now - lastAirDate) / (1000 * 60 * 60);

          if (diffHours >= 0 && diffHours < 7) {
             console.log(`New episode found for ${showDetails.name}: S${lastEp.season_number}E${lastEp.episode_number}`);
             
             // Prepare notification
             const message = {
               notification: {
                 title: `New Episode: ${showDetails.name}`,
                 body: `Season ${lastEp.season_number} Episode ${lastEp.episode_number} is now available!`,
               },
               data: {
                 type: "new_episode",
                 tmdbId: String(tvId),
                 season: String(lastEp.season_number),
                 episode: String(lastEp.episode_number),
                 click_action: "FLUTTER_NOTIFICATION_CLICK",
               },
               tokens: tokens, // Send to all user's devices
             };

             updatesToSend.push(fcm.sendMulticast(message));
          }
        }
      }

      await Promise.all(updatesToSend);
      console.log(`Sent ${updatesToSend.length} TV update notifications.`);
      return null;

    } catch (error) {
      console.error("Error in checkTVUpdates:", error);
      return null;
    }
  });

// Helper to fetch TV details with error handling
async function getTVDetails(tvId) {
  try {
    const response = await axios.get(
      `${TMDB_BASE_URL}/tv/${tvId}?api_key=${TMDB_API_KEY}`
    );
    return response.data;
  } catch (e) {
    console.error(`Failed to fetch TV details for ${tvId}:`, e.message);
    return null;
  }
}
