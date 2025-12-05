# Finishd - Architecture & Database Documentation

**Prepared for:** Client Review  
**Version:** 1.0  
**Date:** December 4, 2025

---

## 1. System Architecture Diagram

The following diagram illustrates the overall architecture of the Finishd application, showing how the Flutter mobile app connects to Firebase backend services and external APIs.

```mermaid
flowchart TB
    subgraph CLIENT["📱 Client Layer"]
        APP["Flutter Mobile App<br/>(iOS / Android)"]
    end

    subgraph FIREBASE["☁️ Firebase Backend"]
        AUTH["Firebase Auth<br/>• Email/Password<br/>• Google Sign-In<br/>• Apple Sign-In"]
        FIRESTORE["Cloud Firestore<br/>• User Data<br/>• Chats & Messages<br/>• Movie Lists<br/>• Recommendations"]
        STORAGE["Firebase Storage<br/>• Profile Images<br/>• Media Files"]
        FCM["Firebase Cloud Messaging<br/>• Push Notifications<br/>• Topic Subscriptions"]
    end

    subgraph EXTERNAL["🌐 External APIs"]
        TMDB["TMDB API<br/>• Movie/TV Data<br/>• Trailers<br/>• Cast & Crew<br/>• Streaming Providers"]
        OMDB["OMDb API<br/>• IMDb Ratings<br/>• Rotten Tomatoes<br/>• Metacritic Scores"]
        YOUTUBE["YouTube<br/>• Video Feed Content<br/>• Trailer Playback"]
    end

    APP <-->|Authentication| AUTH
    APP <-->|Real-time Data| FIRESTORE
    APP <-->|File Upload/Download| STORAGE
    APP <-->|Notifications| FCM
    
    APP -->|Movie Data Requests| TMDB
    APP -->|Ratings Requests| OMDB
    APP -->|Video Extraction| YOUTUBE
    
    FIRESTORE -.->|Trigger| FCM

    style CLIENT fill:#E3F2FD,stroke:#1976D2,stroke-width:2px
    style FIREBASE fill:#FFF3E0,stroke:#FF9800,stroke-width:2px
    style EXTERNAL fill:#E8F5E9,stroke:#4CAF50,stroke-width:2px
```

---

## 2. Detailed Service Integration

```mermaid
flowchart LR
    subgraph APP["Flutter App Services"]
        AS[AuthService]
        CS[ChatService]
        US[UserService]
        MLS[MovieListService]
        RS[RatingsService]
        RCS[RecommendationService]
        PFS[PersonalizedFeedService]
        PNS[PushNotificationService]
        DLS[DeepLinkService]
    end

    subgraph FIREBASE["Firebase"]
        FA[(Firebase Auth)]
        FS[(Firestore)]
        FCM[(Cloud Messaging)]
    end

    subgraph APIS["External APIs"]
        T[TMDB]
        O[OMDb]
        Y[YouTube]
    end

    AS --> FA
    CS --> FS
    US --> FS
    MLS --> FS
    RS --> FS
    RS --> T
    RS --> O
    RCS --> FS
    PFS --> FS
    PFS --> Y
    PFS --> T
    PNS --> FCM
    DLS -.->|URL Launch| STREAMING[Streaming Apps]

    style APP fill:#E1F5FE
    style FIREBASE fill:#FFF8E1
    style APIS fill:#E8F5E9
```

---

## 3. Database Schema (Firestore)

### Collection Structure Overview

```mermaid
erDiagram
    USERS ||--o{ FOLLOWERS : has
    USERS ||--o{ FOLLOWING : has
    USERS ||--o{ WATCHING : has
    USERS ||--o{ WATCHLIST : has
    USERS ||--o{ FINISHED : has
    USERS ||--o{ FAVORITES : has
    USERS ||--o{ DEVICE_TOKENS : has
    
    CHATS ||--o{ MESSAGES : contains
    CHATS }o--|| USERS : "participant A"
    CHATS }o--|| USERS : "participant B"
    
    RECOMMENDATIONS }o--|| USERS : "from"
    RECOMMENDATIONS }o--|| USERS : "to"
    
    MOVIES ||--o{ RATINGS : caches
    
    FEED_CACHE ||--|| USERS : "belongs to"

    USERS {
        string uid PK
        string email
        string username
        string firstName
        string lastName
        string profileImage
        string bio
        timestamp joinedAt
    }

    FOLLOWERS {
        string followerId PK
        timestamp followedAt
    }

    FOLLOWING {
        string followingId PK
        timestamp followedAt
    }

    WATCHING {
        string movieId PK
        string title
        string posterPath
        string mediaType
        timestamp addedAt
    }

    WATCHLIST {
        string movieId PK
        string title
        string posterPath
        string mediaType
        timestamp addedAt
    }

    FINISHED {
        string movieId PK
        string title
        string posterPath
        string mediaType
        timestamp addedAt
    }

    FAVORITES {
        string movieId PK
        string title
        string posterPath
        string mediaType
        timestamp addedAt
    }

    CHATS {
        string chatId PK
        array participants
        string lastMessage
        timestamp lastMessageTime
        string lastMessageSender
        map unreadCounts
        timestamp createdAt
    }

    MESSAGES {
        string messageId PK
        string senderId
        string receiverId
        string text
        string type
        string mediaUrl
        timestamp timestamp
        boolean isRead
    }

    RECOMMENDATIONS {
        string id PK
        string fromUserId FK
        string toUserId FK
        string movieId
        string movieTitle
        string moviePosterPath
        string mediaType
        timestamp timestamp
        string status
    }

    MOVIES {
        string tmdbId PK
    }

    RATINGS {
        string imdbId
        string imdbRating
        string rottenTomatoes
        string metacritic
        timestamp cachedAt
    }

    FEED_CACHE {
        string uid PK
        array videos
        timestamp cachedAt
    }

    DEVICE_TOKENS {
        string token PK
        string platform
        timestamp lastUpdated
    }
```

