import 'package:google_generative_ai/google_generative_ai.dart';

class VertexAiService {
  late final GenerativeModel _model;

  VertexAiService() {
    // Initialize using Google Generative AI SDK
    // Using hardcoded key as requested for migration
    const apiKey = 'AIzaSyBRKUORBWfivcUSL9augk0q9FNYzE2x3rE';

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
      systemInstruction: Content.system(
        'You are the Finishd AI Movie Assistant. Your goal is to help users understand the movie they are currently viewing. '
        'You have access to specific movie metadata. You must stay in character as a helpful movie expert. '
        'NEVER reveal spoilers. NEVER suggest movies from other platforms unless they are in the context. '
        'Keep responses concise and well-formatted using markdown.',
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
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
