import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _endpointCtl = TextEditingController();
  final _apiKeyCtl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    _endpointCtl.text = prefs.getString('summarizeEndpoint') ?? '';
    _apiKeyCtl.text = prefs.getString('summarizeApiKey') ?? '';
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('summarizeEndpoint', _endpointCtl.text.trim());
    await prefs.setString('summarizeApiKey', _apiKeyCtl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  @override
  void dispose() {
    _endpointCtl.dispose();
    _apiKeyCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _endpointCtl,
                    decoration: const InputDecoration(labelText: 'Summarization Endpoint'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyCtl,
                    decoration: const InputDecoration(labelText: 'API Key (optional)'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _save,
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
    );
  }
}
