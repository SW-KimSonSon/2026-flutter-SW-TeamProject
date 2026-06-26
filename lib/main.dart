import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:desktop_audio_capture/audio_capture.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LectureScreen(),
    );
  }
}

class LectureScreen extends StatefulWidget {
  const LectureScreen({super.key});

  @override
  State<LectureScreen> createState() => _LectureScreenState();
}

class _LectureScreenState extends State<LectureScreen> {
  // 화면 공유
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  MediaStream? _stream;
  bool _isSharing = false;
  bool _isProcessingSTT = false;

  final ValueNotifier<String> _subtitleNotifier = ValueNotifier<String>("");
  final ValueNotifier<String> _finalSubtitleNotifier =
  ValueNotifier<String>("");
  final ValueNotifier<Offset> _boxPositionNotifier =
  ValueNotifier<Offset>(const Offset(50, 200));

  double _boxW = 300.0;
  double _boxH = 120.0;
  double _boxOpacity = 0.6;
  double _subtitleFontSize = 18.0;

  // whisper 프롬프트 실시간 제어용
  final TextEditingController _promptController = TextEditingController(
    text: "",
  );

  // AI 요약 / 질문 기능
  //geminiApiKey 입력 필요
  static const String _geminiApiKey = "";

  String _summaryText = "";
  bool _showSummary = false;
  bool _isSummarizing = false;

  double _summaryBoxWidth = 330.0;
  double _summaryBoxHeight = 190.0;
  Offset _summaryBoxPosition = const Offset(600, 300);

  final TextEditingController _questionController = TextEditingController();

