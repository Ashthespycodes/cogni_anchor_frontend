import 'dart:io';
import 'package:cogni_anchor/presentation/constants/colors.dart' as colors;
import 'package:cogni_anchor/presentation/widgets/chatbot_page/quick_chip.dart';
import 'package:cogni_anchor/presentation/widgets/chatbot_page/toggle_button.dart';
import 'package:cogni_anchor/presentation/widgets/common/app_text.dart';
import 'package:cogni_anchor/services/chatbot_service.dart';
import 'package:cogni_anchor/services/conversation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatbotPageFunctional extends StatefulWidget {
  const ChatbotPageFunctional({super.key});

  @override
  State<ChatbotPageFunctional> createState() => _ChatbotPageFunctionalState();
}

class _ChatbotPageFunctionalState extends State<ChatbotPageFunctional> {
  bool isAudio = false; // Start with text mode
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ConversationService _conversationService = ConversationService();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // Voice recording
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  bool _recorderInitialized = false;
  String? _recordingPath;

  // Get actual user ID from Supabase auth
  String get patientId {
    final user = Supabase.instance.client.auth.currentUser;
    return user?.id ?? "demo_patient_001";
  }

  @override
  void initState() {
    super.initState();
    _initRecorder();
    // Load existing conversation from service
    _messages = _conversationService.getConversation(patientId);
  }

