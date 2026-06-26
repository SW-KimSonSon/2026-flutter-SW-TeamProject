// /*
// import 'package:flutter/material.dart';
//
// class SubtitleBox extends StatefulWidget {
//   const SubtitleBox({super.key});
//
//   @override
//   State<SubtitleBox> createState() => _SubtitleBoxState();
// }
//
// class _SubtitleBoxState extends State<SubtitleBox> {
//   //자막 설정 변수
//   String _subtitleText = "자막 내용 입력";
//   double _sBoxWidth = 300.0;
//   double _sBoxHeight = 120.0;
//   double _sBoxOpacity = 0.9;
//   double _subtitleFontSize = 18.0;
//
//   //자막 창 위치
//   Offset _sBoxPosition = const Offset(20, 150);
//
//   final TextEditingController _textController = TextEditingController();
//
//   //설정 창
//   void _showSettingsDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setDialogState) {
//             return AlertDialog(
//               title: const Text('자막 설정'),
//               content: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text('가로 길이: ${_sBoxWidth.toInt()}'),
//                     Slider(value: _sBoxWidth, min: 100, max: 500, onChanged: (v) {
//                       setDialogState(() => _sBoxWidth = v);
//                       setState(() {});
//                     }),
//                     Text('세로 길이: ${_sBoxHeight.toInt()}'),
//                     Slider(value: _sBoxHeight, min: 50, max: 400, onChanged: (v) {
//                       setDialogState(() => _sBoxHeight = v);
//                       setState(() {});
//                     }),
//                     Text('투명도: ${(_sBoxOpacity * 100).toInt()}%'),
//                     Slider(value: _sBoxOpacity, min: 0.1, max: 1.0, onChanged: (v) {
//                       setDialogState(() => _sBoxOpacity = v);
//                       setState(() {});
//                     }),
//                     Text('글씨 크기: ${_subtitleFontSize.toInt()}'),
//                     Slider(value: _subtitleFontSize, min: 10, max: 50, onChanged: (v) {
//                       setDialogState(() => _subtitleFontSize = v);
//                       setState(() {});
//                     }),
//                   ],
//                 ),
//               ),
//               actions: [
//                 TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('수강자 페이지'),
//         backgroundColor: Colors.lightBlue,
//       ),
//       //
//       body: Stack(
//         children: [
//           //입력 창
//           Positioned(
//             top: 20,
//             left: 20,
//             right: 20,
//             child: TextField(
//               controller: _textController,
//               autofocus: true,
//               decoration: const InputDecoration(
//                 border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
//                 hintText: '자막 내용 입력.',
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   _subtitleText = value.isEmpty ? "내용 입력" : value;
//                 });
//               },
//             ),
//           ),
//
//           //자막 박스
//           Positioned(
//             left: _sBoxPosition.dx,
//             top: _sBoxPosition.dy,
//             child: GestureDetector(
//               onPanUpdate: (details) {
//                 setState(() {
//                   //드래그 하면 좌표 갱신
//                   _sBoxPosition = Offset(
//                     _sBoxPosition.dx + details.delta.dx,
//                     _sBoxPosition.dy + details.delta.dy,
//                   );
//                 });
//               },
//               child: Container(
//                 width: _sBoxWidth,
//                 height: _sBoxHeight,
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[850]!.withValues(alpha: _sBoxOpacity),
//                   border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
//                 ),
//                 child: Stack(
//                   children: [
//                     //자막 텍스트 표시
//                     Center(
//                       child: SingleChildScrollView( //
//                         child: Text(
//                           _subtitleText,
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: _subtitleFontSize,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                     //설정 버튼
//                     Positioned(
//                       top: -5,
//                       right: -5,
//                       child: IconButton(
//                         icon: const Icon(Icons.settings, color: Colors.white70, size: 22),
//                         onPressed: _showSettingsDialog,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
//  */
// import 'package:flutter/material.dart';
//
// class SubtitleBox extends StatefulWidget {
//   const SubtitleBox({super.key});
//
//   @override
//   State<SubtitleBox> createState() => _SubtitleBoxState();
// }
//
// class _SubtitleBoxState extends State<SubtitleBox> {
//   //자막 설정 변수
//   String _subtitleText = "자막 내용 입력";
//   String _summaryText = "";        // 요약버튼 추가용
//   bool _showSummary = false;      // 요약버튼 추가용
//   double _sBoxWidth = 300.0;
//   double _sBoxHeight = 120.0;
//   double _sBoxOpacity = 0.9;
//   double _subtitleFontSize = 18.0;
//
//   //자막 창 위치
//   Offset _sBoxPosition = const Offset(20, 150);
//
//   final TextEditingController _textController = TextEditingController();
//
//   //설정 창
//   void _showSettingsDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setDialogState) {
//             return AlertDialog(
//               title: const Text('자막 설정'),
//               content: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text('가로 길이: ${_sBoxWidth.toInt()}'),
//                     Slider(value: _sBoxWidth, min: 100, max: 500, onChanged: (v) {
//                       setDialogState(() => _sBoxWidth = v);
//                       setState(() {});
//                     }),
//                     Text('세로 길이: ${_sBoxHeight.toInt()}'),
//                     Slider(value: _sBoxHeight, min: 50, max: 400, onChanged: (v) {
//                       setDialogState(() => _sBoxHeight = v);
//                       setState(() {});
//                     }),
//                     Text('투명도: ${(_sBoxOpacity * 100).toInt()}%'),
//                     Slider(value: _sBoxOpacity, min: 0.1, max: 1.0, onChanged: (v) {
//                       setDialogState(() => _sBoxOpacity = v);
//                       setState(() {});
//                     }),
//                     Text('글씨 크기: ${_subtitleFontSize.toInt()}'),
//                     Slider(value: _subtitleFontSize, min: 10, max: 50, onChanged: (v) {
//                       setDialogState(() => _subtitleFontSize = v);
//                       setState(() {});
//                     }),
//                   ],
//                 ),
//               ),
//               actions: [
//                 TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('수강자 페이지'),
//         backgroundColor: Colors.lightBlue,
//       ),
//       //
//       body: Stack(
//         children: [
//           //입력 창
//           Positioned(
//             top: 20,
//             left: 20,
//             right: 20,
//             child: TextField(
//               controller: _textController,
//               autofocus: true,
//               decoration: const InputDecoration(
//                 border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
//                 hintText: '자막 내용 입력.',
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   _subtitleText = value.isEmpty ? "내용 입력" : value;
//                 });
//               },
//             ),
//           ),
//
//           //자막 박스
//           Positioned(
//             left: _sBoxPosition.dx,
//             top: _sBoxPosition.dy,
//             child: GestureDetector(
//               onPanUpdate: (details) {
//                 setState(() {
//                   //드래그 하면 좌표 갱신
//                   _sBoxPosition = Offset(
//                     _sBoxPosition.dx + details.delta.dx,
//                     _sBoxPosition.dy + details.delta.dy,
//                   );
//                 });
//               },
//               child: Container(
//                 width: _sBoxWidth,
//                 height: _sBoxHeight,
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[850]!.withValues(alpha: _sBoxOpacity),
//                   border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
//                 ),
//                 child: Stack(
//                   children: [
//                     //자막 텍스트 표시
//                     Center(
//                       child: SingleChildScrollView( //
//                         child: Text(
//                           _subtitleText,
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: _subtitleFontSize,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ),
//                     //설정 버튼
//                     Positioned(
//                       top: -5,
//                       right: -5,
//                       child: IconButton(
//                         icon: const Icon(Icons.settings, color: Colors.white70, size: 22),
//                         onPressed: _showSettingsDialog,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//
//           ),
//           // 요약 상자 출력
//           if (_showSummary)
//             Positioned(
//               right: 20,
//               bottom: 80,
//               child: Container(
//                 width: 300,
//                 height: 150,
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   border: Border.all(color: Colors.grey),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: SingleChildScrollView(
//                   child: Text(
//                     _summaryText,
//                     style: const TextStyle(fontSize: 14),
//                   ),
//                 ),
//               ),
//             ),
//           // 요약 버튼
//           Positioned(
//             right: 20,
//             bottom: 20,
//             child: ElevatedButton.icon(
//               onPressed: () {
//                 setState(() {
//                   if (_showSummary) {
//                     _showSummary = false; // 이미 열려 있으면 닫기
//                   } else {
//                     _summaryText = "요약 결과:\n${_subtitleText}";
//                     _showSummary = true; // 닫혀 있으면 열기
//                   }
//                 });
//               },
//               icon: const Icon(Icons.summarize),
//               label: const Text("요약하기"),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 foregroundColor: Colors.white,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }