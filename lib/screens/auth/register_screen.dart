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

  // Shared inputs (labels change depending on manager type)
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController(); // optional
  final _idController = TextEditingController(); // optional National ID
  final _passwordController = TextEditingController(); // required for non-tenant

  // Tenant-only
  final _propertyCodeController = TextEditingController();
  final _unitLabelController = TextEditingController();

  // Agency optional extras
  final _contactPersonController = TextEditingController(); // optional
  final _officePhoneController = TextEditingController(); // optional override
  final _officeEmailController = TextEditingController(); // optional override

  String _selectedRole = 'tenant';
  String _managerType = 'individual'; // individual | agency
  bool _loading = false;

  final List<String> _roles = ['tenant', 'landlord', 'manager', 'admin'];

  bool get _isTenant => _selectedRole == 'tenant';
  bool get _isManager => _selectedRole == 'manager';
  bool get _isAgency => _isManager && _managerType == 'agency';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idController.dispose();
    _passwordController.dispose();

    _propertyCodeController.dispose();
    _unitLabelController.dispose();

    _contactPersonController.dispose();
    _officePhoneController.dispose();
    _officeEmailController.dispose();
    super.dispose();
  }

  void _onRoleChanged(String? val) {
    setState(() {
      _selectedRole = val ?? 'tenant';

      // clear tenant fields if not tenant
      if (!_isTenant) {
        _propertyCodeController.clear();
        _unitLabelController.clear();
      }

      // clear manager extras if not manager
      if (!_isManager) {
        _managerType = 'individual';
        _contactPersonController.clear();
        _officePhoneController.clear();
        _officeEmailController.clear();
      }
    });
  }

  void _onManagerTypeChanged(String? v) {
    setState(() {
      _managerType = v ?? 'individual';
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
      final idNumber = _idController.text.trim().isEmpty ? null : _idController.text.trim();

      // Tenant
      final propertyCode = _isTenant ? _propertyCodeController.text.trim() : null;
      final unitNumber = _isTenant ? _unitLabelController.text.trim() : null;

      // Agency mapping (avoid double entry)
      final companyName = _isAgency ? _nameController.text.trim() : null;

      final companyOfficePhone = _isAgency
          ? (_officePhoneController.text.trim().isEmpty
              ? _phoneController.text.trim()
              : _officePhoneController.text.trim())
          : null;

      final companyOfficeEmail = _isAgency
          ? (_officeEmailController.text.trim().isEmpty ? email : _officeEmailController.text.trim())
          : null;

      final contactPerson = _isAgency
          ? (_contactPersonController.text.trim().isEmpty ? null : _contactPersonController.text.trim())
          : null;

      // 1) Register
      await AuthService.registerUser(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: email,
        idNumber: idNumber,
        password: _isTenant
            ? (_passwordController.text.trim().isEmpty ? null : _passwordController.text.trim())
            : _passwordController.text.trim(),
        role: _selectedRole,
        propertyCode: propertyCode,
        unitNumber: unitNumber,

        // manager / agency extras
        managerType: _isManager ? _managerType : null, // ✅ no unused local variable now
        companyName: companyName,
        contactPerson: contactPerson,
        officePhone: companyOfficePhone,
        officeEmail: (companyOfficeEmail?.trim().isEmpty == true) ? null : companyOfficeEmail,
      );

      // 2) Auto-login
      final login = await AuthService.loginUser(
        phone: _phoneController.text.trim(),
        password: _isTenant
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

    final nameLabel = _isAgency ? "Company Name" : "Full Name";
    final phoneLabel = _isAgency ? "Company Phone" : "Phone Number";
    final emailLabel = _isAgency ? "Company Email (optional)" : "Email (optional)";

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

                      // ✅ Role FIRST
                      DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        items: _roles
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r[0].toUpperCase() + r.substring(1)),
                                ))
                            .toList(),
                        onChanged: _onRoleChanged,
                        decoration: const InputDecoration(
                          labelText: "Account type",
                          prefixIcon: Icon(Icons.work_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      // ✅ Manager type SECOND (only if manager)
                      if (_isManager) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Manager type',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                value: 'individual',
                                groupValue: _managerType,
                                dense: true,
                                title: const Text('Individual'),
                                onChanged: _onManagerTypeChanged,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                value: 'agency',
                                groupValue: _managerType,
                                dense: true,
                                title: const Text('Agency'),
                                onChanged: _onManagerTypeChanged,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      _requiredField(_nameController, nameLabel, _isAgency ? Icons.business : Icons.person),
                      const SizedBox(height: 10),
                      _requiredField(_phoneController, phoneLabel, Icons.phone),

                      const SizedBox(height: 10),
                      _optionalField(_emailController, emailLabel, Icons.email),
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
                          if (_isTenant) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Password is required for $_selectedRole';
                          }
                          return null;
                        },
                      ),

                      if (_isTenant) ...[
                        const SizedBox(height: 10),
                        _requiredField(_propertyCodeController, "Property Code", Icons.home_work_outlined),
                        const SizedBox(height: 10),
                        _requiredField(_unitLabelController, "Unit Name/Number (e.g., A2, Simba, Nyayo)", Icons.apartment),
                      ],

                      if (_isAgency) ...[
                        const SizedBox(height: 12),
                        _optionalField(_contactPersonController, "Contact Person (optional)", Icons.person_outline),
                        const SizedBox(height: 10),
                        _optionalField(_officePhoneController, "Office Phone (optional override)", Icons.call),
                        const SizedBox(height: 10),
                        _optionalField(_officeEmailController, "Office Email (optional override)", Icons.alternate_email),
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

  Widget _requiredField(TextEditingController c, String label, IconData icon) {
    return TextFormField(
      controller: c,
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
