import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_primary_button.dart';

/// Join specialties / languages for a subtitle line.
String astrologerExpertiseLine(Map<String, dynamic> a) {
  final specs = a['specialties'];
  if (specs is List && specs.isNotEmpty) {
    return specs.take(4).map((e) => e.toString()).join(' · ');
  }
  final langs = a['languages'];
  if (langs is List && langs.isNotEmpty) {
    return langs.take(3).map((e) => e.toString()).join(' · ');
  }
  return 'Astrology';
}

String _feeLine(Map<String, dynamic> a) {
  final raw = a['consultationFeePerMin'];
  if (raw == null) return 'Chat';
  final n = num.tryParse(raw.toString());
  if (n == null) return 'Chat';
  if (n == 0) return 'Free chat';
  return '₹${n is int || n == n.roundToDouble() ? n.round() : n}/min';
}

String _expLine(Map<String, dynamic> a) {
  final raw = a['experienceYears'];
  if (raw == null) return '';
  final n = num.tryParse(raw.toString());
  if (n == null || n <= 0) return '';
  final v = n == n.roundToDouble() ? '${n.round()}' : '$n';
  return 'Exp · $v yrs';
}

double? _rating(Map<String, dynamic> a) {
  final raw = a['averageRating'];
  if (raw == null) return null;
  return double.tryParse(raw.toString());
}

int _consultCount(Map<String, dynamic> a) {
  final raw = a['totalConsultations'];
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

/// Horizontal “story” style avatar for live strip.
class AstrologerLiveCircle extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onTap;

  const AstrologerLiveCircle({super.key, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = data['name']?.toString() ?? 'Astrologer';
    final online = data['isOnline'] == true;
    final url = data['profileImageUrl']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 80,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.35),
                            AppTheme.primaryColor.withValues(alpha: 0.15),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: url != null && url.isNotEmpty
                          ? Image.network(
                              url,
                              fit: BoxFit.cover,
                              width: 76,
                              height: 76,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.person_rounded,
                                size: 40,
                                color: AppTheme.primaryTextColor,
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              size: 40,
                              color: AppTheme.primaryTextColor,
                            ),
                    ),
                    if (online)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppTheme.successColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (online)
                  Text(
                    'Online',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width modern card for the feed.
class AstrologerFeedCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onChat;
  final VoidCallback? onCall;

  const AstrologerFeedCard({
    super.key,
    required this.data,
    this.onChat,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['name']?.toString() ?? 'Astrologer';
    final verified = data['isVerified'] == true;
    final online = data['isOnline'] == true;
    final url = data['profileImageUrl']?.toString();
    final bio = data['bio']?.toString() ?? '';
    final expertise = astrologerExpertiseLine(data);
    final exp = _expLine(data);
    final fee = _feeLine(data);
    final rating = _rating(data);
    final consults = _consultCount(data);
    final chatOn = data['chatEnabled'] != false;
    final callOn = data['callEnabled'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Material(
        color: AppTheme.surfaceColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onChat,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppTheme.inputBorderColor.withValues(alpha: 0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 64,
                              height: 64,
                              color: AppTheme.primaryColor.withValues(alpha: 0.15),
                              child: url != null && url.isNotEmpty
                                  ? Image.network(
                                      url,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.person_rounded,
                                              size: 36),
                                    )
                                  : const Icon(Icons.person_rounded, size: 36),
                            ),
                          ),
                          if (verified)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Icon(
                                Icons.verified_rounded,
                                size: 22,
                                color: AppTheme.successColor,
                              ),
                            ),
                          if (online)
                            Positioned(
                              left: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                letterSpacing: -0.3,
                                color: AppTheme.primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              expertise,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (exp.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                exp,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                            color: AppTheme.secondaryTextColor,
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (rating != null && rating > 0) ...[
                        Icon(Icons.star_rounded,
                            size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.people_outline_rounded,
                          size: 16, color: AppTheme.secondaryTextColor),
                      const SizedBox(width: 4),
                      Text(
                        '$consults sessions',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          fee,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppTheme.primaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (chatOn || callOn)
                    Row(
                      children: [
                        if (chatOn)
                          Expanded(
                            child: AppPrimaryButton.icon(
                              onPressed: onChat,
                              width: double.infinity,
                              icon: const Icon(
                                Icons.chat_bubble_rounded,
                                size: 20,
                              ),
                              label: const Text('Chat'),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                            ),
                          ),
                        if (chatOn && callOn) const SizedBox(width: 10),
                        if (callOn)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onCall,
                              icon:
                                  const Icon(Icons.call_rounded, size: 20),
                              label: const Text('Call'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryTextColor,
                                side: const BorderSide(
                                    color: AppTheme.inputBorderColor),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    Text(
                      'Chat & call coming soon',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
