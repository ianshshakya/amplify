import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/voice_provider.dart';
import 'dart:math' as math;

class AskJuluScreen extends ConsumerStatefulWidget {
  const AskJuluScreen({super.key});

  @override
  ConsumerState<AskJuluScreen> createState() => _AskJuluScreenState();
}

class _AskJuluScreenState extends ConsumerState<AskJuluScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceProvider);
    final voiceNotifier = ref.read(voiceProvider.notifier);
    
    final isListening = voiceState.feedback == VoiceFeedback.listening;
    final isProcessing = voiceState.feedback == VoiceFeedback.processing;
    final isError = voiceState.feedback == VoiceFeedback.error;
    
    String displayText = 'Tap to speak';
    if (isListening) {
      displayText = voiceState.recognizedText.isEmpty ? 'Listening...' : voiceState.recognizedText;
    } else if (isProcessing) {
      displayText = 'Thinking...';
    } else if (voiceState.feedbackMessage.isNotEmpty) {
      displayText = voiceState.feedbackMessage;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            // Siri-like dynamic text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AnimatedSwitcher(
                duration: AppDurations.medium,
                child: Text(
                  displayText,
                  key: ValueKey(displayText),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isError ? AppColors.error : AppColors.textPrimary,
                    fontSize: isListening && voiceState.recognizedText.isNotEmpty ? 28 : 24,
                    fontWeight: isListening ? FontWeight.w400 : FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            const Spacer(),
            
            // Central Orb
            GestureDetector(
              onTap: () => voiceNotifier.toggleListening(),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final double pulseScale = isListening 
                      ? 1.0 + 0.3 * math.sin(_pulseController.value * 2 * math.pi)
                      : (isProcessing ? 1.0 + 0.1 * math.sin(_pulseController.value * 4 * math.pi) : 1.0);
                  
                  return Transform.scale(
                    scale: pulseScale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: isListening
                              ? [AppColors.primary, AppColors.primaryDark]
                              : [AppColors.surfaceHighlight, AppColors.surface],
                        ),
                        boxShadow: [
                          if (isListening || isProcessing)
                            BoxShadow(
                              color: AppColors.primary.withOpacity(isListening ? 0.6 : 0.3),
                              blurRadius: isListening ? 40 : 20,
                              spreadRadius: isListening ? 10 : 5,
                            )
                        ],
                      ),
                      child: Icon(
                        isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  );
                },
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
