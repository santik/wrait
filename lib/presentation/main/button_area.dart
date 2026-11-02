import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/adaptive_button_size.dart';
import '../theme/design_tokens.dart';
import 'countdown_ring.dart';
import 'main_screen_test_keys.dart';
import 'pulse_ring.dart';
import 'recording_state.dart';

class ButtonArea extends StatefulWidget {
  const ButtonArea({
    required this.recordingState,
    required this.shakeErrorKey,
    required this.buttonLabel,
    required this.onPressed,
    this.countdownProgress,
    this.pulseDiameter,
    super.key,
  });

  final RecordingState recordingState;
  final int shakeErrorKey;
  final String buttonLabel;
  final VoidCallback onPressed;
  final double? countdownProgress;
  final double? pulseDiameter;

  @override
  State<ButtonArea> createState() => _ButtonAreaState();
}

class _ButtonAreaState extends State<ButtonArea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: WraitAnimationTokens.buttonShake,
  );

  @override
  void didUpdateWidget(covariant ButtonArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shakeErrorKey != widget.shakeErrorKey) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isListening = widget.recordingState is RecordingListening;
    final isDisabled =
        widget.recordingState is RecordingUploading ||
        widget.recordingState is RecordingProcessing;

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonSize = AdaptiveButtonSize.forWidth(constraints.maxWidth);
        final pulseEndDiameter = _resolvePulseEndDiameter(buttonSize);
        final layoutSize = buttonSize + WraitButtonTokens.countdownSizeOffset;

        return AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final value = _shakeController.value;
            final offset =
                math.sin(
                  value * math.pi * WraitButtonTokens.shakeOscillations,
                ) *
                WraitButtonTokens.shakeAmplitude *
                (1 - value);
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: SizedBox(
            width: layoutSize,
            height: layoutSize,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (isListening)
                  PulseRing(
                    key: const ValueKey('pulseRing'),
                    startDiameter: buttonSize,
                    endDiameter: pulseEndDiameter,
                    color: colorScheme.primary.withValues(alpha: 0.78),
                  ),
                if (isListening && widget.countdownProgress != null)
                  CountdownRing(
                    key: const ValueKey('countdownRing'),
                    size: buttonSize + WraitButtonTokens.countdownSizeOffset,
                    progress: widget.countdownProgress!,
                    color: colorScheme.primary,
                    strokeWidth: WraitButtonTokens.countdownStrokeWidth,
                  ),
                AnimatedOpacity(
                  duration: WraitAnimationTokens.buttonAlpha,
                  opacity: isDisabled
                      ? WraitButtonTokens.alphaDisabled
                      : WraitButtonTokens.alphaFull,
                  child: Semantics(
                    button: true,
                    label: isListening
                        ? 'Recording action button. Listening with countdown indicator.'
                        : 'Recording action button',
                    hint: isListening
                        ? 'Double tap to stop recording.'
                        : 'Double tap to start recording.',
                    value: widget.buttonLabel,
                    child: Material(
                      color: colorScheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: mainActionButtonKey,
                        customBorder: const CircleBorder(),
                        onTap: widget.onPressed,
                        child: SizedBox(
                          width: buttonSize,
                          height: buttonSize,
                          child: Center(
                            child: Text(
                              widget.buttonLabel,
                              key: mainActionButtonLabelKey,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _resolvePulseEndDiameter(double buttonSize) {
    final minimumPulseDiameter = buttonSize * WraitButtonTokens.pulseScaleMax;
    final requestedPulseDiameter = widget.pulseDiameter;
    if (requestedPulseDiameter == null || !requestedPulseDiameter.isFinite) {
      return minimumPulseDiameter;
    }

    return requestedPulseDiameter
        .clamp(minimumPulseDiameter, WraitButtonTokens.pulseDiameterMax)
        .toDouble();
  }
}
