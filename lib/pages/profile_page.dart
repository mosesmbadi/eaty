import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _mode = 'own';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mode = prefs.getString('meal_mode') ?? 'own';
      _loading = false;
    });
  }

  Future<void> _setMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('meal_mode', mode);
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        const Text('Meal Generation Mode:', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        RadioListTile<String>(
          title: const Text('Own Data'),
          value: 'own',
          groupValue: _mode,
          onChanged: (val) => _setMode('own'),
        ),
        RadioListTile<String>(
          title: const Text('Online (External Foods API)'),
          value: 'online',
          groupValue: _mode,
          onChanged: (val) => _setMode('online'),
        ),
      ],
    );
  }
}

