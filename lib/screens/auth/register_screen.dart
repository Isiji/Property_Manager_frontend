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
  final _emailController = TextEditingController(); // optional
  final _idController = TextEditingController();    // optional National ID
  final _passwordController = TextEditingController();

  final _propertyCodeController = TextEditingController(); // tenant-only
  final _unitIdController = TextEditingController();       // tenant-only

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
    _unitIdController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
      final idNumber = _idController.text.trim().isEmpty ? null : _idController.text.trim();

      await AuthService.registerUser(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: email,
        idNumber: idNumber, // mapped to id_number in AuthService
        password: _passwordController.text.trim(),
        role: _selectedRole,
        propertyCode: _selectedRole == 'tenant'
            ? _propertyCodeController.text.trim()
            : null,
        unitId: _selectedRole == 'tenant'
            ? int.tryParse(_unitIdController.text.trim())
            : null,
      );

      if (!mounted) return;

      // Success UX
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful! Please log in.')),
      );

      // 🔁 Redirect logic:
      // Landlord: hard redirect to /login and clear back stack
      // Others: simply pop back (assuming they came from /login)
      if (_selectedRole == 'landlord') {
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      } else {
        // Go back to previous screen (often the login)
        Navigator.pop(context);
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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

                      // Required fields
                      _requiredField(_nameController, "Full Name", Icons.person),
                      const SizedBox(height: 10),
                      _requiredField(_phoneController, "Phone Number", Icons.phone),

                      const SizedBox(height: 10),

                      // Optional email + National ID
                      _optionalField(_emailController, "Email (optional)", Icons.email),
                      const SizedBox(height: 10),
                      _optionalField(_idController, "National ID (optional)", Icons.badge),

                      const SizedBox(height: 10),

                      // Required password (unless tenant with OTP flows—in your case required for non-tenant)
                      _requiredField(_passwordController, "Password", Icons.lock, isPassword: true),

                      const SizedBox(height: 10),

                      // Role selector
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
                              _unitIdController.clear();
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
                        _requiredField(_propertyCodeController, "Property Code", Icons.home_work_outlined),
                        const SizedBox(height: 10),
                        _requiredNumericField(_unitIdController, "Unit ID (number)", Icons.apartment),
                      ],

                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _loading ? null : _register,
                          child: _loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Register", style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _loading ? null : () => Navigator.pop(context),
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

  // ---------- Field Builders ----------

  Widget _requiredField(
    TextEditingController c,
    String label,
    IconData icon, {
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: c,
      obscureText: isPassword,
      validator: (v) => (v == null || v.trim().isEmpty) ? "$label cannot be empty" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _requiredNumericField(TextEditingController c, String label, IconData icon) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.number,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return "$label cannot be empty";
        final n = int.tryParse(v.trim());
        if (n == null) return "Enter a valid number";
        return null;
      },
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
