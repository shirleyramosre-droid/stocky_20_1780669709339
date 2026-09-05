import 'package:shared_preferences/shared_preferences.dart';

/// Stores the user's personal Gemini API key on-device.
///
/// When a key is set here, [getChatCompletion] calls Gemini directly from
/// the app instead of going through the Rocket-managed Lambda — this key
/// never leaves the device except in requests straight to Google's API.
class GeminiApiKeyService {
  GeminiApiKeyService._();
  static final GeminiApiKeyService instance = GeminiApiKeyService._();

  static const _prefsKey = 'gemini_api_key';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_prefsKey);
    return (key != null && key.trim().isNotEmpty) ? key.trim() : null;
  }

  Future<void> setApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, apiKey.trim());
  }

  Future<void> clearApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
