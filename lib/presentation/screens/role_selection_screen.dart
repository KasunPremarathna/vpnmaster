import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user.dart';

class RoleSelectionScreen extends StatefulWidget {
  final AppUser user;
  const RoleSelectionScreen({super.key, required this.user});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  bool _isSaving = false;

  Future<void> _submit() async {
    if (_selectedRole == null) return;
    setState(() => _isSaving = true);
    try {
      await AuthService().createUserProfile(widget.user, _selectedRole!);
      // Auth stream in HomeScreen will catch the change
    } catch (e) {
      if (mounted) {
        // ignore: prefer_const_constructors
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: \$e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.account_circle_rounded, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const Text(
                'Welcome to VPN Master!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please select your role to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 48),
              
              _RoleCard(
                title: 'User',
                description: 'Browse the marketplace and import configurations.',
                icon: Icons.person_rounded,
                isSelected: _selectedRole == 'user',
                onTap: () => setState(() => _selectedRole = 'user'),
                selectedColor: Colors.blueAccent,
              ),
              
              const SizedBox(height: 16),
              
              _RoleCard(
                title: 'Seller',
                description: 'Distribute your VPN configurations to users.',
                icon: Icons.business_center_rounded,
                isSelected: _selectedRole == 'seller',
                onTap: () => setState(() => _selectedRole = 'seller'),
                selectedColor: Colors.amber,
              ),
              
              const Spacer(),
              
              ElevatedButton(
                onPressed: _selectedRole == null || _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.withAlpha(25),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('COMPLETE SIGNUP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => AuthService().signOut(),
                child: const Text('Log Out', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withAlpha(25) : Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.white10,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? selectedColor : Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? selectedColor : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: selectedColor, size: 24),
          ],
        ),
      ),
    );
  }
}
