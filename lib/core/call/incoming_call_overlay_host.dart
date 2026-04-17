import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'consultation_incoming_call.dart';
import 'incoming_call_coordinator.dart';

/// Full-screen incoming call UI above the whole app ([MaterialApp.builder]).
class IncomingCallOverlayHost extends StatelessWidget {
  const IncomingCallOverlayHost({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: IncomingCallCoordinator.instance,
      builder: (context, _) {
        final inv = IncomingCallCoordinator.instance.invite;
        if (inv == null) return const SizedBox.shrink();

        return _IncomingCallOverlay(invite: inv);
      },
    );
  }
}

class _IncomingCallOverlay extends StatelessWidget {
  const _IncomingCallOverlay({required this.invite});

  final IncomingCallInvite invite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = invite.isVideo ? 'Incoming video call' : 'Incoming voice call';
    final name = invite.peerDisplayName ?? 'Someone';

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        invite.isVideo ? Icons.videocam : Icons.call,
                        size: 56,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      if (invite.isVideo) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Video — camera and microphone will be used',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: IncomingCallCoordinator.instance.decline,
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: IncomingCallCoordinator.instance.accept,
                              child: Text(invite.isVideo ? 'Accept video' : 'Accept'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
