import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// WebSocket service for real-time email notifications
/// This would typically connect to a Gmail push notification service
/// or your own backend that monitors Gmail via webhooks
class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const Duration _pingInterval = Duration(seconds: 30);

  Stream<Map<String, dynamic>> get messages => _messageController!.stream;
  bool get isConnected => _isConnected;

  WebSocketService() {
    _messageController = StreamController<Map<String, dynamic>>.broadcast();
  }

  /// Connect to WebSocket server
  /// In production, replace with your actual WebSocket endpoint
  Future<void> connect(String userEmail) async {
    if (_isConnected) {
      print('WebSocket: Already connected');
      return;
    }

    try {
      // Example: Connect to a hypothetical WebSocket endpoint
      // In production, you would:
      // 1. Set up Gmail push notifications via Google Cloud Pub/Sub
      // 2. Create a backend service that receives push notifications
      // 3. Forward them via WebSocket to your Flutter app
      
      final wsUrl = 'wss://your-backend-service.com/ws?email=$userEmail';
      
      print('WebSocket: Connecting to $wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      await _channel!.ready;
      _isConnected = true;
      _reconnectAttempts = 0;
      
      print('WebSocket: Connected successfully');
      
      // Start ping/pong to keep connection alive
      _startPing();
      
      // Listen to messages
      _channel!.stream.listen(
        (dynamic message) {
          try {
            final data = json.decode(message as String) as Map<String, dynamic>;
            print('WebSocket: Received message: $data');
            _messageController!.add(data);
          } catch (e) {
            print('WebSocket: Error parsing message: $e');
          }
        },
        onError: (error) {
          print('WebSocket: Error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('WebSocket: Connection closed');
          _handleDisconnect();
        },
        cancelOnError: false,
      );
      
      // Send authentication/identification
      _send({
        'type': 'auth',
        'email': userEmail,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      print('WebSocket: Connection failed: $e');
      _handleDisconnect();
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (timer) {
      if (_isConnected) {
        _send({'type': 'ping', 'timestamp': DateTime.now().toIso8601String()});
      }
    });
  }

  void _handleDisconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    
    // Attempt reconnection
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      print('WebSocket: Attempting reconnection ($_reconnectAttempts/$_maxReconnectAttempts)');
      
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(_reconnectDelay, () {
        // Note: You'd need to pass the user email again
        // This is a simplified version
        // In production, store the email or make it available
        print('WebSocket: Reconnecting...');
      });
    } else {
      print('WebSocket: Max reconnection attempts reached');
      _messageController!.add({
        'type': 'error',
        'message': 'Connection lost. Please refresh.',
      });
    }
  }

  void _send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(json.encode(data));
      } catch (e) {
        print('WebSocket: Error sending message: $e');
      }
    }
  }

  /// Subscribe to new email notifications
  void subscribeToNewEmails(String userEmail) {
    _send({
      'type': 'subscribe',
      'event': 'new_email',
      'email': userEmail,
    });
  }

  /// Request real-time sync
  void requestSync() {
    _send({
      'type': 'sync_request',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    print('WebSocket: Disconnecting');
    _isConnected = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    
    try {
      await _channel?.sink.close(status.normalClosure);
    } catch (e) {
      print('WebSocket: Error closing connection: $e');
    }
    
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController?.close();
  }
}

/// Example usage of WebSocket integration:
/// 
/// In your HomePage or main service:
/// ```dart
/// final _wsService = WebSocketService();
/// 
/// @override
/// void initState() {
///   super.initState();
///   _initWebSocket();
/// }
/// 
/// Future<void> _initWebSocket() async {
///   // Get user email from GoogleSignIn or auth
///   final userEmail = 'user@gmail.com';
///   
///   await _wsService.connect(userEmail);
///   
///   // Listen for new email notifications
///   _wsService.messages.listen((message) {
///     if (message['type'] == 'new_email') {
///       print('New email received: ${message['subject']}');
///       // Refresh email list
///       _refreshEmails();
///     }
///   });
/// }
/// 
/// @override
/// void dispose() {
///   _wsService.dispose();
///   super.dispose();
/// }
/// ```
/// 
/// Backend Setup (Example with Node.js):
/// ```javascript
/// const WebSocket = require('ws');
/// const {google} = require('googleapis');
/// 
/// const wss = new WebSocket.Server({ port: 8080 });
/// 
/// // Set up Gmail push notifications
/// async function setupGmailWatch(userEmail, auth) {
///   const gmail = google.gmail({version: 'v1', auth});
///   await gmail.users.watch({
///     userId: 'me',
///     requestBody: {
///       topicName: 'projects/YOUR_PROJECT/topics/gmail-notifications',
///       labelIds: ['INBOX']
///     }
///   });
/// }
/// 
/// // Handle pub/sub messages and forward via WebSocket
/// wss.on('connection', (ws) => {
///   ws.on('message', (message) => {
///     const data = JSON.parse(message);
///     if (data.type === 'auth') {
///       // Setup push notifications for this user
///       setupGmailWatch(data.email, auth);
///     }
///   });
/// });
/// ```
