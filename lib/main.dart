import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mime/mime.dart';
void main() {
  runApp(MyApp());
  startServer();
}

// グローバルなValueNotifierを作成
final requestUriNotifier = ValueNotifier<String>('Waiting for requests...');
final ValueNotifier<Image?> requestImageNotifier = ValueNotifier<Image?>(null);


// サーバーの起動
Future<void> startServer() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  debugPrint('Server running on http://${server.address.address}:${server.port}');
  
  await for (HttpRequest request in server) {
    // リクエストURIを取得してNotifierを更新
    final uri = request.uri.toString();
    
    if (request.headers.contentType != null) {
      if (request.headers.contentType!.mimeType.startsWith("image/")) {
        // /upload に画像がアップロードされた場合
        // Handle the request stream properly
        final List<int> data = await request.fold<List<int>>([], (previous, element) => previous..addAll(element));
        requestImageNotifier.value = Image.memory(Uint8List.fromList(data));
        requestUriNotifier.value = "Image received $uri";
        request.response
          ..write('Request received for: $uri')
          ..close();
        continue;
      } else if (request.headers.contentType!.mimeType == "multipart/form-data") {
        // Handle multipart/form-data
        final boundary = request.headers.contentType!.parameters['boundary'];
        final transformer = MimeMultipartTransformer(boundary!);
        final bodyStream = request.cast<List<int>>().transform(transformer);

        String cText = "";
        await for (final part in bodyStream) {
          print(part.headers);
          if (part.headers['content-type']?.startsWith('image/') == true) {
            cText += "content-disposition = ${part.headers['content-disposition']}\n";;
            final content = await part.fold<List<int>>([], (previous, element) => previous..addAll(element));
            requestImageNotifier.value = Image.memory(Uint8List.fromList(content));
          }else{
            final content = await utf8.decoder.bind(part).join();
            cText += content;
          }
        }
        
        requestUriNotifier.value = "cText $cText";
        request.response
          ..write('Multipart request received for: $uri')
          ..close();
        continue;
      }
    }

    requestImageNotifier.value = null;
    if (uri.startsWith("/launch/")) {
      final String content = await utf8.decoder.bind(request).join();
      requestUriNotifier.value = content.replaceAll("\\n", "\n"); 
      _launchURL(content); // Launch the browser with the received URI
      request.response
        ..write('Request received for: $content')
        ..close();
      continue;
    }
    // /favicon.ico
    // レスポンスを返す
    request.response.headers.contentType = ContentType.html;
    request.response
      ..write('<html><body><a href="https://docs.google.com/spreadsheets/d/1P6Lxj5SGeJ7FaMMELo2OligWI5x7XbARlyyTV62qxkI/edit?gid=0#gid=0">link</a></body></html>')
      ..close();
  }
}

// Function to launch the browser with the given URL
void _launchURL(String intentstr) async {
  int p = intentstr.indexOf("http://");
  if (p < 0) {
    p = intentstr.indexOf("https://");
  }
  if(p >= 0) {
    String url = intentstr.substring(p).split("\n")[0];
    Uri uri = Uri.parse(url);
    if (await canLaunchUrl (uri)) {
      await launchUrl(uri);
    } else {
      debugPrint( 'Could not launch $intentstr');
    }
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _ipAddress = '取得中...';
  TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _getLocalIpAddress();
  }

  Future<void> _getLocalIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback) { // ループバックアドレス(127.0.0.1)は除外
            setState(() {
              _ipAddress = addr.address; // IPv4アドレスをセット
            });
            return;
          }
        }
      }
      setState(() {
        _ipAddress = 'IPアドレスが見つかりませんでした';
      });
    } catch (e) {
      setState(() {
        _ipAddress = 'エラー: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("'Flutter Web Server $_ipAddress'")),
        body: Center(child: 
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    QrImageView(
                      data: "IntentBridgeHost=$_ipAddress:8080",
                      version: QrVersions.auto,
                      size: 100.0,
                    ),
                    SelectableText('http://$_ipAddress:8080', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),

              ValueListenableBuilder<String>(
                valueListenable: requestUriNotifier,
                builder: (context, uri, child) {
                  return SelectableText(
                    'Last Request URI: $uri',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20),
                  );
                },
              ),
              
              InteractiveViewer(
                maxScale: 64,
                transformationController: _transformationController,
                child: ValueListenableBuilder<Image?>(
                  valueListenable: requestImageNotifier,
                  builder: (context, img, child) {
                    return img ?? SelectableText(
                      'No image received',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20),
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
            ],
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