// ignore_for_file: deprecated_member_use_from_same_package
import 'package:http/http.dart' as http;
import 'llm_client.dart';
import '../models/message.dart';

/// A [LlmClient] that proxies Vertex AI Gemini requests through a server-side
/// function (e.g. a Firebase Cloud Function), keeping the GCP service account
/// credentials off the client device.
///
/// **Production-ready transport via a Firebase Function proxy.**
/// Implementation lands in v0.4 (post-hackathon, see spec §13.3).
///
/// The reference Firebase Function (TypeScript, ~30 lines) ships in
/// `examples/firebase-proxy/`. It accepts the same payload shape as
/// [VertexDirectClient] and forwards it to Vertex AI, authenticating with a
/// server-side service account.
///
/// Example (using Firebase Auth to supply the user ID token):
/// ```dart
/// final client = VertexProxyClient(
///   endpoint: 'https://europe-west1-gymgeist.cloudfunctions.net/genuiformProxy',
///   authProvider: () async => await FirebaseAuth.instance.currentUser?.getIdToken(),
/// );
/// ```
class VertexProxyClient extends LlmClient {
  /// The full URL of the proxy Cloud Function.
  final String endpoint;

  /// Async callback that returns a bearer token for the current user, or
  /// `null` if the user is unauthenticated. The proxy function validates this
  /// token server-side.
  final Future<String?> Function() authProvider;

  // ignore: unused_field — will be used once generate() is implemented in v0.4.
  final http.Client _httpClient;

  /// Creates a [VertexProxyClient].
  ///
  /// [httpClient] may be injected for testing; defaults to [http.Client()].
  VertexProxyClient({
    required this.endpoint,
    required this.authProvider,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Not yet implemented.
  ///
  /// Throws [UnimplementedError] pointing to spec §13.3.
  /// Full implementation is planned for v0.4 (post-hackathon).
  @override
  Stream<String> generate({
    required String systemPrompt,
    required List<Message> messages,
    required Map<String, dynamic> responseSchema,
    required String model,
    double temperature = 0.7,
  }) {
    throw UnimplementedError(
      'VertexProxyClient is stubbed for v0.1; '
      'full impl deferred to spec §13.3.',
    );
  }
}
