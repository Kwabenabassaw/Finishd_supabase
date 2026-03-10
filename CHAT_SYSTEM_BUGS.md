# Chat System Bug Report

Here is a comprehensive list of bugs, issues, and architectural flaws identified in the chat system of the app, spanning UI components, services, and state management.

## 1. UI Components (`ChatScreen`, `ChatListScreen`, `NewChatListScreen`)

*   **`ChatScreen` Context usage after async gap:**
    *   In `_pickAndPreviewMedia` and `_pickAndSendGif`, `BuildContext` is used across asynchronous calls (`Navigator.push`, `_storageService.uploadChatImage`, etc.) without consistently checking `if (!mounted)` before *every* subsequent context usage. Although there are some checks, `context.read<ChatProvider>()` is called after async operations which can throw if the widget is unmounted.
    *   **Fix:** Ensure `if (!mounted) return;` is checked immediately before any `context.read` or `Navigator` call that follows an `await`.
*   **`ChatScreen` Stream Lifecycle:**
    *   In `dispose()`, `context.read<ChatProvider>().closeConversation();` is commented out. If a user pops the screen using the system back button, the stream subscription in `ChatProvider` (`_msgSub`) remains active, leading to memory leaks and background processing of messages for a closed screen. `WillPopScope` catches the back button but relies on a deprecated widget.
    *   **Fix:** Use `PopScope` instead of `WillPopScope` and ensure `closeConversation()` is called reliably when leaving the screen.
*   **`ChatListScreen` FutureBuilder in ListView:**
    *   `_ConversationTile` uses a `FutureBuilder` to fetch user data (`chatProvider.getOtherUser`). This means every time the user scrolls, the future fires again (even with the cache in the provider, it causes a frame rebuild).
    *   **Fix:** Pre-fetch user data or use a more reactive state management approach to bind user data directly to the conversation models before they hit the UI.
*   **`ChatListScreen` Search Logic:**
    *   The search logic in `_ConversationTile` hides the widget `SizedBox.shrink()` if it doesn't match the query, but the item still takes up an index in the `ListView.builder`. This can lead to weird scrolling behavior or empty spaces.
    *   **Fix:** Filter the `conversations` list *before* passing it to `ListView.builder`.
*   **`ChatScreen` Missing Focus Unfocus:**
    *   Tapping outside the keyboard/input area does not unfocus the `_focusNode`, leaving the keyboard open unnecessarily.
    *   **Fix:** Wrap the main `ListView` in a `GestureDetector` with `onTap: () => FocusScope.of(context).unfocus()`.

## 2. Services (`chat_sync_service.dart`, `chat_service.dart`)

*   **`ChatSyncService` Realtime Subscription Memory Leak:**
    *   In `_startGlobalListener()`, `_globalChannel` is subscribed to `public:messages`. However, if the user logs out and logs back in (or `initialize` is called multiple times), multiple subscriptions are created because `_globalChannel?.unsubscribe()` is only called in `dispose()` and `reinitialize()`, but `initialize()` does not clean up previous channels.
    *   **Fix:** Ensure `_globalChannel?.unsubscribe();` is called at the beginning of `_startGlobalListener()`.
*   **`ChatSyncService` Deduplication Logic Flaw:**
    *   When a new message arrives via realtime subscription, it checks `exists` via `_msgBox.query(LocalMessage_.firestoreId.equals(msgId)).build().count() > 0;`. However, if the message was sent locally (optimistically), it might not have the `firestoreId` yet, or it might be mapped incorrectly. The current check only prevents duplicate *incoming* messages, but might fail to link an incoming message to a pending local message if the sender ID check isn't robust.
    *   **Fix:** Ensure optimistic messages are correctly matched with server echoes, perhaps using a local UUID generated before sending.
*   **`ChatSyncService` Missing Offline State Check in Sync:**
    *   `syncAllConversations()` and `syncConversation()` do not check `_isOnline` before making Supabase calls. If called while offline (e.g., via `refreshConversations`), they will throw unhandled exceptions.
    *   **Fix:** Wrap Supabase calls in an `if (!_isOnline) return;` block or handle SocketExceptions gracefully.
*   **`ChatSyncService` Missing Error Handling in Queue Processor:**
    *   In `_processPendingQueue()`, if the `_supabase.from('messages').insert(...)` fails, it falls into the `catch (e)` block and leaves the message in the queue. However, if the error is a permanent failure (e.g., RLS violation, malformed data), the queue will stall forever trying to send the same broken message every 3 seconds.
    *   **Fix:** Implement a retry counter or distinguish between network errors (retry) and validation errors (discard or mark as failed).
*   **`ChatSyncService` Incomplete `markAsRead`:**
    *   `markAsRead` calls the RPC `mark_chat_read`. However, it does not update the local `unreadCount` on the `LocalConversation` object in ObjectBox. The UI will still show the chat as unread until a full sync happens.
    *   **Fix:** Update `LocalConversation.unreadCount = 0` locally in ObjectBox when calling `markAsRead`.
*   **`chat_service.dart` `sendRecommendation` Metadata Issue:**
    *   `sendRecommendation` and `sendVideoLink` insert JSON into a `metadata` column. However, `ChatSyncService`'s realtime listener and sync methods do not parse or save this `metadata` field into `LocalMessage`. This means recommendations and video links sent via `ChatService` will appear as plain text "🎬 Recommended:..." without the actionable metadata when synced to other devices or reloaded.
    *   **Fix:** Update `LocalMessage` schema to support metadata JSON, and ensure `ChatSyncService` parses it during sync and realtime events.

## 3. Providers (`chat_provider.dart`)

*   **`ChatProvider` Auth State Listener Memory Leak:**
    *   In `initialize()`, `Supabase.instance.client.auth.onAuthStateChange.listen(...)` is called. The `StreamSubscription` is never stored or canceled in `dispose()`. Every time `ChatProvider` is instantiated (or `initialize` is called again), a new listener is spawned.
    *   **Fix:** Store the auth stream subscription and cancel it in `dispose()`.
*   **`ChatProvider` NotifyListeners during Build:**
    *   `_subscribeToConversations()` assigns a stream listener that calls `notifyListeners()`. If the stream yields immediately (which `triggerImmediately: true` in ObjectBox does), it might call `notifyListeners()` while the widget tree is still building, causing the classic Flutter error.
    *   **Fix:** Wrap the `notifyListeners()` call inside the stream listener with `Future.microtask(() => notifyListeners());` or ensure it's safe.
*   **`ChatProvider` `_currentConversationId` Bug:**
    *   `closeConversation()` sets `_currentConversationId = null` but doesn't call `notifyListeners()`. If UI elements rely on this state to show/hide, they won't update.
    *   **Fix:** Add `notifyListeners()` to `closeConversation()`.