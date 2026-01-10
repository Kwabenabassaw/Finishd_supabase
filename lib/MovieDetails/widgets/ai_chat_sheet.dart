import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:finishd/Model/MovieDetails.dart';
import 'package:finishd/Model/tvdetail.dart';
import 'package:finishd/Model/movie_ratings_model.dart';
import 'package:finishd/provider/ai_assistant_provider.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

class AiChatSheet extends StatefulWidget {
  final MovieDetails? movie;
  final TvShowDetails? tvShow;
  final MovieRatings ratings;

  const AiChatSheet({super.key, this.movie, this.tvShow, required this.ratings})
    : assert(movie != null || tvShow != null);

  @override
  State<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends State<AiChatSheet> {
  @override
  void initState() {
    super.initState();
    // Initialize provider for this title
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.movie != null) {
        context.read<AiAssistantProvider>().initForMovie(
          widget.movie!,
          widget.ratings,
        );
      } else if (widget.tvShow != null) {
        context.read<AiAssistantProvider>().initForTvShow(
          widget.tvShow!,
          widget.ratings,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AiAssistantProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: 80.h,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF4ADE80),
                    radius: 5.w,
                    child: Icon(
                      FontAwesomeIcons.brain,
                      color: Colors.black,
                      size: 6.w,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Assistant',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            color: Theme.of(
                              context,
                            ).textTheme.titleLarge?.color,
                          ),
                        ),
                        Text(
                          'Asking about: ${widget.movie?.title ?? widget.tvShow?.name ?? "this content"}',
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 6.w),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Chat View
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  primaryColor: isDark ? Colors.white : Colors.black,
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: isDark ? Colors.white : Colors.black,
                  ),
                  textSelectionTheme: TextSelectionThemeData(
                    cursorColor: isDark ? Colors.white : Colors.black,
                  ),
                ),
                child: DashChat(
                  currentUser: provider.currentUser,
                  onSend: (ChatMessage m) {
                    provider.sendMessage(m.text);
                  },
                  messages: provider.messages,
                  typingUsers: provider.isLoading ? [provider.aiUser] : [],
                  inputOptions: InputOptions(
                    sendButtonBuilder: (onSend) => IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: onSend,
                      icon: Icon(
                        Icons.send_rounded,
                        color: Color(0xFF4ADE80),
                        size: 7.w,
                      ),
                    ),
                    inputDecoration: InputDecoration(
                      hintText:
                          'Ask anything about the ${widget.movie != null ? "movie" : "show"}...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey : Colors.black54,
                        fontSize: 11.sp,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.w),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.w),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.w),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 5.w,
                        vertical: 1.2.h,
                      ),
                    ),
                  ),
                  messageOptions: MessageOptions(
                    showOtherUsersAvatar: true,
                    showTime: true,
                    // AI / Other User (Left Side)
                    containerColor: isDark
                        ? const Color(0xFF333333)
                        : const Color(0xFFE5E5EA),
                    textColor: isDark ? Colors.white : Colors.black,
                    // Current User (Right Side) - Brand Green
                    currentUserContainerColor: const Color(0xFF4ADE80),
                    currentUserTextColor: Colors.black,
                  ),
                ),
              ),
            ),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }
}
