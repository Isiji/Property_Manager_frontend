// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:property_manager_frontend/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String selectedRole = 'landlord';
  bool isLoading = false;

  final List<String> roles = ['admin', 'landlord', 'manager', 'tenant'];

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final phone = phoneController.text.trim();
    final pwd = passwordController.text.trim();

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number is required')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await AuthService.loginUser(
        phone: phone,
        password: selectedRole == 'tenant' ? null : pwd, // tenant can be passwordless
        role: selectedRole,
      );

      final role = (result['role'] ?? selectedRole).toString();
      final userId = result['userId'];
      print('🎯 Redirecting for role=$role (User ID=$userId)');

      if (!mounted) return;

      switch (role) {
        case 'landlord':
          Navigator.pushReplacementNamed(context, '/dashboard');
          break;
        case 'manager':
          Navigator.pushReplacementNamed(context, '/manager_dashboard');
          break;
        case 'tenant':
          // NEW: send tenants to the new tenant portal
          Navigator.pushReplacementNamed(context, '/tenant_home');
          break;
        case 'admin':
          Navigator.pushReplacementNamed(context, '/admin_dashboard');
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unknown role.')),
          );
      }
    } catch (e) {
      print('❌ Login failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'PropSmart Login',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Role selector
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    items: roles
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.toUpperCase()),
                          ),
                        )
                        .toList(),
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => selectedRole = v ?? 'landlord'),
                  ),

                  const SizedBox(height: 16),

                  // Phone
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 16),

                  // Password (hidden for tenant)
                  if (selectedRole != 'tenant')
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Login button
                  ElevatedButton(
                    onPressed: isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Login'),
                  ),

                  const SizedBox(height: 12),

                  // Register link
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
                    child: const Text("Don't have an account? Register here"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