  // 오디오 캡쳐 설정
  SystemAudioCapture? _systemAudioCapture;
  final List<int> _audioBuffer = [];
  StreamSubscription? _audioSubscription;
  Timer? _sttTimer;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    _renderer.initialize();
  }

  @override
  void dispose() {
    _renderer.dispose();
    _stream?.dispose();
    _sttTimer?.cancel();
    _audioSubscription?.cancel();
    _systemAudioCapture?.stopCapture();

    _subtitleNotifier.dispose();
    _finalSubtitleNotifier.dispose();
    _boxPositionNotifier.dispose();

    _promptController.dispose();
    _questionController.dispose();

    super.dispose();
  }

  // 자막 설정창
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('자막 설정'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('가로 길이: ${_boxW.toInt()}'),
                    Slider(
                      value: _boxW,
                      min: 150,
                      max: 600,
                      onChanged: (v) {
                        setDialogState(() => _boxW = v);
                        setState(() {});
                      },
                    ),
                    Text('세로 길이: ${_boxH.toInt()}'),
                    Slider(
                      value: _boxH,
                      min: 50,
                      max: 400,
                      onChanged: (v) {
                        setDialogState(() => _boxH = v);
                        setState(() {});
                      },
                    ),
                    Text('투명도: ${(_boxOpacity * 100).toInt()}%'),
                    Slider(
                      value: _boxOpacity,
                      min: 0.1,
                      max: 1.0,
                      onChanged: (v) {
                        setDialogState(() => _boxOpacity = v);
                        setState(() {});
                      },
                    ),
                    Text('글씨 크기: ${_subtitleFontSize.toInt()}'),
                    Slider(
                      value: _subtitleFontSize,
                      min: 10,
                      max: 40,
                      onChanged: (v) {
                        setDialogState(() => _subtitleFontSize = v);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 현재까지 누적된 자막 가져오기
  String _getCurrentTranscript() {
    final finalText = _finalSubtitleNotifier.value.trim();
    final currentText = _subtitleNotifier.value.trim();

    if (finalText.isNotEmpty) {
      return finalText;
    }

    if (currentText.isNotEmpty) {
      return currentText;
    }

    return "";
  }

  // Gemini API 공통 호출 함수
  Future<String> _requestGemini(String prompt) async {
    if (_geminiApiKey.trim().isEmpty || _geminiApiKey.contains("여기에")) {
      return "Gemini API 키를 먼저 입력해주세요.";
    }

    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent",
    );

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": _geminiApiKey,
        },
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        return "API 오류가 발생했습니다.\n상태 코드: ${response.statusCode}\n${response.body}";
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final candidates = data["candidates"] as List?;
      if (candidates == null || candidates.isEmpty) {
        return "AI 응답을 찾지 못했습니다.";
      }

      final firstCandidate = candidates[0] as Map<String, dynamic>;
      final content = firstCandidate["content"] as Map<String, dynamic>?;
      final parts = content?["parts"] as List?;

      if (parts == null || parts.isEmpty) {
        return "AI 응답 내용이 비어 있습니다.";
      }

      final firstPart = parts[0] as Map<String, dynamic>;
      final resultText = firstPart["text"]?.toString();

      if (resultText == null || resultText.trim().isEmpty) {
        return "AI 응답 결과가 비어 있습니다.";
      }

      return resultText;
    } catch (e) {
      return "AI 요청 중 오류가 발생했습니다.\n$e";
    }
  }

  // AI 요약 함수
  Future<String> _summarizeWithGemini(String text) async {
    if (text.trim().isEmpty) {
      return "요약할 자막 내용이 없습니다.";
    }

    final prompt = """
아래 강의 자막 내용을 학생이 복습하기 쉽게 요약해주세요.

조건:
1. 핵심 내용을 3~5줄로 요약
2. 중요한 개념은 따로 키워드로 정리
3. 너무 길게 쓰지 말 것
4. 한국어로 답변

[강의 자막]
$text
""";

    return await _requestGemini(prompt);
  }

  // AI 질문 답변 함수
  Future<String> _askWithGemini(String transcript, String question) async {
    if (transcript.trim().isEmpty) {
      return "질문에 사용할 자막 내용이 없습니다.";
    }

    if (question.trim().isEmpty) {
      return "질문을 입력해주세요.";
    }

    final prompt = """
아래 강의 자막 내용을 참고해서 학생의 질문에 답변해주세요.

조건:
1. 강의 자막 내용을 기준으로 답변
2. 자막에 없는 내용은 추측하지 말고, 자막에 없는 내용이라고 말하기
3. 학생이 이해하기 쉽게 한국어로 설명
4. 너무 길지 않게 핵심 위주로 답변

[강의 자막]
$transcript

[학생 질문]
$question
""";

    return await _requestGemini(prompt);
  }

  // 질문 입력 팝업
  void _showQuestionDialog() {
    _questionController.clear();

    String answerText = "질문을 입력한 뒤 질문하기 버튼을 눌러주세요.";
    bool isAnswering = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("AI에게 질문하기"),
              content: SizedBox(
                width: 520,
                height: 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "강의 자막 내용을 기준으로 질문합니다.",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _questionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "예: CPU 스케줄링이 뭐야?",
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: isAnswering
                            ? null
                            : () async {
                          final question =
                          _questionController.text.trim();

                          if (question.isEmpty) {
                            setDialogState(() {
                              answerText = "질문을 입력해주세요.";
                            });
                            return;
                          }

                          setDialogState(() {
                            isAnswering = true;
                            answerText = "AI 답변 생성 중입니다...";
                          });

                          final result = await _askWithGemini(
                            _getCurrentTranscript(),
                            question,
                          );

                          if (!mounted) return;

                          setDialogState(() {
                            answerText = result;
                            isAnswering = false;
                          });
                        },
                        icon: const Icon(Icons.question_answer),
                        label: Text(isAnswering ? "답변 중..." : "질문하기"),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            answerText,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("닫기"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 화면 공유 시작
  Future<void> _startShare() async {
    try {
      String? selectedSourceId;

      if (Platform.isWindows) {
        List<DesktopCapturerSource> sources =
        await desktopCapturer.getSources(
          types: [SourceType.Screen, SourceType.Window],
        );

        if (mounted) {
          selectedSourceId = await _showSelectionDialog(context, sources);
        }

        if (selectedSourceId == null) return;
      }

      final Map<String, dynamic> mediaConstraints = {
        'audio': false,
        'video': selectedSourceId != null
            ? {
          'deviceId': {'exact': selectedSourceId},
          'mandatory': {
            'frameRate': 30,
            'minWidth': 1280,
            'minHeight': 720,
          },
        }
            : true,
      };

      final stream =
      await navigator.mediaDevices.getDisplayMedia(mediaConstraints);

      setState(() {
        _stream = stream;
        _renderer.srcObject = stream;
        _isSharing = true;
        _finalSubtitleNotifier.value = "";
        _subtitleNotifier.value = "";
      });

      _startRecordingLoop();
    } catch (e) {
      debugPrint("화면 공유 오류: $e");
    }
  }

  // 공유할 화면 선택
  Future<String?> _showSelectionDialog(
      BuildContext context,
      List<DesktopCapturerSource> sources,
      ) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("공유할 화면 선택"),
          content: SizedBox(
            width: 500,
            height: 400,
            child: ListView.builder(
              itemCount: sources.length,
              itemBuilder: (context, index) {
                final source = sources[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Text(
                      source.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(source.id);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text("취소"),
            ),
          ],
        );
      },
    );
  }

  void _stopShare() {
    _stream?.getTracks().forEach((t) => t.stop());
    _stream?.dispose();

    _sttTimer?.cancel();
    _audioSubscription?.cancel();
    _systemAudioCapture?.stopCapture();

    setState(() {
      _stream = null;
      _renderer.srcObject = null;
      _isSharing = false;
      _subtitleNotifier.value = "";
    });
  }

  // 컴퓨터 소리 녹음 시작
  Future<void> _startRecordingLoop() async {
    _sttTimer?.cancel();
    _audioSubscription?.cancel();
    await _systemAudioCapture?.stopCapture();
    _audioBuffer.clear();

    _isProcessingSTT = false;

    final dir = await getApplicationDocumentsDirectory();
    _audioPath = "${dir.path}${Platform.pathSeparator}audio.wav";

    _systemAudioCapture = SystemAudioCapture(
      config: SystemAudioConfig(
        sampleRate: 44100,
        channels: 1,
      ),
    );

    await _systemAudioCapture!.startCapture();
    _audioSubscription = _systemAudioCapture!.audioStream?.listen((audioData) {
      _audioBuffer.addAll(audioData);
    });

    _sttTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _processWhisperFromBuffer();
    });
  }

  Future<void> _processWhisperFromBuffer() async {
    if (_isProcessingSTT) {
      print("이전 Whisper 분석이 끝나지 않음");
      return;
    }

    if (_audioBuffer.isEmpty || _audioPath == null) {
      print("오디오 버퍼 empty");
      _subtitleNotifier.value = "";
      return;
    }

    _isProcessingSTT = true;

    try {
      final currentBuffer = List<int>.from(_audioBuffer);
      _audioBuffer.clear();

      final file = File(_audioPath!);
      final header =
      _createWavHeader(currentBuffer.length, sampleRate: 44100, channels: 1);
      await file.writeAsBytes(header + currentBuffer);

      final projectRoot = Directory.current.path;
      final exePath =
          "$projectRoot${Platform.pathSeparator}whisper.cpp${Platform.pathSeparator}whisper-blas-bin-x64${Platform.pathSeparator}Release${Platform.pathSeparator}whisper-cli.exe";
      final modelPath =
          "$projectRoot${Platform.pathSeparator}whisper.cpp${Platform.pathSeparator}models${Platform.pathSeparator}ggml-base.bin";

      final exeFile = File(exePath);
      final modelFile = File(modelPath);

      if (!exeFile.existsSync() || !modelFile.existsSync()) {
        print("파일 존재 검증 실패로 Whisper 작동 일시 중단.");
        return;
      }

      final currentPrompt = _promptController.text.trim();

      final result = await Process.run(
        exePath,
        [
          "-m",
          modelPath,
          "-f",
          _audioPath!,
          "-l",
          "ko",
          "-nt",
          "-t",
          "8",
          if (currentPrompt.isNotEmpty) ...[
            "--prompt",
            currentPrompt,
          ],
        ],
        stdoutEncoding: utf8,
      );

      if (result.exitCode == 0) {
        String text = result.stdout.toString().trim();

        final lines = text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

        if (lines.isNotEmpty) {
          text = lines.first;
        } else {
          text = "";
        }

        text = text.replaceAll(RegExp(r'\[.*?\]|\(.*?\)|<.*?>'), '').trim();

        if (text.isNotEmpty) {
          print("인식된 영상 소리: $text");
          _subtitleNotifier.value = text;
          _finalSubtitleNotifier.value += "$text ";
        } else {
          print("무음 상태");
          _subtitleNotifier.value = "";
        }
      } else {
        print("Whisper 실행 실패 (Exit Code: ${result.exitCode})");
        _subtitleNotifier.value = "";
      }
    } catch (e) {
      print("오류 발생: $e");
      _subtitleNotifier.value = "";
    } finally {
      _isProcessingSTT = false;
    }
  }

  List<int> _createWavHeader(
      int pcmLength, {
        int sampleRate = 44100,
        int channels = 2,
      }) {
    final int byteRate = sampleRate * channels * 2;
    final int blockAlign = channels * 2;
    final int fileSize = 36 + pcmLength;

    final header = ByteData(44);
    header.setUint32(0, 0x52494646, Endian.big);
    header.setUint32(4, fileSize, Endian.little);
    header.setUint32(8, 0x57415645, Endian.big);
    header.setUint32(12, 0x666d7420, Endian.big);
    header.setUint16(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint32(36, 0x64617461, Endian.big);
    header.setUint32(40, pcmLength, Endian.little);

    return header.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isSharing ? null : _startShare,
                child: const Text("화면 공유 시작"),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isSharing ? _stopShare : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("중지"),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 실시간 프롬프트 가이드 입력창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                labelText: "실시간 자막 프롬프트",
                hintText: "자주 틀리는 고유 명사, 상황 등을 적어두면 오인식이 줄어듭니다.",
                border: OutlineInputBorder(),
                contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 1,
              style: const TextStyle(fontSize: 13),
            ),
          ),

          const SizedBox(height: 10),

          // 화면 + 자막 Stack
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // 화면
                    Container(
                      margin: const EdgeInsets.all(10),
                      color: Colors.black,
                      child: RTCVideoView(
                        _renderer,
                        objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      ),
                    ),

                    // 자막 박스
                    if (_isSharing)
                      ValueListenableBuilder<Offset>(
                        valueListenable: _boxPositionNotifier,
                        builder: (context, boxPosition, child) {
                          return Positioned(
                            left: boxPosition.dx,
                            top: boxPosition.dy,
                            child: GestureDetector(
                              onPanUpdate: (d) {
                                final maxX = constraints.maxWidth - _boxW;
                                final maxY = constraints.maxHeight - _boxH;

                                double x =
                                    _boxPositionNotifier.value.dx + d.delta.dx;
                                double y =
                                    _boxPositionNotifier.value.dy + d.delta.dy;

                                x = x.clamp(0, maxX).toDouble();
                                y = y.clamp(0, maxY).toDouble();

                                _boxPositionNotifier.value = Offset(x, y);
                              },
                              child: Container(
                                width: _boxW,
                                height: _boxH,
                                decoration: BoxDecoration(
                                  color: Colors.black
                                      .withValues(alpha: _boxOpacity),
                                  border: Border.all(
                                    color:
                                    Colors.white.withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 10,
                                          right: 30,
                                          left: 10,
                                          bottom: 10,
                                        ),
                                        child: ValueListenableBuilder<String>(
                                          valueListenable: _subtitleNotifier,
                                          builder: (context, subtitle, child) {
                                            return SingleChildScrollView(
                                              child: Text(
                                                subtitle,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: _subtitleFontSize,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.settings,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                        onPressed: _showSettingsDialog,
                                        tooltip: "자막 설정",
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    // 요약 상자 출력
                    if (_showSummary)
                      Positioned(
                        left: _summaryBoxPosition.dx,
                        top: _summaryBoxPosition.dy,
                        child: SizedBox(
                          width: _summaryBoxWidth,
                          height: _summaryBoxHeight,
                          child: Stack(
                            children: [
                              Container(
                                width: _summaryBoxWidth,
                                height: _summaryBoxHeight,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    GestureDetector(
                                      onPanUpdate: (details) {
                                        setState(() {
                                          double x =
                                              _summaryBoxPosition.dx +
                                                  details.delta.dx;
                                          double y =
                                              _summaryBoxPosition.dy +
                                                  details.delta.dy;

                                          final maxX = constraints.maxWidth -
                                              _summaryBoxWidth;
                                          final maxY = constraints.maxHeight -
                                              _summaryBoxHeight;

                                          if (maxX > 0) {
                                            x = x.clamp(0, maxX).toDouble();
                                          } else {
                                            x = 0;
                                          }

                                          if (maxY > 0) {
                                            y = y.clamp(0, maxY).toDouble();
                                          } else {
                                            y = 0;
                                          }

                                          _summaryBoxPosition = Offset(x, y);
                                        });
                                      },
                                      child: Container(
                                        height: 32,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius:
                                          const BorderRadius.only(
                                            topLeft: Radius.circular(8),
                                            topRight: Radius.circular(8),
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.open_with, size: 16),
                                            SizedBox(width: 6),
                                            Text(
                                              "AI 요약 결과",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          _summaryText,
                                          style:
                                          const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onPanUpdate: (details) {
                                    setState(() {
                                      _summaryBoxWidth =
                                          (_summaryBoxWidth + details.delta.dx)
                                              .clamp(220.0, 700.0)
                                              .toDouble();

                                      _summaryBoxHeight =
                                          (_summaryBoxHeight + details.delta.dy)
                                              .clamp(120.0, 500.0)
                                              .toDouble();
                                    });
                                  },
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    alignment: Alignment.bottomRight,
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.drag_handle,
                                      size: 20,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 질문 버튼
                    Positioned(
                      right: 170,
                      bottom: 20,
                      child: ElevatedButton.icon(
                        onPressed: _showQuestionDialog,
                        icon: const Icon(Icons.question_answer),
                        label: const Text("AI 질문하기"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),

                    // 요약 버튼
                    Positioned(
                      right: 20,
                      bottom: 20,
                      child: ElevatedButton.icon(
                        onPressed: _isSummarizing
                            ? null
                            : () async {
                          if (_showSummary) {
                            setState(() {
                              _showSummary = false;
                            });
                            return;
                          }

                          double startX = constraints.maxWidth -
                              _summaryBoxWidth -
                              20;
                          double startY = constraints.maxHeight -
                              _summaryBoxHeight -
                              80;

                          if (startX < 0) startX = 0;
                          if (startY < 0) startY = 0;

                          setState(() {
                            _summaryBoxPosition =
                                Offset(startX, startY);
                            _showSummary = true;
                            _isSummarizing = true;
                            _summaryText = "AI 요약 중입니다...";
                          });

                          final result = await _summarizeWithGemini(
                            _getCurrentTranscript(),
                          );

                          if (!mounted) return;

                          setState(() {
                            _summaryText = result;
                            _isSummarizing = false;
                          });
                        },
                        icon: const Icon(Icons.summarize),
                        label: Text(
                          _isSummarizing
                              ? "요약 중..."
                              : (_showSummary ? "요약 닫기" : "AI 요약하기"),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}