  Future<void> _initRecorder() async {
    try {
      await _audioRecorder.openRecorder();
      _recorderInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize recorder: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_recorderInitialized) {
      _audioRecorder.closeRecorder();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final userMessage = ChatMessage(
      text: message,
      isBot: false,
      timestamp: DateTime.now(),
    );

    _conversationService.addMessage(patientId, userMessage);

    setState(() {
      _messages = _conversationService.getConversation(patientId);
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await ChatbotService.sendTextMessage(
        patientId: patientId,
        message: message,
      );

      if (mounted) {
        final botMessage = ChatMessage(
          text: response,
          isBot: true,
          timestamp: DateTime.now(),
        );

        _conversationService.addMessage(patientId, botMessage);

        setState(() {
          _messages = _conversationService.getConversation(patientId);
          _isLoading = false;
        });

        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = ChatMessage(
          text: "Sorry, I couldn't process your message. Please check your connection and try again.",
          isBot: true,
          timestamp: DateTime.now(),
          isError: true,
        );

        _conversationService.addMessage(patientId, errorMessage);

        setState(() {
          _messages = _conversationService.getConversation(patientId);
          _isLoading = false;
        });
      }

      _scrollToBottom();

      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleQuickAction(String action) {
    _sendMessage(action);
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for voice chat'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        await _requestMicrophonePermission();
        return;
      }

      if (!_recorderInitialized) {
        await _initRecorder();
      }

      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String filePath = '${appDocDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _audioRecorder.startRecorder(
        toFile: filePath,
        codec: Codec.aacADTS,
      );

      setState(() {
        _isRecording = true;
        _recordingPath = filePath;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });

      if (_recordingPath != null) {
        await _sendVoiceMessage(_recordingPath!);
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendVoiceMessage(String audioPath) async {
    final voiceMessage = ChatMessage(
      text: "🎤 Voice message sent",
      isBot: false,
      timestamp: DateTime.now(),
    );

    _conversationService.addMessage(patientId, voiceMessage);

    setState(() {
      _messages = _conversationService.getConversation(patientId);
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final audioFile = File(audioPath);
      final audioBytes = await audioFile.readAsBytes();

      final response = await ChatbotService.sendVoiceMessage(
        patientId: patientId,
        audioBytes: audioBytes,
        filename: 'voice_message.aac',
      );

      // Remove the temporary voice message and add the transcribed one
      final messages = _conversationService.getConversation(patientId);
      messages.removeLast();

      final transcribedMessage = ChatMessage(
        text: "🎤 ${response['transcription']}",
        isBot: false,
        timestamp: voiceMessage.timestamp,
      );

      _conversationService.addMessage(patientId, transcribedMessage);

      final botMessage = ChatMessage(
        text: response['response'] as String,
        isBot: true,
        timestamp: DateTime.now(),
        audioUrl: response['audio_url'] as String?,
      );

      _conversationService.addMessage(patientId, botMessage);

      setState(() {
        _messages = _conversationService.getConversation(patientId);
        _isLoading = false;
      });

      _scrollToBottom();

      // Auto-play the response audio if available
      if (response['audio_url'] != null) {
        final audioUrl = response['audio_url'] as String;
        if (audioUrl.isNotEmpty) {
          await _playAudio(audioUrl);
        }
      }
    } catch (e) {
      final errorMessage = ChatMessage(
        text: "Sorry, I couldn't process your voice message. Please try again.",
        isBot: true,
        timestamp: DateTime.now(),
        isError: true,
      );

      _conversationService.addMessage(patientId, errorMessage);

      setState(() {
        _messages = _conversationService.getConversation(patientId);
        _isLoading = false;
      });

      _scrollToBottom();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _playAudio(String audioUrl) async {
    try {
      // If it's a relative URL, prepend the base URL
      final fullUrl = audioUrl.startsWith('http')
          ? audioUrl
          : 'http://10.0.2.2:8000$audioUrl';

      await _audioPlayer.play(UrlSource(fullUrl));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppbar(),
      body: Column(
        children: [
          Gap(20.h),

          // Mode toggle (Audio/Text)
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ToggleButton(
                  label: "Audio",
                  selected: isAudio,
                  onTap: () => setState(() => isAudio = true),
                ),
                Gap(12.w),
                ToggleButton(
                  label: "Text",
                  selected: !isAudio,
                  onTap: () => setState(() => isAudio = false),
                ),
              ],
            ),
          ),

          Gap(20.h),

          // Quick action suggestions
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.fluorescent_rounded, color: colors.appColor.withValues(alpha: 0.7)),
                    Gap(10.w),
                    Expanded(
                      child: AppText(
                        "Quick actions to get started:",
                        fontSize: 15.sp,
                      ),
                    ),
                  ],
                ),
                Gap(14.h),
                Wrap(
                  spacing: 10.w,
                  runSpacing: 12.h,
                  children: [
                    GestureDetector(
                      onTap: () => _handleQuickAction("I'm feeling confused today"),
                      child: const QuickChip("I'm feeling confused"),
                    ),
                    GestureDetector(
                      onTap: () => _handleQuickAction("What day is it today?"),
                      child: const QuickChip("What day is it?"),
                    ),
                    GestureDetector(
                      onTap: () => _handleQuickAction("I need help remembering something"),
                      child: const QuickChip("Help me remember"),
                    ),
                    GestureDetector(
                      onTap: () => _handleQuickAction("Tell me a calming story"),
                      child: const QuickChip("Tell me a story"),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Gap(20.h),

          // Chat messages area
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 18.w),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: _messages.isEmpty
                  ? Center(
                      child: AppText(
                        "Start chatting...",
                        fontSize: 16.sp,
                        color: Colors.grey,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(16.w),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isLoading) {
                          return _buildLoadingBubble();
                        }
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),
          ),

          Gap(15.h),

          // Input area
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w),
            child: isAudio ? _buildAudioInputBox() : _buildTextInputBox(),
          ),

          Gap(15.h),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        constraints: BoxConstraints(maxWidth: 280.w),
        decoration: BoxDecoration(
          color: message.isBot
              ? (message.isError ? Colors.red[100] : Colors.white)
              : colors.appColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AppText(
          message.text,
          fontSize: 14.sp,
          color: message.isBot ? Colors.black87 : Colors.white,
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16.w,
              height: 16.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colors.appColor),
              ),
            ),
            Gap(10.w),
            AppText("Thinking...", fontSize: 14.sp, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInputBox() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Type your message...",
              ),
              onSubmitted: _sendMessage,
              enabled: !_isLoading,
            ),
          ),
        ),
        Gap(12.w),
        GestureDetector(
          onTap: _isLoading ? null : () => _sendMessage(_messageController.text),
          child: Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              color: _isLoading ? Colors.grey : colors.appColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.send,
              color: Colors.white,
              size: 24.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioInputBox() {
    return Center(
      child: Column(
        children: [
          if (_isRecording)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12.w,
                    height: 12.w,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Gap(8.w),
                  AppText(
                    "Recording...",
                    fontSize: 14.sp,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTapDown: (_) {
              if (!_isLoading && !_isRecording) {
                _startRecording();
              }
            },
            onTapUp: (_) {
              if (_isRecording) {
                _stopRecording();
              }
            },
            onTapCancel: () {
              if (_isRecording) {
                _stopRecording();
              }
            },
            child: Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                color: _isRecording
                    ? Colors.red
                    : (_isLoading ? Colors.grey : colors.appColor),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _isRecording
                        ? Colors.red.withValues(alpha: 0.3)
                        : colors.appColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 40.sp,
              ),
            ),
          ),
          Gap(12.h),
          AppText(
            _isRecording
                ? "Tap to stop recording"
                : "Tap and hold to record",
            fontSize: 13.sp,
            color: Colors.grey[600] ?? Colors.grey,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppbar() {
    return PreferredSize(
      preferredSize: Size.fromHeight(70.h),
      child: AppBar(
        elevation: 0,
        backgroundColor: colors.appColor,
        centerTitle: true,
        automaticallyImplyLeading: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20.r),
            bottomRight: Radius.circular(20.r),
          ),
        ),
        title: AppText(
          "Chatbot AI",
          fontSize: 20.sp,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _conversationService.clearConversation(patientId);
              setState(() {
                _messages = _conversationService.getConversation(patientId);
              });
            },
          ),
        ],
      ),
    );
  }
}

