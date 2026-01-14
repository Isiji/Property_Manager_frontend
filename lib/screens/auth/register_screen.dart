// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:property_manager_frontend/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();     // optional
  final _idController = TextEditingController();        // optional National ID
  final _passwordController = TextEditingController();  // required for non-tenant

  final _propertyCodeController = TextEditingController(); // tenant-only
  final _unitLabelController = TextEditingController();    // tenant-only (A2, Simba, Nyayo...)

  String _selectedRole = 'tenant';
  bool _loading = false;

  final List<String> _roles = ['tenant', 'landlord', 'manager', 'admin'];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    _propertyCodeController.dispose();
    _unitLabelController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
      final idNumber = _idController.text.trim().isEmpty ? null : _idController.text.trim();

      final propertyCode = _selectedRole == 'tenant' ? _propertyCodeController.text.trim() : null;
      final unitNumber = _selectedRole == 'tenant' ? _unitLabelController.text.trim() : null;

      // 1) Register
      await AuthService.registerUser(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: email,
        idNumber: idNumber,
        password: _selectedRole == 'tenant'
            ? (_passwordController.text.trim().isEmpty ? null : _passwordController.text.trim())
            : _passwordController.text.trim(),
        role: _selectedRole,
        propertyCode: propertyCode,
        unitNumber: unitNumber, // ✅ manual unit entry
      );

      // 2) Auto-login
      final login = await AuthService.loginUser(
        phone: _phoneController.text.trim(),
        password: _selectedRole == 'tenant'
            ? (_passwordController.text.trim().isEmpty ? null : _passwordController.text.trim())
            : _passwordController.text.trim(),
        role: _selectedRole,
      );

      if (!mounted) return;

      final role = (login['role'] ?? _selectedRole).toString();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration complete!')),
      );

      switch (role) {
        case 'tenant':
          Navigator.of(context).pushReplacementNamed('/tenant_home');
          break;
        case 'landlord':
          Navigator.of(context).pushReplacementNamed('/dashboard');
          break;
        case 'manager':
          Navigator.of(context).pushReplacementNamed('/manager_dashboard');
          break;
        case 'admin':
          Navigator.of(context).pushReplacementNamed('/admin_dashboard');
          break;
        default:
          Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4C51BF), Color(0xFF6B73FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Create your PropSmart account",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      _requiredField(_nameController, "Full Name", Icons.person),
                      const SizedBox(height: 10),
                      _requiredField(_phoneController, "Phone Number", Icons.phone),

                      const SizedBox(height: 10),
                      _optionalField(_emailController, "Email (optional)", Icons.email),
                      const SizedBox(height: 10),
                      _optionalField(_idController, "National ID (optional)", Icons.badge),

                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (_selectedRole == 'tenant') return null; // optional for tenant
                          if (v == null || v.trim().isEmpty) {
                            return 'Password is required for $_selectedRole';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        items: _roles
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r[0].toUpperCase() + r.substring(1)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedRole = val ?? 'tenant';
                            if (_selectedRole != 'tenant') {
                              _propertyCodeController.clear();
                              _unitLabelController.clear();
                            }
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: "Select Role",
                          prefixIcon: Icon(Icons.work_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      if (_selectedRole == 'tenant') ...[
                        const SizedBox(height: 10),
                        _requiredField(
                          _propertyCodeController,
                          "Property Code",
                          Icons.home_work_outlined,
                        ),
                        const SizedBox(height: 10),
                        _requiredField(
                          _unitLabelController,
                          "Unit Name/Number (e.g., A2, Simba, Nyayo)",
                          Icons.apartment,
                        ),
                      ],

                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _loading ? null : _register,
                          child: _loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Register", style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Already have an account? Login"),
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

  Widget _requiredField(
    TextEditingController c,
    String label,
    IconData icon, {
    void Function(String)? onChanged,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: c,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      validator: (v) => (v == null || v.trim().isEmpty) ? "$label cannot be empty" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _optionalField(TextEditingController c, String label, IconData icon) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
