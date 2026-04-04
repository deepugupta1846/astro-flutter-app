/// Countries shown on the login phone row, with national-number validation rules.
class LoginCountryOption {
  const LoginCountryOption({
    required this.name,
    required this.dialCode,
    required this.flagEmoji,
    required this.minNationalDigits,
    required this.maxNationalDigits,
    this.nationalPatternSource,
    this.hintText,
  });

  final String name;
  final String dialCode;
  final String flagEmoji;

  /// Inclusive length of the subscriber number only (no country code, no spaces).
  final int minNationalDigits;
  final int maxNationalDigits;

  /// Optional [RegExp] pattern as a string (full national number must match).
  final String? nationalPatternSource;

  /// Hint inside the phone field; defaults from digit range if null.
  final String? hintText;

  String get resolvedHint =>
      hintText ??
      (minNationalDigits == maxNationalDigits
          ? 'Enter $minNationalDigits-digit number'
          : 'Enter $minNationalDigits–$maxNationalDigits digit number');

  String validationMessage() {
    if (minNationalDigits == maxNationalDigits) {
      return 'Enter a valid $minNationalDigits-digit mobile number for $name.';
    }
    return 'Enter a valid $minNationalDigits–$maxNationalDigits digit mobile number for $name.';
  }

  /// [raw] should be digits only (no country code).
  bool isValidNational(String raw) {
    final d = raw.trim();
    if (d.isEmpty) return false;
    if (!RegExp(r'^\d+$').hasMatch(d)) return false;
    if (d.length < minNationalDigits || d.length > maxNationalDigits) {
      return false;
    }
    final src = nationalPatternSource;
    if (src != null && !RegExp(src).hasMatch(d)) return false;
    return true;
  }
}

/// Curated list for login OTP; India first, then alphabetical by name.
final List<LoginCountryOption> kLoginCountryOptions = [
  const LoginCountryOption(
    name: 'India',
    dialCode: '+91',
    flagEmoji: '🇮🇳',
    minNationalDigits: 10,
    maxNationalDigits: 10,
    nationalPatternSource: r'^[6-9]\d{9}$',
    hintText: '10-digit mobile number',
  ),
  const LoginCountryOption(
    name: 'Australia',
    dialCode: '+61',
    flagEmoji: '🇦🇺',
    minNationalDigits: 9,
    maxNationalDigits: 9,
    hintText: '9-digit mobile number',
  ),
  const LoginCountryOption(
    name: 'Bahrain',
    dialCode: '+973',
    flagEmoji: '🇧🇭',
    minNationalDigits: 8,
    maxNationalDigits: 8,
  ),
  const LoginCountryOption(
    name: 'Bangladesh',
    dialCode: '+880',
    flagEmoji: '🇧🇩',
    minNationalDigits: 10,
    maxNationalDigits: 10,
  ),
  const LoginCountryOption(
    name: 'Canada',
    dialCode: '+1',
    flagEmoji: '🇨🇦',
    minNationalDigits: 10,
    maxNationalDigits: 10,
    nationalPatternSource: r'^[2-9]\d{9}$',
    hintText: '10-digit number',
  ),
  const LoginCountryOption(
    name: 'Egypt',
    dialCode: '+20',
    flagEmoji: '🇪🇬',
    minNationalDigits: 10,
    maxNationalDigits: 10,
  ),
  const LoginCountryOption(
    name: 'Kuwait',
    dialCode: '+965',
    flagEmoji: '🇰🇼',
    minNationalDigits: 8,
    maxNationalDigits: 8,
  ),
  const LoginCountryOption(
    name: 'Malaysia',
    dialCode: '+60',
    flagEmoji: '🇲🇾',
    minNationalDigits: 9,
    maxNationalDigits: 10,
  ),
  const LoginCountryOption(
    name: 'Nepal',
    dialCode: '+977',
    flagEmoji: '🇳🇵',
    minNationalDigits: 10,
    maxNationalDigits: 10,
  ),
  const LoginCountryOption(
    name: 'New Zealand',
    dialCode: '+64',
    flagEmoji: '🇳🇿',
    minNationalDigits: 8,
    maxNationalDigits: 10,
  ),
  const LoginCountryOption(
    name: 'Oman',
    dialCode: '+968',
    flagEmoji: '🇴🇲',
    minNationalDigits: 8,
    maxNationalDigits: 8,
  ),
  const LoginCountryOption(
    name: 'Pakistan',
    dialCode: '+92',
    flagEmoji: '🇵🇰',
    minNationalDigits: 10,
    maxNationalDigits: 10,
  ),
  const LoginCountryOption(
    name: 'Qatar',
    dialCode: '+974',
    flagEmoji: '🇶🇦',
    minNationalDigits: 8,
    maxNationalDigits: 8,
  ),
  const LoginCountryOption(
    name: 'Saudi Arabia',
    dialCode: '+966',
    flagEmoji: '🇸🇦',
    minNationalDigits: 9,
    maxNationalDigits: 9,
  ),
  const LoginCountryOption(
    name: 'Singapore',
    dialCode: '+65',
    flagEmoji: '🇸🇬',
    minNationalDigits: 8,
    maxNationalDigits: 8,
  ),
  const LoginCountryOption(
    name: 'Sri Lanka',
    dialCode: '+94',
    flagEmoji: '🇱🇰',
    minNationalDigits: 9,
    maxNationalDigits: 9,
  ),
  const LoginCountryOption(
    name: 'United Arab Emirates',
    dialCode: '+971',
    flagEmoji: '🇦🇪',
    minNationalDigits: 9,
    maxNationalDigits: 9,
  ),
  const LoginCountryOption(
    name: 'United Kingdom',
    dialCode: '+44',
    flagEmoji: '🇬🇧',
    minNationalDigits: 10,
    maxNationalDigits: 10,
    hintText: '10-digit mobile (no leading 0)',
  ),
  const LoginCountryOption(
    name: 'United States',
    dialCode: '+1',
    flagEmoji: '🇺🇸',
    minNationalDigits: 10,
    maxNationalDigits: 10,
    nationalPatternSource: r'^[2-9]\d{9}$',
    hintText: '10-digit number',
  ),
  const LoginCountryOption(
    name: 'South Africa',
    dialCode: '+27',
    flagEmoji: '🇿🇦',
    minNationalDigits: 9,
    maxNationalDigits: 9,
  ),
];

LoginCountryOption get kDefaultLoginCountry => kLoginCountryOptions.first;
