// Mindora - Caregiver Authentication & Login Screen
// Dedicated portal entry for family members and caregivers.
// Maintains privacy, security, and consent awareness.
// Note: "Patient" is NEVER used anywhere in UI labels or messages.

import 'package:flutter/material.dart';
import '../theme/mindora_theme.dart';
import '../app_settings.dart';
import '../services/api_service.dart';

class CaregiverLoginScreen extends StatefulWidget {
  const CaregiverLoginScreen({super.key});

  @override
  State<CaregiverLoginScreen> createState() => _CaregiverLoginScreenState();
}

class _CaregiverLoginScreenState extends State<CaregiverLoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _registerMode = false;

  bool get isHindi => AppSettings.instance.isHindi;
  String tr(String en, String hi, {String? key}) => AppSettings.instance.trBilingual(en, hi, key: key);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    Map<String, dynamic>? result;
    if (_registerMode) {
      result = await ApiService.instance.register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        role: 'caregiver',
      );
    } else {
      result = await ApiService.instance.caregiverLogin(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.instance.lastError ??
                tr('Could not sign in. Please check your details.', 'साइन इन नहीं हो सका।'),
          ),
        ),
      );
      return;
    }
    // The auth gate detects the validated caregiver session and shows the
    // caregiver dashboard. Popping returns to it instead of leaving a second
    // dashboard route stacked on top of role selection.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MindoraColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr('Password Recovery', 'पासवर्ड पुनर्प्राप्ति'),
          style: MindoraTextStyles.titleLarge,
        ),
        content: Text(
          tr(
            'Password reset is not available in this build. Please contact the Mindora administrator to reset your caregiver account securely.',
            'इस बिल्ड में पासवर्ड रीसेट उपलब्ध नहीं है। अपना देखभालकर्ता खाता सुरक्षित रूप से रीसेट कराने के लिए कृपया Mindora प्रशासक से संपर्क करें।',
          ),
          style: MindoraTextStyles.bodyMedium,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: MindoraColors.sageGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('Understood', 'समझ गया')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: MindoraColors.cream,
          appBar: AppBar(
            backgroundColor: MindoraColors.cream,
            foregroundColor: MindoraColors.forestGreen,
            elevation: 0,
            leading: IconButton(
              tooltip: tr('Back to role selection', 'भूमिका चयन पर वापस जाएँ'),
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(
              tr('Caregiver Access', 'देखभालकर्ता प्रवेश'),
              style: MindoraTextStyles.displayMedium,
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: mindoraCard(color: MindoraColors.cardGreen, radius: 20),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.volunteer_activism_rounded,
                          size: 38,
                          color: MindoraColors.forestGreen,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('Caregiver & Family Portal', 'देखभालकर्ता एवं परिवार पोर्टल'),
                                style: MindoraTextStyles.titleMedium.copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr(
                                  'Review shared cognitive activities, mood history and engagement trends of your loved one.',
                                  'अपने प्रियजन की गतिविधियों, मनोदशा और सहभागिता का विवरण देखें।',
                                ),
                                style: MindoraTextStyles.caption.copyWith(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  if (_registerMode) ...[
                    Text(
                      tr('Your name', 'आपका नाम'),
                      style: MindoraTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.person_outline, color: MindoraColors.sageGreen),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Email Field
                  Text(
                    tr('Caregiver Email Address', 'देखभालकर्ता ईमेल पता'),
                    style: MindoraTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.email_outlined, color: MindoraColors.sageGreen),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: MindoraColors.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: MindoraColors.borderLight),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Password Field
                  Text(
                    tr('Password', 'पासवर्ड'),
                    style: MindoraTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: MindoraColors.sageGreen),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: MindoraColors.textMuted,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: MindoraColors.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: MindoraColors.borderLight),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: Text(
                        tr('Forgot Password?', 'पासवर्ड भूल गए?'),
                        style: const TextStyle(color: MindoraColors.sageGreen),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MindoraColors.forestGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              _registerMode
                                  ? tr('Create Caregiver Account', 'देखभालकर्ता खाता बनाएँ')
                                  : tr('Sign In to Dashboard', 'डैशबोर्ड में प्रवेश करें'),
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _registerMode = !_registerMode),
                      child: Text(
                        _registerMode
                            ? tr('I already have an account', 'मेरा खाता पहले से है')
                            : tr('Create a caregiver account', 'देखभालकर्ता खाता बनाएँ'),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Privacy banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: mindoraCard(color: MindoraColors.cardAmber.withValues(alpha: 0.5)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: MindoraColors.forestGreen, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr(
                              'Consent & Privacy: All wellness updates are shared with the explicit consent of the family member.',
                              'गोपनीयता सूचना: सभी विवरण परिवार के सदस्य की स्पष्ट सहमति से ही साझा किए जाते हैं।',
                            ),
                            style: MindoraTextStyles.caption.copyWith(color: MindoraColors.forestGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
