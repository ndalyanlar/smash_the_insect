import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _nicknameKey = 'user_nickname';
  final String _highScoreKey = 'user_high_score';

  /// Check if a nickname already exists in Firestore
  Future<bool> checkNicknameExists(String nickname) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('nickname', isEqualTo: nickname.toLowerCase())
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking nickname: $e');
      return false;
    }
  }

  /// Validate nickname format
  bool isValidNickname(String nickname) {
    // Nickname can only contain letters, numbers, and underscores
    // Must be between 3 and 20 characters
    final regex = RegExp(r'^[a-zA-Z0-9_]{3,20}$');
    return regex.hasMatch(nickname);
  }

  /// Save nickname locally
  Future<void> saveNicknameLocally(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nicknameKey, nickname);
  }

  /// Get nickname from local storage
  Future<String?> getNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nicknameKey);
  }

  /// Save high score to Firestore
  Future<void> saveHighScore(
    String nickname,
    int score, {
    int level = 1,
    double gameTime = 0.0,
  }) async {
    try {
      final nicknameLower = nickname.toLowerCase();

      // Check if user document exists
      final userDocRef = _firestore.collection('users').doc(nicknameLower);
      final userDoc = await userDocRef.get();

      if (userDoc.exists) {
        // Update existing user's high score if current score is higher
        final currentHighScore = userDoc.data()?['high_score'] as int? ?? 0;
        if (score > currentHighScore) {
          await userDocRef.update({
            'high_score': score,
            'level': level,
            'game_time': gameTime,
            'last_updated': FieldValue.serverTimestamp(),
          });
          print(
              'High score updated for $nickname: $score (Level: $level, Time: ${gameTime.toStringAsFixed(1)}s)');
        }
      } else {
        // Create new user document
        await userDocRef.set({
          'nickname': nickname,
          'high_score': score,
          'level': level,
          'game_time': gameTime,
          'created_at': FieldValue.serverTimestamp(),
          'last_updated': FieldValue.serverTimestamp(),
        });
        print(
            'New user created: $nickname with score: $score (Level: $level, Time: ${gameTime.toStringAsFixed(1)}s)');
      }
    } catch (e) {
      print('Error saving high score: $e');
    }
  }

  /// Get high score for current user from local storage
  Future<int?> getLocalHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_highScoreKey);
  }

  /// Save high score locally
  Future<void> saveLocalHighScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_highScoreKey, score);
  }

  /// Update local high score if current score is higher
  Future<void> updateLocalHighScore(int score) async {
    final currentHigh = await getLocalHighScore();
    if (currentHigh == null || score > currentHigh) {
      await saveLocalHighScore(score);
    }
  }

  /// Get top scores from Firestore
  Future<List<Map<String, dynamic>>> getTopScores({int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('high_score', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'nickname': data['nickname'] ?? 'Unknown',
          'high_score': data['high_score'] ?? 0,
          'level': data['level'] ?? 1,
          'game_time': (data['game_time'] ?? 0.0) as double,
        };
      }).toList();
    } catch (e) {
      print('Error getting top scores: $e');
      return [];
    }
  }

  /// Check if this is the first time opening the app
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('first_launch') ?? true;
  }

  /// Mark that app has been launched
  Future<void> markFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch', false);
  }
}
