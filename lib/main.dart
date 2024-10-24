import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_app/services/signaling_service_.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: "AIzaSyAuhb2HtnXOpYE2sexKLvgwMm5M2y0i9cE",
          appId: "1:1075872048568:android:78678346f3e3d74f97db4d",
          messagingSenderId: "1075872048568",
          projectId: "flutter-web-rtc-e4b65"));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebRTC Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<StatefulWidget> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final TextEditingController _roomTextController = TextEditingController();
  SignalingService signalingService = SignalingService();

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();

    signalingService.onAddRemoteStream = (stream) {
      _remoteRenderer.srcObject = stream;
    };
  }

  @override
  void dispose() {
    super.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  void updateLocalRenderer(MediaStream stream) {
    setState(() {
      _localRenderer.srcObject = stream;
    });
  }
  void setRoomID(String t){
    setState(() {
      _roomTextController.text=t;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Demo"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
                children: [
                  ElevatedButton(
                      onPressed: () {
                        signalingService.openUserMedia(
                            _localRenderer, _remoteRenderer,updateLocalRenderer );
                      },
                      child: const Text('Open vid & mic')),
                  ElevatedButton(
                      onPressed: () {
                        signalingService.createRoom(_remoteRenderer,setRoomID
                        );
                      },
                      child: const Text("create meeting")),
                  ElevatedButton(
                      onPressed: () {
                        signalingService.joinRoom(_roomTextController.text,_remoteRenderer);
                      },
                      child: const Text('join meeting')),
                  ElevatedButton(
                      onPressed: () {
                        signalingService.hangUp(_localRenderer);
                      },
                      child: const Text('Hang up')),
                ],
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                      child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                  )),
                  Expanded(child: RTCVideoView(_remoteRenderer)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Room ID : '),
                  Flexible(
                      child: TextField(
                    controller: _roomTextController,
                  ))
                ],
              ),
            ),
            const SizedBox(
              height: 8,
            )
          ],
        ),
      ),
    );
  }
}
