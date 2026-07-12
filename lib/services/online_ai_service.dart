import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/soil_sample.dart';

/// Calls the authenticated Firebase backend for cloud AI responses.
class OnlineAiService {
  static const _callableName = 'chatAssistant';

  final FirebaseFunctions _functions;

  OnlineAiService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  Future<bool> isConfigured() async =>
      FirebaseAuth.instance.currentUser != null;

  Future<String> chat({
    required List<Map<String, String>> history,
    required String userMessage,
    SoilSample? soilContext,
    List<String> learnedContext = const [],
    List<String> verifiedInsights = const [],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return '🔒 **Sign in required.**\n\nCreate or sign in to your GardenerGrid account to use cloud AI.';
    }

    try {
      final callable = _functions.httpsCallable(
        _callableName,
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );

      final result = await callable.call({
        'history': history,
        'userMessage': userMessage,
        'soilContext': _serializeSoilContext(soilContext),
        'learnedContext': learnedContext,
        'verifiedInsights': verifiedInsights,
      });

      final data = _asMap(result.data);
      final content = data['content'];
      if (content is String && content.trim().isNotEmpty) {
        return content.trim();
      }

      final error = data['error'];
      if (error is String && error.trim().isNotEmpty) {
        return '❌ **Server error.**\n\n${error.trim()}';
      }

      return '❌ **AI response error.**\n\nThe cloud assistant returned an unexpected response.';
    } on FirebaseFunctionsException catch (e) {
      return _mapFunctionsError(e);
    } catch (e) {
      return '📡 **Connection failed.**\n\nError: ${e.toString()}\n\nCheck your internet connection. GardenerGrid will keep the built-in plant knowledge available offline.';
    }
  }

  Map<String, dynamic> _serializeSoilContext(SoilSample? soilContext) {
    if (soilContext == null) return {};

    return {
      'ph': soilContext.ph,
      'nitrogen': soilContext.nitrogen,
      'phosphorus': soilContext.phosphorus,
      'potassium': soilContext.potassium,
      'moisture': soilContext.moisture,
      'organicMatter': soilContext.organicMatter,
      'deficiencies': soilContext.deficiencies,
      'healthScore': soilContext.healthScore,
      'source': soilContext.source.name,
      'sensorName': soilContext.sensorName,
      'sensorId': soilContext.sensorId,
      'signalStrength': soilContext.signalStrength,
      'timestamp': soilContext.timestamp.toIso8601String(),
    };
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map<dynamic, dynamic>);
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded as Map<dynamic, dynamic>);
        }
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }

  String _mapFunctionsError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return '🔒 **Sign in required.**\n\nCreate or sign in to your GardenerGrid account to use cloud AI.';
      case 'failed-precondition':
        return '🛠️ **Cloud AI not available yet.**\n\nGardenerGrid has not finished its server-side AI setup. The built-in plant knowledge base will keep working offline.';
      case 'deadline-exceeded':
        return '⏱️ **Cloud AI timed out.**\n\nThe request took too long. Please try again in a moment.';
      case 'resource-exhausted':
        return '⏱️ **Cloud AI is busy.**\n\nThe assistant hit a temporary usage limit. Please try again shortly.';
      case 'unavailable':
        return '📡 **Connection failed.**\n\nGardenerGrid could not reach the cloud assistant.\n\nCheck your internet connection and try again.';
      case 'invalid-argument':
        return '⚠️ **Request could not be sent.**\n\nPlease rephrase your question and try again.';
      default:
        final details = error.message?.trim();
        return details == null || details.isEmpty
            ? '❌ **Server error.**\n\nThe cloud assistant returned an unexpected error.'
            : '❌ **Server error.**\n\n$details';
    }
  }
}
