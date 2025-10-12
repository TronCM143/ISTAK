import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/authentication/service.dart';
import 'package:mobile/pages/home.dart';
import 'package:mobile/landingPage.dart';

class AuthPage extends StatefulWidget {
  final VoidCallback handleLogin;

  const AuthPage({super.key, required this.handleLogin});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController managerIdController = TextEditingController();
  List<Map<String, dynamic>> managers = [];
  bool isLoading = false;
  bool isLoginMode = true;
  bool isFetchingManagers = false;
  String? errorMessage;
  final AuthService authService = AuthService();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize the AnimationController for fade effect
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    // Start the fade-in animation
    _fadeController.forward();
    if (!isLoginMode) {
      fetchManagers();
    }
  }

  Future<void> fetchManagers() async {
    if (authService.baseUrl.isEmpty) {
      setState(() {
        isFetchingManagers = false;
        errorMessage = "Base URL is not configured";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD33F49), // --destructive
          content: Text(
            "Error: Base URL is not configured",
            style: GoogleFonts.ibmPlexMono(
              color: const Color(0xFFF5F7F5), // --card-foreground
              fontSize: 14,
            ),
          ),
        ),
      );
      return;
    }

    setState(() => isFetchingManagers = true);
    try {
      final url = Uri.parse("${authService.baseUrl}/api/managers/");
      final response = await http.get(
        url,
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          setState(() {
            managers = List<Map<String, dynamic>>.from(data).where((manager) {
              return manager['id'] != null && manager['username'] != null;
            }).toList();
            isFetchingManagers = false;
          });
        } else {
          throw Exception("Invalid response format");
        }
      } else {
        setState(() {
          isFetchingManagers = false;
          errorMessage = "Failed to load managers: ${response.statusCode}";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD33F49), // --destructive
            content: Text(
              "Failed to load managers: ${response.statusCode}",
              style: GoogleFonts.ibmPlexMono(
                color: const Color(0xFFF5F7F5), // --card-foreground
                fontSize: 14,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isFetchingManagers = false;
        errorMessage = "Error loading managers: $e";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD33F49), // --destructive
          content: Text(
            "Error loading managers: $e",
            style: GoogleFonts.ibmPlexMono(
              color: const Color(0xFFF5F7F5), // --card-foreground
              fontSize: 14,
            ),
          ),
        ),
      );
    }
  }

  Future<void> handleAuth() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    final Map<String, dynamic> response;
    if (isLoginMode) {
      response = await authService.loginUser(
        username: usernameController.text.trim(),
        password: passwordController.text.trim(),
      );
    } else {
      if (managerIdController.text.isEmpty) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD33F49), // --destructive
            content: Text(
              "Please select a manager",
              style: GoogleFonts.ibmPlexMono(
                color: const Color(0xFFF5F7F5), // --card-foreground
                fontSize: 14,
              ),
            ),
          ),
        );
        return;
      }
      response = await authService.registerUser(
        username: usernameController.text.trim(),
        password: passwordController.text.trim(),
        email: emailController.text.trim(),
        managerId: managerIdController.text.trim(),
      );
    }

    setState(() => isLoading = false);

    if (response["success"]) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E3638), // --card
          content: Text(
            isLoginMode
                ? "Login successful"
                : "Registration successful, pending approval",
            style: GoogleFonts.ibmPlexMono(
              color: const Color(0xFFF5F7F5), // --card-foreground
              fontSize: 14,
            ),
          ),
        ),
      );

      if (isLoginMode) {
        // Start fade-out before navigating
        await _fadeController.reverse();
        // Wait 3 seconds in "darkness" after fade-out
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(seconds: 1),
            reverseTransitionDuration: const Duration(seconds: 1),
            pageBuilder: (context, animation, secondaryAnimation) =>
                const NavShell(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        );
      } else {
        setState(() {
          isLoginMode = true;
          errorMessage = null;
          managers.clear();
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD33F49), // --destructive
          content: Text(
            response["error"] ??
                (isLoginMode ? "Login failed" : "Registration failed"),
            style: GoogleFonts.ibmPlexMono(
              color: const Color(0xFFF5F7F5), // --card-foreground
              fontSize: 14,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        resizeToAvoidBottomInset: false, // Prevent automatic resizing
        backgroundColor: Colors.transparent, // --background
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 20),
                          Hero(
                            tag: "istakLogo",
                            child: Material(
                              type: MaterialType.transparency,
                              child: Image(
                                image: const AssetImage("assets/fullLogo.png"),
                                width: 200,
                                height: 100,
                                //  fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color.fromARGB(
                                          255,
                                          42,
                                          42,
                                          42,
                                        ).withOpacity(0.08),
                                        const Color.fromARGB(
                                          255,
                                          42,
                                          41,
                                          41,
                                        ).withOpacity(0.04),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.16),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.35),
                                        blurRadius: 28,
                                        offset: const Offset(0, 16),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const SizedBox(height: 26),
                                      // Username
                                      Text(
                                        "Username",
                                        style: GoogleFonts.ibmPlexMono(
                                          color: const Color(0xFFA8B0B2),
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: usernameController,
                                        style: GoogleFonts.ibmPlexMono(
                                          color: const Color(0xFFF5F7F5),
                                        ),
                                        cursorColor: const Color(0xFF1A8B4A),
                                        decoration: _glassInputDecoration(
                                          hint: "Enter your username",
                                          icon: Icons.person_outline,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      if (!isLoginMode) ...[
                                        // Email
                                        Text(
                                          "Email",
                                          style: GoogleFonts.ibmPlexMono(
                                            color: const Color(0xFFA8B0B2),
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          style: GoogleFonts.ibmPlexMono(
                                            color: const Color(0xFFF5F7F5),
                                          ),
                                          cursorColor: const Color(0xFF1A8B4A),
                                          decoration: _glassInputDecoration(
                                            hint: "you@example.com",
                                            icon: Icons.mail_outline,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        // Manager
                                        Text(
                                          "Select Manager",
                                          style: GoogleFonts.ibmPlexMono(
                                            color: const Color(0xFFA8B0B2),
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        isFetchingManagers
                                            ? const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Color(0xFF1A8B4A),
                                                    ),
                                              )
                                            : (managers.isNotEmpty
                                                  ? DropdownButtonFormField<
                                                      String
                                                    >(
                                                      value:
                                                          (managerIdController
                                                              .text
                                                              .isEmpty)
                                                          ? null
                                                          : managerIdController
                                                                .text,
                                                      decoration:
                                                          _glassInputDecoration(
                                                            hint:
                                                                "Choose a manager",
                                                            icon: Icons
                                                                .supervisor_account_outlined,
                                                          ),
                                                      dropdownColor:
                                                          const Color(
                                                            0xFF303638,
                                                          ).withOpacity(0.8),
                                                      style:
                                                          GoogleFonts.ibmPlexMono(
                                                            color: const Color(
                                                              0xFFF5F7F5,
                                                            ),
                                                          ),
                                                      items: managers.map((m) {
                                                        return DropdownMenuItem<
                                                          String
                                                        >(
                                                          value: m['id']
                                                              .toString(),
                                                          child: Text(
                                                            m['username'],
                                                            style: GoogleFonts.ibmPlexMono(
                                                              color:
                                                                  const Color(
                                                                    0xFFF5F7F5,
                                                                  ),
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                      onChanged: (value) {
                                                        if (value != null)
                                                          managerIdController
                                                                  .text =
                                                              value;
                                                      },
                                                      validator: (value) =>
                                                          (value == null ||
                                                              value.isEmpty)
                                                          ? "Please select a manager"
                                                          : null,
                                                    )
                                                  : Text(
                                                      "No managers available",
                                                      style:
                                                          GoogleFonts.ibmPlexMono(
                                                            color: const Color(
                                                              0xFFD33F49,
                                                            ),
                                                            fontSize: 14,
                                                          ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    )),
                                        const SizedBox(height: 14),
                                      ],
                                      // Password
                                      Text(
                                        "Password",
                                        style: GoogleFonts.ibmPlexMono(
                                          color: const Color(0xFFA8B0B2),
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      StatefulBuilder(
                                        builder: (context, setSB) {
                                          bool obscure = true;
                                          return _PasswordField(
                                            controller: passwordController,
                                            obscure: obscure,
                                            toggle: () =>
                                                setSB(() => obscure = !obscure),
                                            decoration: _glassInputDecoration(
                                              hint: "••••••••",
                                              icon: Icons.lock_outline,
                                            ),
                                          );
                                        },
                                      ),
                                      if (errorMessage != null) ...[
                                        const SizedBox(height: 14),
                                        Text(
                                          errorMessage!,
                                          style: GoogleFonts.ibmPlexMono(
                                            color: const Color(0xFFD33F49),
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                      const SizedBox(height: 20),
                                      // Primary button (slightly luminous)
                                      isLoading
                                          ? const Center(
                                              child: CircularProgressIndicator(
                                                color: Color(0xFF1A8B4A),
                                              ),
                                            )
                                          : SizedBox(
                                              height: 48,
                                              child: ElevatedButton(
                                                onPressed: handleAuth,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF34C759,
                                                  ).withOpacity(0.9),
                                                  foregroundColor: const Color(
                                                    0xFF0D251F,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  elevation: 8,
                                                  shadowColor: Colors.black
                                                      .withOpacity(0.35),
                                                ),
                                                child: Text(
                                                  isLoginMode
                                                      ? "Sign In"
                                                      : "Sign Up",
                                                  style:
                                                      GoogleFonts.ibmPlexMono(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: const Color(
                                                          0xFF0D251F,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                            ),
                                      const SizedBox(height: 12),
                                      // Switch mode (glass accent link)
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            isLoginMode = !isLoginMode;
                                            errorMessage = null;
                                            if (!isLoginMode) {
                                              fetchManagers();
                                            } else {
                                              managers.clear();
                                              managerIdController.clear();
                                            }
                                          });
                                        },
                                        child: Text(
                                          isLoginMode ? "Sign Up" : "Sign In",
                                          style: GoogleFonts.ibmPlexMono(
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                            fontSize: 14,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: Colors.white
                                                .withOpacity(0.35),
                                          ),
                                        ),
                                      ),
                                      // Add extra space at the bottom to ensure scrollability
                                      SizedBox(
                                        height:
                                            MediaQuery.of(
                                              context,
                                            ).viewInsets.bottom +
                                            20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    emailController.dispose();
    managerIdController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}

InputDecoration _glassInputDecoration({required String hint, IconData? icon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFA8B0B2)),
    filled: true,
    fillColor: Colors.white.withOpacity(0.06),
    prefixIcon: icon == null
        ? null
        : Icon(icon, color: Colors.white.withOpacity(0.9)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFF1A8B4A), width: 1.4),
    ),
  );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.toggle,
    required this.decoration,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback toggle;
  final InputDecoration decoration;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscure;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      style: GoogleFonts.ibmPlexMono(color: const Color(0xFFF5F7F5)),
      cursorColor: const Color(0xFF1A8B4A),
      decoration: widget.decoration.copyWith(
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ),
    );
  }
}
