import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/authentication/service.dart';
import 'package:mobile/components/landing_page.dart';

class AuthPage extends StatefulWidget {
  final VoidCallback handleLogin;

  const AuthPage({super.key, required this.handleLogin});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController managerIdController = TextEditingController();
  List<Map<String, dynamic>> managers = [];
  bool isLoading = false;
  bool isLoginMode = true;
  bool isFetchingManagers = false;
  final AuthService authService = AuthService();

  Future<void> fetchManagers() async {
    setState(() => isFetchingManagers = true);
    try {
      final url = Uri.parse("${authService.baseUrl}/api/managers/");
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          // remove Authorization entirely
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          managers = List<Map<String, dynamic>>.from(jsonDecode(response.body));
          isFetchingManagers = false;
        });
      } else {
        setState(() => isFetchingManagers = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load managers: ${response.statusCode}"),
          ),
        );
      }
    } catch (e) {
      setState(() => isFetchingManagers = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading managers: $e")));
    }
  }

  Future<void> handleAuth() async {
    setState(() => isLoading = true);

    final Map<String, dynamic> response;
    if (isLoginMode) {
      response = await authService.loginUser(
        username: usernameController.text.trim(),
        password: passwordController.text.trim(),
      );
    } else {
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
          content: Text(
            isLoginMode
                ? "Login successful"
                : "Registration successful, pending approval",
          ),
        ),
      );

      if (isLoginMode) {
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(seconds: 1), // slow down here
              reverseTransitionDuration: const Duration(seconds: 1),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const Home(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
            ),
          );
        });
      } else {
        setState(() => isLoginMode = true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response["error"] ??
                (isLoginMode ? "Login failed" : "Registration failed"),
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (!isLoginMode) {
      fetchManagers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 330),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 120,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const SizedBox(height: 32),
                TextField(
                  controller: usernameController,
                  style: GoogleFonts.ibmPlexMono(
                    color: const Color.fromARGB(255, 148, 148, 147),
                  ),
                  cursorColor: const Color.fromARGB(255, 103, 73, 49),
                  textAlignVertical:
                      TextAlignVertical.center, // ⬅️ centers text vertically
                  decoration: const InputDecoration(
                    labelText: "username",
                    border: InputBorder.none,
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                ),

                const SizedBox(height: 16),
                if (!isLoginMode) ...[
                  TextField(
                    controller: emailController,
                    style: GoogleFonts.ibmPlexMono(
                      color: const Color.fromARGB(255, 148, 148, 147),
                    ),
                    cursorColor: const Color.fromARGB(255, 103, 73, 49),
                    decoration: InputDecoration(
                      labelText: "Email",
                      labelStyle: GoogleFonts.ibmPlexMono(
                        color: const Color.fromARGB(255, 148, 148, 147),
                      ),
                      border: InputBorder.none, // 👈 no border
                      floatingLabelBehavior:
                          FloatingLabelBehavior.never, // 👈 no float
                    ),
                  ),

                  const SizedBox(height: 16),
                  isFetchingManagers
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: "Select Manager",
                            labelStyle: GoogleFonts.ibmPlexMono(
                              color: const Color.fromARGB(255, 148, 148, 147),
                            ),
                            border: InputBorder.none, // 👈 removes border
                            floatingLabelBehavior:
                                FloatingLabelBehavior.never, // 👈 prevent float
                          ),
                          dropdownColor: const Color.fromARGB(
                            255,
                            23,
                            20,
                            1,
                          ), // dark dropdown bg
                          style: GoogleFonts.ibmPlexMono(
                            color: const Color.fromARGB(255, 148, 148, 147),
                          ),
                          items: managers.map((manager) {
                            return DropdownMenuItem<String>(
                              value: manager['id'].toString(),
                              child: Text(
                                manager['username'],
                                style: GoogleFonts.ibmPlexMono(
                                  color: const Color.fromARGB(
                                    255,
                                    148,
                                    148,
                                    147,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            managerIdController.text = value ?? '';
                          },
                          validator: (value) => value == null || value.isEmpty
                              ? "Please select a manager"
                              : null,
                        ),

                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: GoogleFonts.ibmPlexMono(
                    color: const Color.fromARGB(255, 148, 148, 147),
                  ),
                  cursorColor: const Color.fromARGB(255, 103, 73, 49),
                  textAlignVertical:
                      TextAlignVertical.center, // ⬅️ centers text vertically
                  decoration: const InputDecoration(
                    labelText: "password",
                    border: InputBorder.none,
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                ),
                const SizedBox(height: 32),
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.transparent, // 👈 transparent background
                            shadowColor: Colors.transparent,
                            minimumSize: const Size(50, 50),
                          ),
                          child: Text(
                            isLoginMode ? "Login" : "Register",
                            style: GoogleFonts.ibmPlexMono(
                              color: const Color.fromARGB(255, 137, 135, 135),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 200),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        isLoginMode = !isLoginMode;
                        if (!isLoginMode) fetchManagers();
                      }),
                      child: Text(
                        isLoginMode ? "SIGNUP" : "SIGNIN",
                        style: GoogleFonts.ibmPlexMono(
                          color: const Color.fromARGB(255, 137, 135, 135),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
