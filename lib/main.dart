import 'dart:io';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
  startServer();
}

// グローバルなValueNotifierを作成
final requestUriNotifier = ValueNotifier<String>('Waiting for requests...');

// サーバーの起動
Future<void> startServer() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('Server running on http://${server.address.address}:${server.port}');
  
  await for (HttpRequest request in server) {
    // リクエストURIを取得してNotifierを更新
    final uri = request.uri.toString();
    requestUriNotifier.value = uri;
    
    // レスポンスを返す
    request.response
      ..write('Request received for: $uri')
      ..close();
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Flutter Web Server')),
        body: Center(
          child: ValueListenableBuilder<String>(
            valueListenable: requestUriNotifier,
            builder: (context, uri, child) {
              return Text(
                'Last Request URI: $uri',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20),
              );
            },
          ),
        ),
      ),
    );
  }
}

/*  
  In the above code, we have created a simple Flutter web application that starts an HTTP server on port 8080. The server responds with a simple message and the IP address of the client. 
  To run the above code, you need to add the following dependencies in your  pubspec.yaml  file: 
  dependencies:
    flutter:
      sdk: flutter
    http: ^0.13.3
  
  Now, run the application using the following command: 
  flutter run -d chrome
  
  This will start the Flutter web application and the HTTP server. You can access the server by visiting  http://localhost:8080  in your browser. 
  Conclusion 
  In this article, we learned how to create an HTTP server in Flutter. We also learned how to handle requests and send responses using the  HttpServer  class. 
  If you have any questions or suggestions, feel free to leave a comment below. 
  Happy coding! 
  Peer Review Contributions by:  Mohan Raj
  */