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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _propertyCodeController = TextEditingController();
  final _unitIdController = TextEditingController();

  String _selectedRole = 'tenant';
  bool _loading = false;

  final List<String> _roles = ['tenant', 'landlord', 'manager', 'admin'];

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await AuthService.registerUser(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful!')),
      );
      Navigator.pop(context); // go back to login
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    } finally {
      setState(() => _loading = false);
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
                      _buildTextField(_nameController, "Full Name", Icons.person),
                      const SizedBox(height: 10),
                      _buildTextField(_phoneController, "Phone Number", Icons.phone),
                      const SizedBox(height: 10),
                      _buildTextField(_emailController, "Email (optional)", Icons.email),
                      const SizedBox(height: 10),
                      _buildTextField(_passwordController, "Password", Icons.lock,
                          isPassword: true),
                      const SizedBox(height: 10),

                      // Role selector
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        items: _roles.map((r) {
                          return DropdownMenuItem(
                            value: r,
                            child: Text(r[0].toUpperCase() + r.substring(1)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedRole = val ?? 'tenant');
                        },
                        decoration: const InputDecoration(
                          labelText: "Select Role",
                          prefixIcon: Icon(Icons.work_outline),
                        ),
                      ),

                      if (_selectedRole == 'tenant') ...[
                        const SizedBox(height: 10),
                        _buildTextField(_propertyCodeController, "Property Code",
                            Icons.home_work_outlined),
                        const SizedBox(height: 10),
                        _buildTextField(_unitIdController, "Unit ID (number)",
                            Icons.apartment),
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
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Register",
                                  style: TextStyle(fontSize: 16),
                                ),
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      {bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? "$label cannot be empty" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
