import 'package:flutter/material.dart';

/// A full-width [FilledButton] that disables itself and shows a spinner while
/// [onPressed] is running, so a slow save can't be triggered twice and the user
/// gets visible feedback that something is happening. Errors are left to
/// [onPressed] to handle (e.g. showing its own SnackBar) — this widget only
/// manages the busy/disabled visual state.
class SavingButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Future<void> Function() onPressed;

  const SavingButton({super.key, required this.label, this.icon, required this.onPressed});

  @override
  State<SavingButton> createState() => _SavingButtonState();
}

class _SavingButtonState extends State<SavingButton> {
  bool _busy = false;

  Future<void> _handleTap() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.icon;
    return FilledButton(
      onPressed: _busy ? null : _handleTap,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: _busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                Text(widget.label),
              ],
            ),
    );
  }
}
