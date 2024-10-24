import 'dart:typed_data';
import 'package:web_socket_channel/io.dart';
import 'dart:convert';

class Signaling {
  late IOWebSocketChannel _channel;
  Function(Map) onMessage;

  Signaling(String serverUrl, this.onMessage) {
    _channel = IOWebSocketChannel.connect(serverUrl);
    _channel.stream.listen((message) {
      if (message is Uint8List) {
        // Convert Uint8List to String
        message = utf8.decode(message as List<int>  );
      }
      var decodedMessage = jsonDecode(message);
      // print("-----------------------RECEIVED DATA ::\n "+decodedMessage.toString());
      onMessage(decodedMessage);
    });
  }

  void send(String event, dynamic data) {
    var message = {'event': event, 'data': data};
    print("-----------------------SEND DATA :: "+message.toString());
    _channel.sink.add(jsonEncode(message));
  }

  void close() {
    _channel.sink.close();
  }
}
