// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:property_manager_frontend/services/auth_service.dart';
import 'package:property_manager_frontend/core/config.dart';

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
  final _unitLabelController = TextEditingController();    // tenant-only (label like A3, B1)

  String _selectedRole = 'tenant';
  bool _loading = false;

  final List<String> _roles = ['tenant', 'landlord', 'manager', 'admin'];

  // Autocomplete data
  List<Map<String, dynamic>> _unitOptions = [];
  int? _chosenUnitId;

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

  Future<void> _fetchUnits() async {
    final code = _propertyCodeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _unitOptions = [];
        _chosenUnitId = null;
      });
      return;
    }

    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/properties/by-code/$code/units');
      final res = await http.get(url, headers: {"Content-Type": "application/json"});
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List) {
          setState(() {
            _unitOptions = list.cast<Map<String, dynamic>>();
          });
        }
      } else {
        setState(() {
          _unitOptions = [];
          _chosenUnitId = null;
        });
      }
    } catch (e) {
      setState(() {
        _unitOptions = [];
        _chosenUnitId = null;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // If tenant, ensure we either matched a unit option or fallback to number parsing error-less path
    if (_selectedRole == 'tenant' && _chosenUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a valid unit from suggestions.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
      final idNumber = _idController.text.trim().isEmpty ? null : _idController.text.trim();

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
        propertyCode: _selectedRole == 'tenant' ? _propertyCodeController.text.trim() : null,
        unitId: _selectedRole == 'tenant' ? _chosenUnitId : null, // <-- from autocomplete
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

      // 3) Route by role
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

                      // Required
                      _requiredField(_nameController, "Full Name", Icons.person),
                      const SizedBox(height: 10),
                      _requiredField(_phoneController, "Phone Number", Icons.phone),

                      const SizedBox(height: 10),

                      // Optional
                      _optionalField(_emailController, "Email (optional)", Icons.email),
                      const SizedBox(height: 10),
                      _optionalField(_idController, "National ID (optional)", Icons.badge),

                      const SizedBox(height: 10),

                      // Password (required for non-tenant; optional for tenant)
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (_selectedRole == 'tenant') {
                            return null; // optional
                          }
                          if (v == null || v.trim().isEmpty) {
                            return 'Password is required for $_selectedRole';
                          }
                          return null;
                        },
                      ),

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
                              _unitLabelController.clear();
                              _unitOptions = [];
                              _chosenUnitId = null;
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
                          onChanged: (_) => _fetchUnits(),
                          onFieldSubmitted: (_) => _fetchUnits(),
                        ),
                        const SizedBox(height: 10),

                        // Autocomplete for Unit (label)
                        RawAutocomplete<Map<String, dynamic>>(
                          textEditingController: _unitLabelController,
                          focusNode: FocusNode(),
                          optionsBuilder: (TextEditingValue tv) {
                            final q = tv.text.toLowerCase().trim();
                            if (q.isEmpty) return _unitOptions;
                            return _unitOptions.where((m) {
                              final label = (m['label'] ?? '').toString().toLowerCase();
                              return label.contains(q);
                            });
                          },
                          displayStringForOption: (m) => (m['label'] ?? '').toString(),
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: 'Unit (e.g., A3, B1)',
                                prefixIcon: Icon(Icons.apartment),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return "Unit is required";
                                // ensure selection maps to an option
                                final match = _unitOptions.firstWhere(
                                  (m) => (m['label'] ?? '').toString().trim().toLowerCase() == v.trim().toLowerCase(),
                                  orElse: () => {},
                                );
                                if (match.isEmpty) return "Pick a valid unit from suggestions";
                                return null;
                              },
                              onChanged: (v) {
                                final match = _unitOptions.firstWhere(
                                  (m) => (m['label'] ?? '').toString().trim().toLowerCase() == v.trim().toLowerCase(),
                                  orElse: () => {},
                                );
                                setState(() {
                                  _chosenUnitId = match.isEmpty ? null : (match['id'] as num?)?.toInt();
                                });
                              },
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                child: SizedBox(
                                  width: 360,
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (_, i) {
                                      final m = options.elementAt(i);
                                      final label = (m['label'] ?? '').toString();
                                      return ListTile(
                                        title: Text(label),
                                        onTap: () {
                                          onSelected(m);
                                          _unitLabelController.text = label;
                                          setState(() => _chosenUnitId = (m['id'] as num).toInt());
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
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

  // ---------- Field helpers ----------

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
