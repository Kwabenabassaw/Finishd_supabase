import 'package:finishd/onboarding/widgets/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:finishd/services/auth_service.dart';
import 'package:finishd/provider/user_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Define the primary color (Green from the image)
const Color primaryGreen = Color(0xFF1A8927);

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await Provider.of<AuthService>(context, listen: false)
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        // If new user (auto-created), go to onboarding
        if (result['isNewUser'] == true) {
          Navigator.pushReplacementNamed(context, 'genre');
        } else {
          // Initialize UserProvider with following IDs
          if (authService.currentUser != null) {
            Provider.of<UserProvider>(
              context,
              listen: false,
            ).fetchCurrentUser(authService.currentUser!.uid);
          }
          // Existing user, go to homepage
          Navigator.pushReplacementNamed(context, 'homepage');
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

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final result = await Provider.of<AuthService>(
        context,
        listen: false,
      ).signInWithGoogle();
      if (result == null) {
        // User canceled
        setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        // Check if new user or if existing user hasn't completed onboarding
        if (result['isNewUser'] == true ||
            result['onboardingCompleted'] != true) {
          Navigator.pushReplacementNamed(context, 'genre');
        } else {
          // Initialize UserProvider with following IDs
          if (authService.currentUser != null) {
            Provider.of<UserProvider>(
              context,
              listen: false,
            ).fetchCurrentUser(authService.currentUser!.uid);
          }
          // Existing user with completed onboarding
          Navigator.pushReplacementNamed(context, 'homepage');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google Sign In failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithApple() async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthService>(context, listen: false).signInWithApple();
      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        // Initialize UserProvider with following IDs
        if (authService.currentUser != null) {
          Provider.of<UserProvider>(
            context,
            listen: false,
          ).fetchCurrentUser(authService.currentUser!.uid);
        }
        Navigator.pushReplacementNamed(context, 'homepage');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Apple Sign In failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(

        padding: const EdgeInsets.symmetric(horizontal: 50.0, vertical: 10.0),
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
              'Log in or register to unlock your personal TV feed.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // 4. Log In / Sign Up Segmented Control
            const ToggleButtonRow(),
            const SizedBox(height: 30),

            // 5. Form Fields
            // Email Field
            LabeledTextField(
              label: 'Email',
              hintText: 'johndoe@gmail.com',
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
            ),
            const SizedBox(height: 20),

            // Password Field
            LabeledTextField(
              label: 'Set Password',
              hintText: '********',
              isPassword: true,
              controller: _passwordController,
            ),
            const SizedBox(height: 30),

            // 6. Register Button
            Column(
              spacing: 10,
              children: [
                PrimaryButton(
                  isLoading: _isLoading,
                  onTap: () {
                    if (!_isLoading) {
                      _login();
                    }
                  },
                  text: "Login",
                ),

                const Text("Or With"),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithGoogle,
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loginWithApple,
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
                      spacing: 14,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.apple,
                          size: 24.0,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.grey,
                        ),
                        const Text(
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          'Continue With Apple ',

                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
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

  const LabeledTextField({
    super.key,
    required this.label,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.controller,
  });

  @override
  State<LabeledTextField> createState() => _LabeledTextFieldState();
}

class _LabeledTextFieldState extends State<LabeledTextField> {
  late bool _obscureText = false;

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
                        _obscureText = !_obscureText;
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
          // Log In Button (Active)
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
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
                  'Log In',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ),
          // Sign Up Button (Inactive)
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.pushReplacementNamed(context, '/signup');
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Sign Up',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
