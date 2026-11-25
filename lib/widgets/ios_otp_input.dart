import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ios_components.dart';

/// Native iOS-style 6-Digit SMS OTP Input with individual digit cells,
/// paste support, auto-advance, and resend countdown timer.
class IosOtpInput extends StatefulWidget {
  final TextEditingController controller;
  final String phone;
  final VoidCallback? onResend;
  final ValueChanged<String>? onCompleted;
  final bool isResending;

  const IosOtpInput({
    super.key,
    required this.controller,
    required this.phone,
    this.onResend,
    this.onCompleted,
    this.isResending = false,
  });

  @override
  State<IosOtpInput> createState() => _IosOtpInputState();
}

class _IosOtpInputState extends State<IosOtpInput> {
  final FocusNode _focusNode = FocusNode();
  Timer? _timer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
      }
    });
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
    if (widget.controller.text.length == 6) {
      HapticFeedback.lightImpact();
      widget.onCompleted?.call(widget.controller.text);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: IosTheme.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.chat_bubble_text_fill,
                size: 16,
                color: IosTheme.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text(
                '6-digit code sent to +91 ${widget.phone}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: IosTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Hidden TextField + 6 visual iOS digit cells
        GestureDetector(
          onTap: () => _focusNode.requestFocus(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Hidden input capturing keyboard + SMS autofill
              Opacity(
                opacity: 0.0,
                child: SizedBox(
                  height: 54,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(counterText: ''),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final hasChar = index < code.length;
                  final isActive = index == code.length && _focusNode.hasFocus;
                  final char = hasChar ? code[index] : '';

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 46,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive || hasChar
                            ? IosTheme.primaryBlue
                            : IosTheme.separator,
                        width: isActive ? 2 : 1,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: IosTheme.primaryBlue.withValues(alpha: 0.14),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      char,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: IosTheme.labelPrimary,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Valid for 10 minutes',
              style: TextStyle(
                fontSize: 12.5,
                color: IosTheme.labelTertiary,
              ),
            ),
            if (widget.onResend != null)
              _secondsLeft > 0
                  ? Text(
                      'Resend in ${_secondsLeft}s',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: IosTheme.labelTertiary,
                      ),
                    )
                  : CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 32),
                      onPressed: widget.isResending
                          ? null
                          : () {
                              widget.onResend!();
                              _startTimer();
                            },
                      child: widget.isResending
                          ? const CupertinoActivityIndicator(radius: 9)
                          : const Text(
                              'Resend OTP',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: IosTheme.primaryBlue,
                              ),
                            ),
                    ),
          ],
        ),
      ],
    );
  }
}
