import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../api/api_config.dart';

/// Socket.IO client for consultation chat (query `userId` joins per-user inbox room).
sio.Socket createConsultationSocket(int userId) {
  final url = socketUrl;
  return sio.io(
    url,
    sio.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableReconnection()
        .setQuery({'userId': userId.toString()})
        .build(),
  );
}
