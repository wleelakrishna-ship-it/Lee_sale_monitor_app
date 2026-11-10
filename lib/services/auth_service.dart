import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around Firebase Authentication (email/password only — accounts for
/// staff are created by the business owner in the Firebase Console, not in-app).
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// Maps a [FirebaseAuthException] to a short, user-facing message.
  String messageForError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'invalid-credential':
          return 'No account found with that email and password.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'network-request-failed':
          return 'No internet connection. Please check your network and try again.';
        default:
          return error.message ?? 'Sign in failed. Please try again.';
      }
    }
    return 'Sign in failed. Please try again.';
  }
}
