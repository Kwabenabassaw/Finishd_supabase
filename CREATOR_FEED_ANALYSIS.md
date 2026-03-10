# Creator Content System Analysis

This document provides a simple, less technical overview of how the creator content system (TikTok-style video feed) works in the Finishd app.

---

## 1. How the Feed is Gotten from Supabase

When a user opens the app and navigates to the Creators Feed, the app asks the database (Supabase) for a list of videos to show.

Here is the process:
1.  **Session Setup**: When the user opens the feed, the app creates a "session" or uses an existing one. This session Remembers which videos the user has already seen.
2.  **Requesting Videos**: The app asks Supabase for a personalized batch of videos (usually 15 at a time) using a special database function (`get_personalized_feed`).
3.  **Deduplication (No Repeats)**: The database checks the user's current session to make sure it doesn't send videos the user has already watched recently.
4.  **Ranking**: The database returns the best videos based on an "engagement score" (how much other people liked, commented, or shared the video) and how new they are.
5.  **Tracking**: As soon as the app gets the list, the database secretly marks these videos as "seen" in the user's session so they won't appear again in the next batch.

---

## 2. How the Frontend Uses the Data (Performance, Preloading & Caching)

Once the app receives the list of videos, it uses some clever tricks to make sure the feed feels fast and smooth, just like TikTok.

Here is what happens:
1.  **URL Caching**: The app stores the video locations (URLs) in memory (`CreatorUrlCache`). It even "pre-warms" (loads ahead of time) the URLs for the next few videos before the user even scrolls to them.
2.  **The "Sliding Window" (Preloading)**: The app never tries to load all 15 videos at once because that would crash the phone or drain the battery. Instead, it uses a "Sliding Window" approach (managed by `VideoControllerPool`).
    *   It only keeps a maximum of **3 videos** ready to play at any given time:
        *   The **current** video the user is watching.
        *   The **next** video (pre-loaded so swiping down is instant).
        *   The **previous** video (in case they swipe up to watch it again).
3.  **Memory Management**: The moment a user swipes past a video and it falls outside this 3-video window, the app completely deletes that video player from the phone's memory to keep the app running smoothly.
4.  **Instant Visuals**: Before the video even starts playing, the app instantly shows a thumbnail picture (poster) of the video with a subtle loading animation. Once the video is ready (usually in milliseconds), it smoothly fades in over the picture.

---

## 3. How the Database Delivers Videos to Everyone

The actual video files are stored and delivered using Supabase's storage system.

1.  **Storage Buckets**: Videos are stored in a private vault (`creator-videos`), while the thumbnail pictures are stored in a public vault (`creator-thumbnails`).
2.  **Secure Links (Signed URLs)**: Because the videos are in a private vault, the database doesn't just give out direct links. Instead, when the app wants to play a video, it asks Supabase for a temporary, secure "Signed URL". This link is only valid for a short time (e.g., 1 hour). This prevents people from stealing direct links to the videos and sharing them outside the app.
3.  **Real-Time Stats**: As users watch videos, they can like, comment, or share them. The app uses "Real-Time Subscriptions" to listen to the database. If user A likes a video, user B (who is currently watching the same video) will see the like count go up instantly without having to refresh the page.

---

## Summary: Pros and Cons of this Approach

### Pros (The Good Stuff)
*   **Super Fast Swiping**: By pre-loading only the next video and pre-fetching URLs, swiping between videos feels instant.
*   **Low Memory Usage**: The "sliding window" approach ensures older phones won't crash from loading too many videos at once. It strictly controls how much memory the app uses.
*   **No Repeats**: The session system intelligently tracks what a user has seen, ensuring they always get fresh content when they scroll.
*   **Secure**: Using signed URLs protects the creator's content from being scraped or hotlinked by other websites.
*   **Live Updates**: Real-time stats make the app feel alive and active.

### Cons (The Trade-offs)
*   **Database Load**: Asking for new secure "Signed URLs" for every single video can put a lot of strain on the database if thousands of users are scrolling very fast.
*   **Data Usage**: Pre-loading the *next* video means the app uses internet data downloading a video the user might never actually watch (if they close the app before swiping).
*   **Complex Logic**: The backend function that figures out which videos to show (ranking, filtering out seen videos, checking if they are approved) is very complex. If it breaks, the entire feed stops working.
*   **Fallback Limitations**: If the smart feed ranking fails, the app falls back to a simple chronological list, which might show users videos they've already seen or lower-quality content.