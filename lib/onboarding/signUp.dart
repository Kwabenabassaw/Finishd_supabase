import 'dart:async';
import 'package:finishd/onboarding/widgets/button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:finishd/services/auth_service.dart';
import 'package:finishd/provider/user_provider.dart';
import 'package:finishd/screens/moderation_block_screen.dart';
import 'package:finishd/utils/name_utils.dart';

// Define the primary color (Green from the image)
const Color primaryGreen = Color(0xFF1A8927);

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Listen for auth state changes (for OAuth flow)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      debugPrint('🔑 SignUp: Auth state changed: ${data.event}');
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        _handleSuccessfulSignIn(data.session!.user.id);
      }
    });
  }

  Future<void> _handleSuccessfulSignIn(String userId) async {
    if (!mounted) return;

    debugPrint('🔑 SignUp: Handling successful sign-in for $userId');

    final authService = Provider.of<AuthService>(context, listen: false);

    // Check moderation status before allowing access
    if (await _checkModerationAndNavigate(authService)) return;

    // Check if user has completed onboarding
    final onboardingCompleted = await authService.hasCompletedOnboarding(
      userId,
    );

    if (!onboardingCompleted) {
      // New or incomplete user — send to onboarding
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, 'genre', (route) => false);
      }
      return;
    }

    // Initialize UserProvider
    Provider.of<UserProvider>(context, listen: false).fetchCurrentUser(userId);

    // Navigate to homepage
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, 'homepage', (route) => false);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Check moderation status and navigate accordingly
  /// Returns true if user is banned/suspended (navigation handled)
  Future<bool> _checkModerationAndNavigate(AuthService authService) async {
    final user = authService.currentUser;
    if (user == null) return false;

    final status = await authService.checkUserModerationStatus(user.id);
    if (status != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ModerationBlockScreen(
            isBanned: status.isBanned,
            reason: status.reason,
            daysRemaining: status.daysRemaining,
          ),
        ),
      );
      return true;
    }
    return false;
  }

  Future<void> _register() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await Provider.of<AuthService>(context, listen: false)
          .signUpWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            firstName: NameUtils.capitalizeName(_firstNameController.text),
            lastName: NameUtils.capitalizeName(_lastNameController.text),
          );

      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);

        // Check moderation status before allowing access
        if (await _checkModerationAndNavigate(authService)) return;

        // If new user, go to onboarding
        if (result['isNewUser'] == true) {
          final authResponse = result['credential'] as AuthResponse;
          if (authResponse.session == null) {
            // Email verification required
            if (mounted) {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('Verification Required'),
                  content: const Text(
                    'Please check your email to verify your account before continuing.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pushReplacementNamed(
                          context,
                          '/login',
                        ); // Go to login
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
              return;
            }
          }
          Navigator.pushReplacementNamed(context, 'genre');
        } else {
          // Existing user - check if they completed onboarding
          if (result['onboardingCompleted'] == true) {
            // Initialize UserProvider with following IDs
            if (authService.currentUser != null) {
              Provider.of<UserProvider>(
                context,
                listen: false,
              ).fetchCurrentUser(authService.currentUser!.id);
            }
            // Onboarding complete, go to homepage
            TextInput.finishAutofillContext(); // Trigger Credential Save
            Navigator.pushReplacementNamed(context, 'homepage');
          } else {
            // Onboarding not complete, continue with onboarding
            TextInput.finishAutofillContext(); // Trigger Credential Save
            Navigator.pushReplacementNamed(context, 'genre');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthService>(context, listen: false).signInWithGoogle();

      // With Supabase Deep Link flow, the app will open a browser.
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google Sign Up failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithApple() async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthService>(context, listen: false).signInWithApple();
      // Apple OAuth also uses deep link callback, handled by _handleSuccessfulSignIn
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Apple Sign Up failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Image.asset('assets/icon2.png', fit: BoxFit.contain),
            Center(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                // Replace with your actual logo asset/icon
              ),
            ),
            const SizedBox(height: 30),

            // 2. Title
            Text(
              'Join the Watch Party',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
            const SizedBox(height: 8),

            // 3. Subtitle
            const Text(
              'Sign in or register to unlock your personal TV feed.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // 4. Sign In / Sign Up Segmented Control
            const ToggleButtonRow(),
            const SizedBox(height: 20),

            // 5. Form Fields
            AutofillGroup(
              child: Column(
                children: [
                  // First Name and Last Name in a Row
                  Row(
                    children: <Widget>[
                      // First Name Field
                      Expanded(
                        child: LabeledTextField(
                          label: 'First Name',
                          hintText: 'John',
                          controller: _firstNameController,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.givenName],
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Last Name Field
                      Expanded(
                        child: LabeledTextField(
                          label: 'Last Name',
                          hintText: 'Doe',
                          controller: _lastNameController,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.familyName],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Email Field
                  LabeledTextField(
                    label: 'Email',
                    hintText: 'johndoe@gmail.com',
                    keyboardType: TextInputType.emailAddress,
                    controller: _emailController,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  LabeledTextField(
                    label: 'Set Password',
                    hintText: '********',
                    isPassword: true,
                    controller: _passwordController,
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 6. Register Button
            Column(
              spacing: 10,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: PrimaryButton(
                    isLoading: _isLoading,
                    onTap: () {
                      if (!_isLoading) {
                        _register();
                      }
                    },
                    text: "Register",
                  ),
                ),
                const Text("Or With"),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUpWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.grey, width: 0.5),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      spacing: 10,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/glogo.png', width: 24, height: 24),
                        const Text(
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          'Continue With Google ',

                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SignInWithAppleButton(
                  onPressed: _isLoading ? null : _signUpWithApple,
                  style: Theme.of(context).brightness == Brightness.dark
                      ? SignInWithAppleButtonStyle.white
                      : SignInWithAppleButtonStyle.black,
                  height: 55,
                ),
                const SizedBox(height: 20),
                // Privacy Policy & Terms of Service
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      children: [
                        const TextSpan(
                          text: 'By continuing, you agree to our ',
                        ),
                        TextSpan(
                          text: 'Terms of Service',
                          style: const TextStyle(
                            color: primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              // TODO: Add navigation to Terms of Service
                            },
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: const TextStyle(
                            color: primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              // TODO: Add navigation to Privacy Policy
                            },
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Helper Widgets ---

// Custom Widget for the Labeled Text Fields
class LabeledTextField extends StatefulWidget {
  final String label;
  final String hintText;
  final TextInputType keyboardType;
  final bool isPassword;
  final TextEditingController? controller;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  const LabeledTextField({
    super.key,
    required this.label,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.controller,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<LabeledTextField> createState() => _LabeledTextFieldState();
}

class _LabeledTextFieldState extends State<LabeledTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword; // Initialize with widget property
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          obscureText: _obscureText,
          keyboardType: widget.keyboardType,
          autofillHints: widget.autofillHints,
          textCapitalization: widget.textCapitalization,
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            suffixIcon: widget.isPassword
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _obscureText = !_obscureText; // Toggle local state
                      });
                    },
                    child: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

// Custom Widget for the Log In / Sign Up Toggle
class ToggleButtonRow extends StatelessWidget {
  const ToggleButtonRow({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          // Log In Button (Inactive)
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Sign In',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
          // Sign Up Button (Active)
          Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Sign Up',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
