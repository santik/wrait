import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'calendar_month_model.dart';

/// Marker shown beneath a day number for days that have entries.
///
/// One dot for a single entry, up to three for multiple entries. Days with more
/// than three entries show three dots followed by a `+` (no exact count).
/// Draft-only days use a subtler (outline) color than days with finalized
/// entries. The dots are decorative; [semanticsLabel] (e.g. "2 entries") gives
/// a screen reader the entry count the dots convey visually.
class CalendarDayMarker extends StatelessWidget {
  const CalendarDayMarker({
    required this.indicator,
    this.semanticsLabel,
    super.key,
  });

  final CalendarDayIndicator indicator;

  /// Announced to assistive technology in place of the decorative dots.
  final String? semanticsLabel;

  static const double _dotSize = 5;
  static const int _maxDots = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = indicator.draftOnly ? scheme.outline : scheme.primary;
    final dotCount = indicator.entryCount.clamp(1, _maxDots);
    final hasOverflow = indicator.entryCount > _maxDots;

    return Semantics(
      label: semanticsLabel,
      container: semanticsLabel != null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          for (var i = 0; i < dotCount; i++)
            Container(
              width: _dotSize,
              height: _dotSize,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (hasOverflow)
            Padding(
              padding: const EdgeInsets.only(left: 1),
              child: Text(
                '+',
                style: TextStyle(
                  color: color,
                  fontSize: _dotSize + 2,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Vertical space reserved under each day cell so markers never overlap the
/// day number.
const double kCalendarMarkerReserve = WraitSpacingTokens.sm;
