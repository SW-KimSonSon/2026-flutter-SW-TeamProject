//
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:speech_to_text/speech_to_text.dart';
// import 'package:speech_to_text/speech_recognition_result.dart';
//
// class ScreenShare extends StatefulWidget {
//   const ScreenShare({super.key});
//
//   @override
//   State<ScreenShare> createState() => _ScreenShareState();
// }
//
// class _ScreenShareState extends State<ScreenShare> {
//   final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
//   MediaStream? _localStream;
//   bool _isSharing = false;
//
//   //STT 변수
//   final SpeechToText _speechToText = SpeechToText();
//   bool _speechEnable = false;
//   String _subtitle = "";
//   String _allSubtitle = "";
//
//   Timer? _silenceTimer;
//
//   @override
//   void initState() {
//     super.initState();
//     _initRenderer();
//     _initSpeech();
//   }
//
//   @override
//   void dispose() {
//     _localRenderer.dispose();
//     _localStream?.dispose();
//     _silenceTimer?.cancel();
//     _stopListening();
//     super.dispose();
//   }
//
//   Future<void> _initRenderer() async {
//     await _localRenderer.initialize();
//   }
//
//   //음성 초기화
//   Future<void> _initSpeech() async {
//     try {
//       _speechEnable = await _speechToText.initialize(
//         onStatus: (status) {
//           debugPrint('STT 상태: $status');
//           if (_isSharing && (status == 'done' || status == 'notListening')) {
//             Future.delayed(const Duration(milliseconds: 100),(){
//               _startListening();
//             });
//           }
//         },
//         onError: (errorNotification) => debugPrint('STT 에러: $errorNotification'),
//       );
//       setState(() {});
//     } catch (e) {
//       debugPrint('STT 초기화 실패: $e');
//     }
//   }
//
//   void _startListening() async {
//     if (_speechEnable && _isSharing) {
//       await _speechToText.listen(
//         onResult: _onSpeechResult,
//         localeId: 'ko_KR',
//         listenOptions: SpeechListenOptions(
//           cancelOnError: true,
//           partialResults: true,
//           listenMode: ListenMode.dictation,
//         ),
//       );
//       setState(() {});
//     }
//   }
//
//   void _stopListening() async {
//     _silenceTimer?.cancel();
//     await _speechToText.stop();
//     setState(() {
//     });
//   }
//
//   //실시간 인식
//   void _onSpeechResult(SpeechRecognitionResult result) {
//     //새로운 음성이 인식되면 기존 타이머 취소
//     _silenceTimer?.cancel();
//
//     setState(() {
//       _subtitle = result.recognizedWords;
//       if (result.finalResult) {
//         _subtitle = "";
//       }
//     });
//
//     //3초간 말이 없으면 자막 초기화
//     _silenceTimer = Timer(const Duration(seconds: 3), () {
//       if (mounted) {
//         setState(() {
//           _allSubtitle += _subtitle;
//           _allSubtitle += ". ";
//           _subtitle = ""; //자막 비우기
//         });
//         _speechToText.stop();
//       }
//     });
//   }
//
//   Future<void> _startShare() async {
//     try {
//       final Map<String, dynamic> mediaConstraints = {
//         'audio': false,
//         'video': {'frameRate': 30}
//       };
//
//       MediaStream stream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
//
//       //마이크 소리 가져오기
//       final Map<String, dynamic> userConstraints = {
//         'audio': {
//           'echoCancellation': true,
//           'noiseSuppression': true,
//           'autoGainControl': true,
//         },
//         'video': false,
//       };
//       MediaStream soundStream = await navigator.mediaDevices.getUserMedia(userConstraints);
//
//       if (soundStream.getAudioTracks().isNotEmpty) {
//         //마이크 트랙 추가
//         stream.addTrack(soundStream.getAudioTracks()[0]);
//       }
//
//       setState(() {
//         _localStream = stream;
//         _localRenderer.srcObject = _localStream;
//         _localRenderer.muted = false; //로컬 음소거 false
//         _isSharing = true;
//         _allSubtitle = "";
//       });
//
//       _localStream!.getAudioTracks().forEach((track) {
//         track.enabled = true;
//       });
//
//       _startListening();
//
//     } catch (e) {
//       debugPrint('화면 캡처 오류: $e');
//     }
//   }
//
//   void _stopShare() {
//     _allSubtitle += _subtitle;
//
//     _localStream?.getTracks().forEach((track) => track.stop());
//     _localStream?.dispose();
//     _stopListening();
//
//     setState(() {
//       _localStream = null;
//       _localRenderer.srcObject = null;
//       _isSharing = false;
//       //_subtitle = "전체 자막: $_allSubtitle";
//       _subtitle="";
//       debugPrint('전체 자막: $_allSubtitle');
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('강의자 페이지'),
//         backgroundColor: Colors.lightBlue,
//       ),
//       body: Column(
//         children: [
//           const SizedBox(height: 20),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               ElevatedButton.icon(
//                 onPressed: _isSharing ? null : _startShare,
//                 icon: const Icon(Icons.screen_share),
//                 label: const Text('화면 공유 시작'),
//               ),
//               const SizedBox(width: 15),
//               ElevatedButton.icon(
//                 onPressed: _isSharing ? _stopShare : null,
//                 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                 icon: const Icon(Icons.stop_screen_share, color: Colors.white),
//                 label: const Text('화면 공유 중지', style: TextStyle(color: Colors.white)),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//
//           //영상 출력
//           Expanded(
//             child: Container(
//               margin: const EdgeInsets.all(15),
//               decoration: BoxDecoration(
//                 color: Colors.black,
//                 border: Border.all(color: Colors.grey, width: 2),
//               ),
//               child: RTCVideoView(
//                 _localRenderer,
//                 mirror: false,
//                 objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
//               ),
//             ),
//           ),
//
//           //실시간 자막
//           Container(
//             padding: const EdgeInsets.all(20),
//             child: Text(
//               _subtitle,
//               style: const TextStyle(
//                 //color: Colors.black,
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ),
//           const SizedBox(height: 10),
//         ],
//       ),
//     );
//   }
// }