import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/voice_provider.dart';
import '../theme/app_theme.dart';
import 'dart:ui';
import 'dart:math' as math;

class BingoOverlay extends ConsumerStatefulWidget {
  const BingoOverlay({super.key});

  @override
  ConsumerState<BingoOverlay> createState() => _BingoOverlayState();
}

class _BingoOverlayState extends ConsumerState<BingoOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceProvider);
    
    // Check if the overlay should be visible
    final isVisible = voiceState.feedback != VoiceAssistantState.disabled &&
                      voiceState.feedback != VoiceAssistantState.idle &&
                      voiceState.feedback != VoiceAssistantState.waitingForWakeWord;

    if (!isVisible) {
      return const SizedBox.shrink();
    }

    final isListening = voiceState.feedback == VoiceAssistantState.listeningForCommand;
    final isProcessing = voiceState.feedback == VoiceAssistantState.processing || 
                         voiceState.feedback == VoiceAssistantState.executing;
    final isError = voiceState.feedback == VoiceAssistantState.error;
    final isSuccess = voiceState.feedback == VoiceAssistantState.success;

    String displayText = 'Listening...';
    if (isListening) {
      displayText = voiceState.recognizedText.isEmpty ? 'Listening...' : voiceState.recognizedText;
    } else if (isProcessing) {
      displayText = 'Thinking...';
    } else if (voiceState.feedbackMessage.isNotEmpty) {
      displayText = voiceState.feedbackMessage;
    }

    // Determine glow color
    Color glowColor = Colors.cyanAccent;
    if (isError) glowColor = AppColors.error;
    if (isSuccess) glowColor = AppColors.primary;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: false, // Catch taps if we want to dismiss it
        child: GestureDetector(
          onTap: () {
             ref.read(voiceProvider.notifier).reset();
          },
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.9),
                  Colors.black.withOpacity(0.0),
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Glowing Edge (Alexa style)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final height = isProcessing 
                      ? 4.0 + 4.0 * _pulseController.value
                      : 6.0 + 2.0 * math.sin(_pulseController.value * math.pi);
                      
                    final intensity = isListening 
                      ? 1.0 
                      : (isProcessing ? _pulseController.value : 0.6);
                      
                    return Container(
                      height: height,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: glowColor.withOpacity(intensity),
                        boxShadow: [
                          BoxShadow(
                            color: glowColor.withOpacity(intensity * 0.8),
                            blurRadius: 20 * intensity,
                            spreadRadius: 5 * intensity,
                            offset: const Offset(0, -5),
                          )
                        ]
                      ),
                    );
                  }
                ),
                // Text Display
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isError ? Icons.error_outline : (isSuccess ? Icons.check_circle_outline : Icons.graphic_eq),
                              color: glowColor,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                displayText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
