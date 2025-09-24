import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/authentication/service.dart';
import 'package:mobile/components/_landing_page.dart';

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
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(seconds: 1),
            reverseTransitionDuration: const Duration(seconds: 1),
            pageBuilder: (context, animation, secondaryAnimation) =>
                const Home(),
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
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent, // --background
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.transparent, // --card
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 200),
                      Text(
                        "Username",
                        style: GoogleFonts.ibmPlexMono(
                          color: const Color(0xFFA8B0B2), // --muted-foreground
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: usernameController,
                        style: GoogleFonts.ibmPlexMono(
                          color: const Color(0xFFF5F7F5), // --card-foreground
                        ),
                        cursorColor: const Color(0xFF1A8B4A), // --ring
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF3E4648), // --muted
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: Color(0x26FFFFFF), // --border
                            ),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: Color(0x3DFFFFFF), // --input
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: Color(0xFF1A8B4A), // --ring
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!isLoginMode) ...[
                        Text(
                          "Email",
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color(
                              0xFFA8B0B2,
                            ), // --muted-foreground
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: emailController,
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color(0xFFF5F7F5), // --card-foreground
                          ),
                          cursorColor: const Color(0xFF1A8B4A), // --ring
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF3E4648), // --muted
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Color(0x26FFFFFF), // --border
                              ),
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Color(0x3DFFFFFF), // --input
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Color(0xFF1A8B4A), // --ring
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Select Manager",
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color(
                              0xFFA8B0B2,
                            ), // --muted-foreground
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        isFetchingManagers
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF1A8B4A), // --ring
                                ),
                              )
                            : managers.isNotEmpty
                            ? DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF3E4648), // --muted
                                  border: const OutlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: Color(0x26FFFFFF), // --border
                                    ),
                                  ),
                                  enabledBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: Color(0x3DFFFFFF), // --input
                                    ),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: Color(0xFF1A8B4A), // --ring
                                    ),
                                  ),
                                ),
                                dropdownColor: const Color(
                                  0xFF3E4648,
                                ), // --muted
                                style: GoogleFonts.ibmPlexMono(
                                  color: const Color(
                                    0xFFF5F7F5,
                                  ), // --card-foreground
                                ),
                                items: managers.map((manager) {
                                  return DropdownMenuItem<String>(
                                    value: manager['id'].toString(),
                                    child: Text(
                                      manager['username'],
                                      style: GoogleFonts.ibmPlexMono(
                                        color: const Color(
                                          0xFFF5F7F5,
                                        ), // --card-foreground
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    managerIdController.text = value;
                                  }
                                },
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? "Please select a manager"
                                    : null,
                              )
                            : Text(
                                "No managers available",
                                style: GoogleFonts.ibmPlexMono(
                                  color: const Color(
                                    0xFFD33F49,
                                  ), // --destructive
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        "Password",
                        style: GoogleFonts.ibmPlexMono(
                          color: const Color(0xFFA8B0B2), // --muted-foreground
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: GoogleFonts.ibmPlexMono(
                          color: const Color(0xFFF5F7F5), // --card-foreground
                        ),
                        cursorColor: const Color(0xFF1A8B4A), // --ring
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF3E4648), // --muted
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: Color(0x26FFFFFF), // --border
                            ),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: Color(0x3DFFFFFF), // --input
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(
                              color: Color(0xFF1A8B4A), // --ring
                            ),
                          ),
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color(0xFFD33F49), // --destructive
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),
                      isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF1A8B4A), // --ring
                              ),
                            )
                          : ElevatedButton(
                              onPressed: handleAuth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF34C759,
                                ), // --primary
                                foregroundColor: const Color(
                                  0xFF1A3C34,
                                ), // --primary-foreground
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                                elevation: 2,
                                shadowColor: Colors.black.withOpacity(0.2),
                              ),
                              child: Text(
                                isLoginMode ? "Sign In" : "Sign Up",
                                style: GoogleFonts.ibmPlexMono(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(
                                    0xFF1A3C34,
                                  ), // --primary-foreground
                                ),
                              ),
                            ),
                      const SizedBox(height: 16),
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
                          isLoginMode
                              ? "Don't have an account? Sign Up"
                              : "Already have an account? Sign In",
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color(0xFF3E4648), // --accent
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
