import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectIntronSocket(Uri uri, String apiKey) {
  return IOWebSocketChannel.connect(
    uri,
    headers: {'Authorization': 'Bearer $apiKey'},
  );
}
