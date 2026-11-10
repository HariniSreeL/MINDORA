import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../services/api_service.dart';
import '../theme/mindora_theme.dart';

class UserAuthScreen extends StatefulWidget {
  const UserAuthScreen({
    super.key,
    this.startOnRegister = false,
    this.onAuthenticated,
    this.onGuest,
    this.showBackButton = true,
  });

  final bool startOnRegister;
  final VoidCallback? onAuthenticated;
  final VoidCallback? onGuest;
  final bool showBackButton;

  @override
  State<UserAuthScreen> createState() => _UserAuthScreenState();
}

class _UserAuthScreenState extends State<UserAuthScreen> {
  late bool _registerMode;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _registerMode = widget.startOnRegister;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String tr(String en, String hi) => AppSettings.instance.trBilingual(en, hi);

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    Map<String, dynamic>? result;
    if (_registerMode) {
      result = await ApiService.instance.register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        preferredLanguage: AppSettings.instance.selectedLanguage,
      );
    } else {
      result = await ApiService.instance.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (result != null) {
      if (widget.onAuthenticated != null) {
        widget.onAuthenticated!();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } else {
      setState(() {
        _error = ApiService.instance.lastError ??
            tr('Could not sign in. Please try again.', 'साइन इन नहीं हो सका।');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: MindoraColors.cream,
          appBar: AppBar(
            automaticallyImplyLeading: widget.showBackButton,
            title: Text(
              _registerMode
                  ? tr('Create Account', 'खाता बनाएँ')
                  : tr('Sign In', 'साइन इन'),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  tr(
                    'Your games and mood stay with your account.',
                    'आपके खेल और मनोदशा आपके खाते में सुरक्षित रहते हैं।',
                  ),
                  style: MindoraTextStyles.bodyMedium,
                ),
                const SizedBox(height: 20),
                if (_registerMode) ...[
                  Text(tr('Your name', 'आपका नाम'), style: MindoraTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: _inputDecoration(Icons.person_outline),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(tr('Email', 'ईमेल'), style: MindoraTextStyles.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration(Icons.email_outlined),
                ),
                const SizedBox(height: 16),
                Text(tr('Password', 'पासवर्ड'), style: MindoraTextStyles.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _inputDecoration(Icons.lock_outline),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFF8C3A2F))),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MindoraColors.forestGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _registerMode
                              ? tr('Create Account', 'खाता बनाएँ')
                              : tr('Sign In', 'साइन इन'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _registerMode = !_registerMode;
                    _error = null;
                  }),
                  child: Text(
                    _registerMode
                        ? tr('I already have an account', 'मेरा खाता पहले से है')
                        : tr('Create a new account', 'नया खाता बनाएँ'),
                  ),
                ),
                if (widget.onGuest != null) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'Guest mode keeps activity on this device only. Sign in to sync games, moods and caregiver sharing.',
                      'अतिथि मोड गतिविधि केवल इस डिवाइस पर रखता है। खेल, मनोदशा और देखभालकर्ता साझा करने के लिए साइन इन करें।',
                    ),
                    style: MindoraTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _loading ? null : widget.onGuest,
                    child: Text(tr('Continue as guest', 'अतिथि के रूप में जारी रखें')),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(IconData icon) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon, color: MindoraColors.sageGreen),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
