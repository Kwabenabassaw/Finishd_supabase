import 'package:firebase_ai/firebase_ai.dart';

class VertexAiService {
  late final GenerativeModel _model;

  VertexAiService() {
    // Initialize using Firebase AI Logic SDK with Gemini Developer API
    // This uses the recommended googleAI() backend for the no-cost Spark plan
    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      tools: [Tool.googleSearch()],
      systemInstruction: Content.system(
        'You are the Finishd AI Movie Assistant. Your goal is to help users understand the movie they are currently viewing. '
        'You have access to specific movie metadata. You must stay in character as a helpful movie expert. '
        'NEVER reveal spoilers. NEVER suggest movies from other platforms unless they are in the context. '
        'Keep responses concise and well-formatted using markdown.',
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium, null),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium, null),
        SafetySetting(
          HarmCategory.sexuallyExplicit,
          HarmBlockThreshold.medium,
          null,
        ),
        SafetySetting(
          HarmCategory.dangerousContent,
          HarmBlockThreshold.medium,
          null,
        ),
      ],
    );
  }

  /// Starts a new chat session with provided context.
  ChatSession startChat({required String movieContext}) {
    return _model.startChat(
      history: [
        Content.text(movieContext),
        Content.model([
          TextPart(
            'I understand. I am ready to assist the user with information about this movie based on the provided context. I will avoid spoilers and stay on topic.',
          ),
        ]),
      ],
    );
  }

  /// Sends a message to the AI and returns the response stream.
  Stream<GenerateContentResponse> sendMessageStream(
    ChatSession session,
    String message,
  ) {
    return session.sendMessageStream(Content.text(message));
  }

  /// Sends a message and returns the full response.
  Future<GenerateContentResponse> sendMessage(
    ChatSession session,
    String message,
  ) {
    return session.sendMessage(Content.text(message));
  }
}
