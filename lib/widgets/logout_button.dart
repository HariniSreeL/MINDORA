// Mindora - Shared logout control
// A single, clearly labelled Logout button used by both the Loved One home
// screen and the Caregiver portal. It confirms with one short question, ends
// the current session, clears cached account state, stops audio and returns
// straight to role selection without asking which portal to sign out from.

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../theme/mindora_theme.dart';

class LogoutButton extends StatefulWidget {
  const LogoutButton({super.key, this.compact = false});

  /// Slightly tighter padding for placement inside an app bar. The label,
  /// icon and minimum tap height stay the same.
  final bool compact;

  @override
  State<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<LogoutButton> {
  bool _loggingOut = false;

  Future<void> _confirmAndLogout() async {
    if (_loggingOut) return;

    // The active portal is already known from auth state, so the only question
    // asked is the confirmation. No role re-selection is involved.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MindoraColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(fontSize: 17, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MindoraColors.forestGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    // logout() clears the token, profile cache, game progress and any queued
    // offline writes, and stops the background music.
    await ApiService.instance.logout();
    await AudioService.instance.stopMusic();
    if (!mounted) return;
    setState(() => _loggingOut = false);
    // Remove any protected pushed screens so nothing is left visible behind
    // the role-selection screen.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.compact ? 14.0 : 20.0;
    return Semantics(
      button: true,
      label: 'Logout',
      child: OutlinedButton.icon(
        onPressed: _loggingOut ? null : _confirmAndLogout,
        icon: _loggingOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout_rounded, size: 22),
        label: const Text('Logout'),
        style: OutlinedButton.styleFrom(
          foregroundColor: MindoraColors.forestGreen,
          side: const BorderSide(color: MindoraColors.sageGreen),
          minimumSize: Size(0, widget.compact ? 46 : 54),
          padding: EdgeInsets.symmetric(
            horizontal: horizontal,
            vertical: widget.compact ? 10 : 15,
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
