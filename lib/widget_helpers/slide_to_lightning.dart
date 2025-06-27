import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallet/utilities/app_colors.dart';

class SlideToLightning extends StatefulWidget {
  final String mnemonic;
  final VoidCallback? onCompleted;

  const SlideToLightning({
    super.key,
    required this.mnemonic,
    required this.onCompleted,
  });

  @override
  State<StatefulWidget> createState() => SlideToLightningState();
}

class SlideToLightningState extends State<SlideToLightning> {
  double _dragPosition = 0;
  final double _threshold = 0.65;
  bool _completed = false;

  @override
  void initState() {
    super.initState();

    if (_completed) {
      setState(() {
        _completed = false;
        _dragPosition = 0;
      });
    }
  }

  void _onDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_completed) {
      return;
    }

    final maxWidth = constraints.maxWidth - 60;
    double newPos = (_dragPosition + details.delta.dx).clamp(0, maxWidth);
    setState(() => _dragPosition = newPos);

    // print(_dragPosition);
    // print(constraints.maxWidth);
    // print(_threshold);

    if (_dragPosition / constraints.maxWidth > _threshold) {
      setState(() => _completed = true);

      HapticFeedback.mediumImpact();

      widget.onCompleted!();

      setState(() {
        _completed = false;
        _dragPosition = 0;
      });
    }
  }

  void _onDragEnd(BoxConstraints constraints) {
    if (_completed) {
      return;
    }

    setState(() => _dragPosition = 0); // Reset
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.container(context),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary(context).opaque(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppColors.primary(context).opaque(0.4),
              width: 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "Slide to Lightning",
                  style: TextStyle(
                    color: AppColors.text(context).opaque(0.6),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 0),
                left: _dragPosition,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) =>
                      _onDragUpdate(details, constraints),
                  onHorizontalDragEnd: (_) => _onDragEnd(constraints),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary(context),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary(context).opaque(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.bolt,
                      color: AppColors.gradient(context),
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
