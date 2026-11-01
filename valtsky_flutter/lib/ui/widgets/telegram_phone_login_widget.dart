import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/telegram_auth_service.dart';
import '../../data/country_data.dart';
import '../../util/theme.dart';
import 'animated_stagger.dart';

class TelegramPhoneLoginWidget extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onSwitchToBotMode;

  const TelegramPhoneLoginWidget({
    super.key,
    required this.onLoginSuccess,
    required this.onSwitchToBotMode,
  });

  @override
  State<TelegramPhoneLoginWidget> createState() => _TelegramPhoneLoginWidgetState();
}

class _TelegramPhoneLoginWidgetState extends State<TelegramPhoneLoginWidget> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  Country _selectedCountry = CountryData.defaultCountry; // Defaults to India (+91, 10 digits)
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final text = _phoneController.text.trim();
    // Auto-detect country if user pasted or entered number starting with +
    if (text.startsWith('+')) {
      final detected = CountryData.detectFromPhone(text);
      if (detected != null && detected.dialCode != _selectedCountry.dialCode) {
        setState(() {
          _selectedCountry = detected;
        });
        // Strip dial code from controller
        final stripped = text.substring(detected.dialCode.length).replaceAll(RegExp(r'\D'), '');
        final limited = stripped.length > detected.maxLength ? stripped.substring(0, detected.maxLength) : stripped;
        _phoneController.value = TextEditingValue(
          text: limited,
          selection: TextSelection.collapsed(offset: limited.length),
        );
      }
    } else {
      // Trigger rebuild to update digit counter
      setState(() {});
    }
  }

  void _openCountryPicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CountryPickerSheet(
        isDark: isDark,
        selectedCountry: _selectedCountry,
        onSelect: (country) {
          setState(() {
            _selectedCountry = country;
            // Trim existing text if longer than new country's max length
            if (_phoneController.text.length > country.maxLength) {
              _phoneController.text = _phoneController.text.substring(0, country.maxLength);
            }
          });
        },
      ),
    );
  }

  Future<void> _handleSendCode() async {
    final digits = _phoneController.text.trim();
    if (digits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ValtSkyTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Please enter your ${_selectedCountry.name} phone number'),
        ),
      );
      return;
    }

    if (digits.length < _selectedCountry.maxLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ValtSkyTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            '${_selectedCountry.name} numbers require exactly ${_selectedCountry.maxLength} digits (${digits.length}/${_selectedCountry.maxLength} entered)',
          ),
        ),
      );
      return;
    }

    final fullNumber = '${_selectedCountry.dialCode}$digits';
    setState(() => _isLoading = true);

    final success = await TelegramAuthService.instance.sendVerificationCode(fullNumber);
    if (mounted) {
      setState(() => _isLoading = false);
      if (!success) {
        final err = TelegramAuthService.instance.currentState.errorMessage ?? 'Failed to send code';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ValtSkyTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(err),
          ),
        );
      }
    }
  }

  Future<void> _handleVerifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ValtSkyTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Please enter the 5-digit verification code from Telegram'),
        ),
      );
      return;
    }

    if (code.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ValtSkyTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Telegram verification code must be 5 digits'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await TelegramAuthService.instance.verifyCode(code);
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        widget.onLoginSuccess();
      } else {
        final err = TelegramAuthService.instance.currentState.errorMessage ?? 'Verification failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: ValtSkyTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(err),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<AuthState>(
      valueListenable: TelegramAuthService.instance.stateNotifier,
      builder: (context, state, _) {
        final step = state.step;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121214) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Title & Badge
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.telegram_rounded, size: 24, color: Color(0xFF2AABEE)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Direct Telegram Login',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Instant setup: zero BotFather setup required',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Step 1: Enter Phone Number
              if (step == AuthStep.enterPhone) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Telegram Phone Number',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                    // Live Digit Counter Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _phoneController.text.length == _selectedCountry.maxLength
                            ? ValtSkyTheme.success.withValues(alpha: 0.15)
                            : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_phoneController.text.length} / ${_selectedCountry.maxLength} digits',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _phoneController.text.length == _selectedCountry.maxLength
                              ? ValtSkyTheme.success
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Combined Country Selector & Digits-Only Phone Input
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Country Picker Trigger Button
                      InkWell(
                        onTap: () => _openCountryPicker(isDark),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedCountry.flag,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _selectedCountry.dialCode,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),

                      // Pure Numeric Input (Letters and symbols strictly blocked)
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(_selectedCountry.maxLength),
                          ],
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                          decoration: InputDecoration(
                            hintText: _selectedCountry.example,
                            hintStyle: TextStyle(
                              color: Colors.grey.withValues(alpha: 0.5),
                              fontWeight: FontWeight.normal,
                              letterSpacing: 0.5,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Country: ${_selectedCountry.name} (${_selectedCountry.dialCode}) • Max ${_selectedCountry.maxLength} digits',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                TactilePress(
                  onTap: _isLoading ? null : _handleSendCode,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            )
                          : Text(
                              'SEND TELEGRAM VERIFICATION CODE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],

              // Step 2: Enter Verification Code
              if (step == AuthStep.enterCode || step == AuthStep.provisioning) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Code sent to ${_selectedCountry.dialCode} ${_phoneController.text}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => TelegramAuthService.instance.reset(),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('Change', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Check your official Telegram app for the 5-digit login code.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '•••••',
                    hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5), letterSpacing: 8),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TactilePress(
                  onTap: _isLoading ? null : _handleVerifyCode,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'CONNECTING & SYNCING PROFILE...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'VERIFY & LINK TELEGRAM ACCOUNT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],

              // Completed
              if (step == AuthStep.completed) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ValtSkyTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ValtSkyTheme.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: ValtSkyTheme.success, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Real Telegram Account Linked',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ValtSkyTheme.success),
                            ),
                            Text(
                              state.provisionedChannelName ?? 'ValtSky Private Vault',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(height: 32),

              // Switch to Bot Token mode
              Center(
                child: TextButton.icon(
                  onPressed: widget.onSwitchToBotMode,
                  icon: const Icon(Icons.smart_toy_outlined, size: 16),
                  label: const Text(
                    'Advanced: Use Custom Bot Token & Channel ID',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Searchable Country Picker Bottom Sheet
class _CountryPickerSheet extends StatefulWidget {
  final bool isDark;
  final Country selectedCountry;
  final ValueChanged<Country> onSelect;

  const _CountryPickerSheet({
    required this.isDark,
    required this.selectedCountry,
    required this.onSelect,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Country> _filtered = CountryData.countries;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = CountryData.countries;
      } else {
        _filtered = CountryData.countries.where((c) {
          final cleanDial = c.dialCode.replaceAll('+', '');
          return c.name.toLowerCase().contains(q) ||
              c.code.toLowerCase().contains(q) ||
              cleanDial.contains(q) ||
              c.dialCode.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Material(
      color: isDark ? const Color(0xFF18181B) : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Country / Region',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by country or code (+91, India...)',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.withValues(alpha: 0.6)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                filled: true,
                fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _filtered.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
              ),
              itemBuilder: (context, index) {
                final country = _filtered[index];
                final isSelected = country.dialCode == widget.selectedCountry.dialCode &&
                    country.code == widget.selectedCountry.code;

                return ListTile(
                  onTap: () {
                    widget.onSelect(country);
                    Navigator.pop(context);
                  },
                  leading: Text(
                    country.flag,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    country.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Max ${country.maxLength} digits (e.g. ${country.example})',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          country.dialCode,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle_rounded, color: ValtSkyTheme.success, size: 18),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
}
