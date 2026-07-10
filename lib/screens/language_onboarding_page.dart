import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:catchify/extensions/l10n.dart';
import 'package:catchify/services/data_manager.dart';
import 'package:catchify/services/router_service.dart';
import 'package:catchify/services/settings_manager.dart';
import 'package:catchify/utilities/language_utils.dart';
import 'package:catchify/widgets/bottom_sheet_bar.dart';

class _LanguageOption {
  const _LanguageOption(this.code, this.native, this.english, this.color);

  final String code;
  final String native;
  final String english;
  final Color color;
}

const _priorityLanguages = [
  _LanguageOption('hi', 'हिंदी', 'Hindi', Color(0xFFE0512A)),
  _LanguageOption('en', 'English', 'English', Color(0xFFE8A93A)),
  _LanguageOption('te', 'తెలుగు', 'Telugu', Color(0xFF9B3FA8)),
  _LanguageOption('ta', 'தமிழ்', 'Tamil', Color(0xFFD8A526)),
  _LanguageOption('mr', 'मराठी', 'Marathi', Color(0xFF3F9142)),
  _LanguageOption('bn', 'বাংলা', 'Bengali', Color(0xFF2D9E8F)),
  _LanguageOption('kn', 'ಕನ್ನಡ', 'Kannada', Color(0xFF2E6FE0)),
  _LanguageOption('pa', 'ਪੰਜਾਬੀ', 'Punjabi', Color(0xFFD8385F)),
  _LanguageOption('ml', 'മലയാളം', 'Malayalam', Color(0xFF6B4FCF)),
  _LanguageOption('gu', 'ગુજરાતી', 'Gujarati', Color(0xFFD6497A)),
  _LanguageOption('ur', 'اردو', 'Urdu', Color(0xFF3B7D6B)),
  _LanguageOption('or', 'ଓଡ଼ିଆ', 'Odia', Color(0xFFC2622E)),
  _LanguageOption('as', 'অসমীয়া', 'Assamese', Color(0xFF4A7FAE)),
  _LanguageOption('sa', 'संस्कृतम्', 'Sanskrit', Color(0xFFA8752E)),
  _LanguageOption('kok', 'कोंकणी', 'Konkani', Color(0xFF5B8C3E)),
];

class LanguageOnboardingPage extends StatefulWidget {
  const LanguageOnboardingPage({super.key});

  @override
  State<LanguageOnboardingPage> createState() =>
      _LanguageOnboardingPageState();
}

class _LanguageOnboardingPageState extends State<LanguageOnboardingPage> {
  bool _showMore = false;

  void _finishOnboarding() {
    addOrUpdateData<bool>('settings', 'hasSeenLanguageOnboarding', true);
    context.go(NavigationManager.homePath);
  }

  void _selectLanguage(String languageCode) {
    contentLanguagePreference = languageCode;
    addOrUpdateData<String>('settings', 'contentLanguageCode', languageCode);
    _finishOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final priorityCodes = _priorityLanguages.map((l) => l.code).toSet();
    final otherLanguages = appLanguages
        .where((code) => !priorityCodes.contains(code))
        .toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _finishOnboarding,
            child: Text(context.l10n!.skip),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n!.chooseYourLanguage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n!.chooseLanguageDescription,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _priorityLanguages.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.5,
                        ),
                    itemBuilder: (context, index) {
                      final language = _priorityLanguages[index];
                      return _LanguageCard(
                        language: language,
                        onTap: () => _selectLanguage(language.code),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (!_showMore)
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _showMore = true),
                        child: Text(context.l10n!.showMoreLanguages),
                      ),
                    )
                  else
                    ...otherLanguages.map(
                      (code) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: BottomSheetBar(
                          getLanguageDisplayName(context, code),
                          () => _selectLanguage(code),
                          false,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.language, required this.onTap});

  final _LanguageOption language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: language.color,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -18,
              child: CustomPaint(
                size: const Size(110, 110),
                painter: _ArchMotifPainter(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                        width: 1.6,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.native,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        language.english,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A generic, non-region-specific dome-and-arch motif used purely as a
/// decorative watermark (not intended to depict any real monument).
class _ArchMotifPainter extends CustomPainter {
  _ArchMotifPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width;
    final h = size.height;

    final archPath = Path()
      ..moveTo(w * 0.15, h)
      ..lineTo(w * 0.15, h * 0.55)
      ..arcToPoint(Offset(w * 0.85, h * 0.55), radius: Radius.circular(w * 0.35))
      ..lineTo(w * 0.85, h)
      ..close();
    canvas
      ..drawPath(archPath, paint)
      ..drawCircle(Offset(w * 0.5, h * 0.32), w * 0.1, paint);
  }

  @override
  bool shouldRepaint(covariant _ArchMotifPainter oldDelegate) => false;
}
