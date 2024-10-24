import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef void StreamStateCallback(MediaStream stream);

class SignalingService {
  Map<String, dynamic> configuration = {
    "iceServers": [
      {
        'urls': [
          "stun:stun3.l.google.com:19302",
          "stun:stun4.l.google.com:19302"
        ]
      }
    ]
  };

  RTCPeerConnection? rtcPeerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;
  String? currentRoomText;
  StreamStateCallback? onAddRemoteStream;

  Future<String> createRoom(
      RTCVideoRenderer remoteRenderer, Function(String) setState) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('rooms').doc();

    print('Create PeerConnection with configuration: $configuration');

    rtcPeerConnection = await createPeerConnection(configuration);

    // if (rtcPeerConnection == null) {
    //   print("Failed to create PeerConnection");
    //   return "";
    // } else {
    //   print("PeerConnection created successfully");
    // }

    registerPeerConnectionListeners();

    localStream!.getTracks().forEach((track) {
      rtcPeerConnection?.addTrack(track, localStream!);
    });

    // Collect ICE candidates
    var callerCandidatesCollection = roomRef.collection('callerCandidates');
    rtcPeerConnection!.onIceCandidate = (candidate) async{
      print('Got candidate: ${candidate.toMap()}');
      await callerCandidatesCollection.add(candidate.toMap());
    };

    // Create a room and set offer
    RTCSessionDescription offer = await rtcPeerConnection!.createOffer();
    await rtcPeerConnection!.setLocalDescription(offer);
    print('Created offer: $offer');

    Map<String, dynamic> roomWithOffer = {'offer': offer.toMap()};
    await roomRef.set(roomWithOffer);
    roomId = roomRef.id;
    currentRoomText = 'Current room is $roomId - You are the caller!';

    rtcPeerConnection?.onTrack = (RTCTrackEvent event) async {
      print('Got remote track: ${event.streams[0]}');
      if (remoteStream == null) {
        remoteStream = await createLocalMediaStream('remote');
      }
      event.streams[0].getTracks().forEach((track) {
        print('Add a track to the remoteStream: $track');
        remoteStream?.addTrack(track);
      });
    };

    // Listening for remote session description
    roomRef.snapshots().listen((snapshot) async {
      print('Got updated room: ${snapshot.data()}');
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      if (rtcPeerConnection?.getRemoteDescription() != null &&
          data['answer'] != null) {
        var answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        print("Someone tried to connect");
        await rtcPeerConnection?.setRemoteDescription(answer);
      }
    });

    // Listen for remote Ice candidates
    roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      snapshot.docChanges.forEach((change) {
        if (change.type == DocumentChangeType.added) {
          Map<String, dynamic> data = change.doc.data() as Map<String, dynamic>;
          print('Got new remote ICE candidate: ${jsonEncode(data)}');
          rtcPeerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      });
    });

    setState(roomId!);
    return roomId!;
  }

  Future<void> joinRoom(String roomId, RTCVideoRenderer remoteRenderer) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection("rooms").doc(roomId);
    try {
      var roomSnapshot = await roomRef.get();
      print("Got snapshot ${roomSnapshot.exists}");
      if (roomSnapshot.exists) {
        rtcPeerConnection = await createPeerConnection(configuration);

        if (rtcPeerConnection == null) {
          print("Failed to create PeerConnection");
          return;
        } else {
          print("PeerConnection created successfully");
        }

        registerPeerConnectionListeners();
        localStream?.getTracks().forEach((track) {
          rtcPeerConnection?.addTrack(track);
        });

        var calleeIceCandidates = roomRef.collection("calleeCandidates");
        rtcPeerConnection?.onIceCandidate = (iceCandidates) async{
          print('Got ice candidates ${iceCandidates.toMap()}');
          await calleeIceCandidates.add(iceCandidates.toMap());
        };

        Map<String, dynamic> data = roomSnapshot.data() as Map<String, dynamic>;
        var offer = data["offer"];

        if (offer != null && offer['sdp'] != null && offer['type'] != null) {
          print("Setting Remote description...");
          await rtcPeerConnection?.setRemoteDescription(
              RTCSessionDescription(offer['sdp'], offer['type']));
          print(
              'Remote description set. Current signaling state: ${rtcPeerConnection?.signalingState}');
        } else {
          print('Offer data is invalid or null');
        }

        var answer = await rtcPeerConnection!.createAnswer();
        await rtcPeerConnection!.setLocalDescription(answer);
        print('Answer created and set: $answer');

        Map<String, dynamic> roomWithAnswer = {
          "answer": {"sdp": answer.sdp, "type": answer.type}
        };
        await roomRef.update(roomWithAnswer);

        rtcPeerConnection?.onTrack = (RTCTrackEvent event) async {
          if (remoteStream == null) {
            remoteStream = await createLocalMediaStream('remote');
          }
          event.streams[0].getTracks().forEach((track) {
            remoteStream?.addTrack(track);
          });
        };
      }

      roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
        snapshot.docChanges.forEach((changes) {
          if (changes.type == DocumentChangeType.added) {
            Map<String, dynamic> data =
                changes.doc.data() as Map<String, dynamic>;
            rtcPeerConnection?.addCandidate(RTCIceCandidate(
                data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
          }
        });
      });
    } catch (e) {
      print("Error in join room");
      print(e);
    }
  }

  Future<void> hangUp(RTCVideoRenderer localRenderer) async {
    List<MediaStreamTrack> tracks = localRenderer.srcObject!.getTracks();
    tracks.forEach((track) {
      track.stop();
    });

    if (remoteStream != null) {
      remoteStream!.getTracks().forEach((track) => track.stop());
    }

    if (rtcPeerConnection != null) {
      rtcPeerConnection!.close();
    }

    if (roomId != null) {
      var db = FirebaseFirestore.instance;
      var roomRef = db.collection("rooms").doc(roomId);
      var calleeCandidates = await roomRef.collection('calleeCandidates').get();
      calleeCandidates.docs.forEach((doc) => doc.reference.delete());

      var callerCandidates = await roomRef.collection('callerCandidates').get();
      callerCandidates.docs.forEach((doc) => doc.reference.delete());

      await roomRef.delete();
    }

    localStream!.dispose();
    remoteStream!.dispose();
  }

  Future<void> openUserMedia(RTCVideoRenderer localVideo,
      RTCVideoRenderer remoteVideo, Function(MediaStream) upState) async {
    var stream = await navigator.mediaDevices
        .getUserMedia({'video': true, 'audio': true});

    upState(stream);
    localVideo.srcObject = stream;
    localStream = stream;

    remoteVideo.srcObject = await createLocalMediaStream('key');
  }

  void registerPeerConnectionListeners() {
    rtcPeerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE gathering state changed: $state');
    };

    rtcPeerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state changed: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        print("Connection failed. Check your network or signaling.");
      }
    };

    rtcPeerConnection?.onSignalingState = (RTCSignalingState state) {
      print('Signaling state changed: $state');
    };

    rtcPeerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE connection state changed: $state');
    };

    rtcPeerConnection?.onAddStream = (MediaStream stream) {
      print("Add remote stream");
      onAddRemoteStream?.call(stream);
      remoteStream = stream;
    };
    rtcPeerConnection?.onTrack = (RTCTrackEvent event) async {
      print('Got remote track: ${event.streams[0]}');
      if (remoteStream == null) {
        remoteStream = await createLocalMediaStream('remote');
      }
      event.streams[0].getTracks().forEach((track) {
        remoteStream?.addTrack(track);
      });
    };
  }
}
