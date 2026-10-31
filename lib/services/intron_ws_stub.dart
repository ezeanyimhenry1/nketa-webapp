import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectIntronSocket(Uri uri, String apiKey) {
  throw UnsupportedError(
    'Streaming speech-to-text is not available in the browser.',
  );
}
