import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_app/services/sockets.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      home:  WebRTCPage(),
    );
  }
}


class WebRTCPage extends StatefulWidget {
  @override
  _WebRTCPageState createState() => _WebRTCPageState();
}

class _WebRTCPageState extends State<WebRTCPage> {
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  late RTCPeerConnection _peerConnection;
  late Signaling _signaling;
  late MediaStream _localStream;

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize();
    _remoteRenderer.initialize();
    _initWebRTC();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _signaling.close();
    _peerConnection?.close();
    super.dispose();
  }

  Future<void> _initWebRTC() async {
    _signaling = Signaling('ws://localhost:8080', _onSignalingMessage);

    _localStream = await _getUserMedia();
    setState(() {
    _localRenderer.srcObject = _localStream;
    });

    await _createPeerConnection();

  }

  Future<MediaStream> _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      }
    };

    return await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  Future<void> _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"urls": "stun:stun.l.google.com:19302"},
      ]
    };

    _peerConnection = await createPeerConnection(configuration);


    _peerConnection.onTrack = _handleTrack;


    _peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate != null) {
        _signaling.send('candidate', candidate.toMap());
      }
    };

    // _peerConnection.onAddStream = (MediaStream stream) {
    //   setState(() {
    //     _remoteRenderer.srcObject = stream;
    //   });
    // };
    //
    // // Add the local stream to the connection
    // _peerConnection.addStream(_localStream);
    // Instead of onAddStream, use onTrack

    // Adding local tracks instead of streams
    _localStream.getTracks().forEach((track) {
      _peerConnection.addTrack(track, _localStream);
    });
  }


  void _handleTrack(RTCTrackEvent event) async {
    print("Received remote video track with ID: ${event.track.id}");

    if (event.track.kind == 'video') {
      setState(() {
        _remoteRenderer.srcObject = event.streams[0]; // Set remote stream
      });

      // Fetch and print stats after the track is set
      var stats = await _peerConnection.getStats();
      print("PeerConnection Stats: $stats");
    }
  }

// In your _createPeerConnection method

  Future<void> _createOffer() async {
    RTCSessionDescription description = await _peerConnection.createOffer();
    await _peerConnection.setLocalDescription(description);
    _signaling.send('offer', description.sdp);
  }

  Future<void> _createAnswer() async {
    RTCSessionDescription description = await _peerConnection.createAnswer();
    await _peerConnection.setLocalDescription(description);
    _signaling.send('answer', description.sdp);
  }

  void _onSignalingMessage(dynamic message) async {
    switch (message['event']) {
      case 'offer':
        RTCSessionDescription offer = RTCSessionDescription(message['data'], 'offer');
        await _peerConnection.setRemoteDescription(offer);
        _createAnswer();
        break;

      case 'answer':
        RTCSessionDescription answer = RTCSessionDescription(message['data'], 'answer');
        await _peerConnection.setRemoteDescription(answer);
        break;

      case 'candidate':
        RTCIceCandidate candidate = RTCIceCandidate(
          message['data']['candidate'],
          message['data']['sdpMid'],
          message['data']['sdpMLineIndex'],
        );
        await _peerConnection.addCandidate(candidate);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter WebRTC Demo'),
      ),
      body: Column(
        children: [
          Expanded(
            child: RTCVideoView(_localRenderer, mirror: true),
          ),
          Expanded(
            child: RTCVideoView(_remoteRenderer),
          ),
          GestureDetector(
              onTap: ()=>_createOffer(),
              child: Container(
                decoration: BoxDecoration(border: Border.all()),
                padding: const EdgeInsets.all(20.0),
                child: Text('call'),
              )),
        ],
      ),
    );
  }
}