---

## 4. Firestore Collections Hierarchy

```mermaid
flowchart TB
    subgraph ROOT["📁 Firestore Root"]
        USERS["users/"]
        CHATS["chats/"]
        RECOMMENDATIONS["recommendations/"]
        MOVIES["movies/"]
        FEED_CACHE["feed_cache/"]
    end

    subgraph USER_DOC["users/{userId}"]
        USER_DATA["User Document<br/>• uid, email, username<br/>• firstName, lastName<br/>• profileImage, bio<br/>• joinedAt"]
        
        subgraph USER_SUBS["Subcollections"]
            FOLLOWERS_COL["followers/{followerId}"]
            FOLLOWING_COL["following/{followingId}"]
            WATCHING_COL["watching/{movieId}"]
            WATCHLIST_COL["watchlist/{movieId}"]
            FINISHED_COL["finished/{movieId}"]
            FAVORITES_COL["favorites/{movieId}"]
            TOKENS_COL["deviceTokens/{token}"]
        end
    end

    subgraph CHAT_DOC["chats/{chatId}"]
        CHAT_DATA["Chat Document<br/>• participants[]<br/>• lastMessage<br/>• unreadCounts{}"]
        MESSAGES_COL["messages/{messageId}"]
    end

    subgraph MOVIE_DOC["movies/{tmdbId}"]
        MOVIE_DATA["Movie Document"]
        RATINGS_COL["ratings/data"]
    end

    USERS --> USER_DOC
    USER_DATA --> USER_SUBS
    
    CHATS --> CHAT_DOC
    CHAT_DATA --> MESSAGES_COL
    
    MOVIES --> MOVIE_DOC
    MOVIE_DATA --> RATINGS_COL

    style ROOT fill:#FFECB3
    style USER_DOC fill:#E3F2FD
    style CHAT_DOC fill:#E8F5E9
    style MOVIE_DOC fill:#FCE4EC
```

---

## 5. Data Flow Diagrams

### 5.1 User Authentication Flow

```mermaid
sequenceDiagram
    participant U as User
    participant A as Flutter App
    participant FA as Firebase Auth
    participant FS as Firestore

    U->>A: Sign Up / Log In
    A->>FA: Authenticate (Email/Google/Apple)
    FA-->>A: User Credential
    A->>FS: Check if user document exists
    
    alt New User
        A->>FS: Create user document
        A->>A: Navigate to Onboarding
    else Existing User
        FS-->>A: Return user data
        A->>A: Navigate to Home
    end
```

### 5.2 Chat Message Flow

```mermaid
sequenceDiagram
    participant UA as User A (Sender)
    participant APP as Flutter App
    participant FS as Firestore
    participant FCM as Cloud Messaging
    participant UB as User B (Receiver)

    UA->>APP: Send Message
    APP->>FS: Write to messages subcollection
    APP->>FS: Update chat metadata
    FS-->>APP: Real-time listener triggers
    FS-.->FCM: Trigger notification (via Cloud Function)
    FCM-.->UB: Push Notification
    
    Note over FS,UB: User B's app receives<br/>real-time update via listener
```

### 5.3 Movie Details & Ratings Flow

```mermaid
sequenceDiagram
    participant U as User
    participant A as App
    participant FS as Firestore
    participant TMDB as TMDB API
    participant OMDB as OMDb API

    U->>A: View Movie Details
    A->>TMDB: Fetch movie details
    TMDB-->>A: Movie data, trailers, cast
    
    A->>FS: Check cached ratings
    alt Cache Fresh (< 7 days)
        FS-->>A: Return cached ratings
    else Cache Stale or Missing
        A->>TMDB: Get IMDb ID
        TMDB-->>A: imdb_id
        A->>OMDB: Fetch ratings
        OMDB-->>A: IMDb, RT, Metacritic
        A->>FS: Cache ratings
    end
    
    A->>U: Display complete details
```

---

## 6. Security Rules Summary

| Collection | Read | Write |
|-----------|------|-------|
| `users/{userId}` | Any authenticated user | Owner only |
| `users/{uid}/followers` | Any authenticated user | Follower (self-add) |
| `users/{uid}/following` | Any authenticated user | Owner only |
| `users/{uid}/[movie lists]` | Any authenticated user | Owner only |
| `chats/{chatId}` | Participants only | Participants only |
| `chats/{chatId}/messages` | Participants only | Sender must be participant |
| `movies/{id}/ratings` | Any authenticated user | Any authenticated user |
| `feed_cache/{userId}` | Owner only | Owner only |
| `recommendations` | Any authenticated user | Any authenticated user |

---

## 7. External API Integration Summary

| API | Purpose | Data Retrieved |
|-----|---------|----------------|
| **TMDB** | Movie & TV Show data | Titles, posters, synopses, cast, crew, trailers, streaming providers, trending, discover |
| **OMDb** | Aggregated ratings | IMDb rating, Rotten Tomatoes score, Metacritic score |
| **YouTube** | Video content | Trailers, personalized video feed content |

---

## 8. Technology Stack Summary

```mermaid
mindmap
  root((Finishd App))
    Frontend
      Flutter 3.9+
      Provider State Management
      Material Design 3
    Backend
      Firebase Auth
      Cloud Firestore
      Firebase Storage
      Cloud Messaging
    APIs
      TMDB API
      OMDb API
      YouTube
    Features
      Real-time Chat
      Push Notifications
      Video Feed
      Social Features
```

---

*Document prepared for architectural review - December 4, 2025*
