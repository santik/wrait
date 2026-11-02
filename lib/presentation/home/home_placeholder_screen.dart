import 'package:flutter/widgets.dart';

import '../shell/shell_placeholder_screen.dart';

class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShellPlaceholderScreen(
      title: 'Capture',
      description: 'The root shell is ready for recording, transient status feedback, and quota messaging.',
    );
  }
}
