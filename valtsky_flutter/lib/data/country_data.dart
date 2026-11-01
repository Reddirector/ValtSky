class Country {
  final String name;
  final String dialCode;
  final String code;
  final String flag;
  final int maxLength;
  final String example;

  const Country({
    required this.name,
    required this.dialCode,
    required this.code,
    required this.flag,
    required this.maxLength,
    required this.example,
  });

  String get displayName => '$flag  $name ($dialCode)';
}

class CountryData {
  static const Country defaultCountry = Country(
    name: 'India',
    dialCode: '+91',
    code: 'IN',
    flag: '🇮🇳',
    maxLength: 10,
    example: '98765 43210',
  );

  static const List<Country> countries = [
    Country(
      name: 'India',
      dialCode: '+91',
      code: 'IN',
      flag: '🇮🇳',
      maxLength: 10,
      example: '98765 43210',
    ),
    Country(
      name: 'United States',
      dialCode: '+1',
      code: 'US',
      flag: '🇺🇸',
      maxLength: 10,
      example: '555 123 4567',
    ),
    Country(
      name: 'United Kingdom',
      dialCode: '+44',
      code: 'GB',
      flag: '🇬🇧',
      maxLength: 10,
      example: '7911 123456',
    ),
    Country(
      name: 'Canada',
      dialCode: '+1',
      code: 'CA',
      flag: '🇨🇦',
      maxLength: 10,
      example: '416 555 0199',
    ),
    Country(
      name: 'United Arab Emirates',
      dialCode: '+971',
      code: 'AE',
      flag: '🇦🇪',
      maxLength: 9,
      example: '50 123 4567',
    ),
    Country(
      name: 'Saudi Arabia',
      dialCode: '+966',
      code: 'SA',
      flag: '🇸🇦',
      maxLength: 9,
      example: '50 123 4567',
    ),
    Country(
      name: 'Australia',
      dialCode: '+61',
      code: 'AU',
      flag: '🇦🇺',
      maxLength: 9,
      example: '412 345 678',
    ),
    Country(
      name: 'Germany',
      dialCode: '+49',
      code: 'DE',
      flag: '🇩🇪',
      maxLength: 11,
      example: '151 23456789',
    ),
    Country(
      name: 'France',
      dialCode: '+33',
      code: 'FR',
      flag: '🇫🇷',
      maxLength: 9,
      example: '6 12 34 56 78',
    ),
    Country(
      name: 'Singapore',
      dialCode: '+65',
      code: 'SG',
      flag: '🇸🇬',
      maxLength: 8,
      example: '8123 4567',
    ),
    Country(
      name: 'Indonesia',
      dialCode: '+62',
      code: 'ID',
      flag: '🇮🇩',
      maxLength: 11,
      example: '812 3456 7890',
    ),
    Country(
      name: 'Brazil',
      dialCode: '+55',
      code: 'BR',
      flag: '🇧🇷',
      maxLength: 11,
      example: '11 91234 5678',
    ),
    Country(
      name: 'Russia',
      dialCode: '+7',
      code: 'RU',
      flag: '🇷🇺',
      maxLength: 10,
      example: '912 345 6789',
    ),
    Country(
      name: 'Japan',
      dialCode: '+81',
      code: 'JP',
      flag: '🇯🇵',
      maxLength: 10,
      example: '90 1234 5678',
    ),
    Country(
      name: 'South Korea',
      dialCode: '+82',
      code: 'KR',
      flag: '🇰🇷',
      maxLength: 10,
      example: '10 1234 5678',
    ),
    Country(
      name: 'Pakistan',
      dialCode: '+92',
      code: 'PK',
      flag: '🇵🇰',
      maxLength: 10,
      example: '300 1234567',
    ),
    Country(
      name: 'Bangladesh',
      dialCode: '+880',
      code: 'BD',
      flag: '🇧🇩',
      maxLength: 10,
      example: '1712 345678',
    ),
    Country(
      name: 'Nigeria',
      dialCode: '+234',
      code: 'NG',
      flag: '🇳🇬',
      maxLength: 10,
      example: '802 123 4567',
    ),
    Country(
      name: 'Philippines',
      dialCode: '+63',
      code: 'PH',
      flag: '🇵🇭',
      maxLength: 10,
      example: '917 123 4567',
    ),
    Country(
      name: 'Italy',
      dialCode: '+39',
      code: 'IT',
      flag: '🇮🇹',
      maxLength: 10,
      example: '312 345 6789',
    ),
    Country(
      name: 'Spain',
      dialCode: '+34',
      code: 'ES',
      flag: '🇪🇸',
      maxLength: 9,
      example: '612 345 678',
    ),
    Country(
      name: 'Netherlands',
      dialCode: '+31',
      code: 'NL',
      flag: '🇳🇱',
      maxLength: 9,
      example: '6 12345678',
    ),
    Country(
      name: 'Switzerland',
      dialCode: '+41',
      code: 'CH',
      flag: '🇨🇭',
      maxLength: 9,
      example: '78 123 45 67',
    ),
    Country(
      name: 'Turkey',
      dialCode: '+90',
      code: 'TR',
      flag: '🇹🇷',
      maxLength: 10,
      example: '501 234 5678',
    ),
    Country(
      name: 'South Africa',
      dialCode: '+27',
      code: 'ZA',
      flag: '🇿🇦',
      maxLength: 9,
      example: '71 123 4567',
    ),
    Country(
      name: 'Mexico',
      dialCode: '+52',
      code: 'MX',
      flag: '🇲🇽',
      maxLength: 10,
      example: '55 1234 5678',
    ),
    Country(
      name: 'Malaysia',
      dialCode: '+60',
      code: 'MY',
      flag: '🇲🇾',
      maxLength: 10,
      example: '12 345 6789',
    ),
  ];

  static Country findByDialCode(String dialCode) {
    return countries.firstWhere(
      (c) => c.dialCode == dialCode,
      orElse: () => defaultCountry,
    );
  }

  static Country? detectFromPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!clean.startsWith('+')) return null;
    
    // Sort by dial code length descending to match +971 before +9 etc.
    final sorted = List<Country>.from(countries)
      ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
    
    for (final c in sorted) {
      if (clean.startsWith(c.dialCode)) {
        return c;
      }
    }
    return null;
  }
}
