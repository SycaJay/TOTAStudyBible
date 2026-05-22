import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_service.dart';

class AppUpdateChecker extends StatefulWidget {
  const AppUpdateChecker({super.key, required this.child});

  final Widget? child;

  @override
  State<AppUpdateChecker> createState() => _AppUpdateCheckerState();
}

class _AppUpdateCheckerState extends State<AppUpdateChecker> {
  var _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCheck());
  }

  Future<void> _runCheck() async {
    if (_checked || !mounted) return;
    _checked = true;
    if (kIsWeb) return;

    final update = await AppUpdateService.checkForUpdate();
    if (!mounted || update == null) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Update Available'),
          content: const Text(
            'A new version of the app is available. Please update to continue.',
          ),
          actions: [
            FilledButton(
              onPressed: () => _openApk(dialogContext, update.apkUrl),
              child: const Text('Update Now'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openApk(BuildContext context, String apkUrl) async {
    final uri = Uri.parse(apkUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
