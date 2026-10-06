import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  /// Unified Google Sign-In that automatically handles Desktop, Mobile, and Web seamlessly.
  static Future<void> signInWithGoogle() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // 1. Mobile (Android/iOS) -> Uses native Google Sign-In popup
      final googleSignIn = GoogleSignIn(
        // The serverClientId is your Google Cloud Web Client ID (NOT the Android/iOS client ID)
        serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'], 
        scopes: [
          'https://www.googleapis.com/auth/drive.file',
          'https://www.googleapis.com/auth/calendar.events',
        ],
      );
      
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return; // User cancelled

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null || accessToken == null) {
        throw 'Missing Google ID Token or Access Token';
      }

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } else if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      // 2. Desktop (Windows/Mac/Linux) -> Uses our local loopback server
      await _signInWithGoogleDesktop();
    } else {
      // 3. Web -> Standard OAuth redirect
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        scopes: 'https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/calendar.events',
      );
    }
  }

  /// Completely signs out of both Supabase and native Google Sign-In, 
  /// forcing the user to pick an account next time they log in.
  static Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    
    // On mobile, we must also clear the native Google Sign-In cache, 
    // otherwise the OS will automatically log them in with the previous account.
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      await googleSignIn.disconnect();
    }
  }

  /// Internal method for handling Desktop OAuth loopback
  static Future<void> _signInWithGoogleDesktop() async {
    HttpServer? server;
    try {
      // Start local server to catch the redirect
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);
      
      // Trigger Supabase OAuth
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        scopes: 'https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/calendar.events',
        redirectTo: 'http://localhost:3000/',
      );

      // Wait for the browser to redirect to localhost:3000
      final request = await server.first;
      
      // Send a nice success page to the browser
      request.response.headers.contentType = ContentType.html;
      request.response.write('''
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: system-ui, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background-color: #111; color: white; }
            .card { background: #222; padding: 40px; border-radius: 16px; text-align: center; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
            h1 { margin-top: 0; color: #4CAF50; }
          </style>
        </head>
        <body>
          <div class="card">
            <h1>Login Successful!</h1>
            <p>You can safely close this tab and return to Tanu.</p>
          </div>
          <script>
            setTimeout(() => window.close(), 3000);
          </script>
        </body>
        </html>
      ''');
      await request.response.close();

      // Process the URL using Supabase
      final url = Uri.parse('http://localhost:3000${request.uri}');
      
      // For PKCE flow, extract the code and exchange it.
      // signInWithOAuth sets up the PKCE verifier, getSessionFromUrl uses it.
      await Supabase.instance.client.auth.getSessionFromUrl(url);
      
    } finally {
      await server?.close(force: true);
    }
  }
}
