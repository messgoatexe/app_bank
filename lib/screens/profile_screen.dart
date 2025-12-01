import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    _nameCtrl.text = auth.user?.displayName ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text('Email : ${auth.user?.email ?? ''}'),
          const SizedBox(height: 12),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom affiché')),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : () async {
              setState(() { _loading = true; });
              await auth.updateProfile(displayName: _nameCtrl.text.trim());
              setState(() { _loading = false; });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis à jour')));
            },
            child: _loading ? const CircularProgressIndicator() : const Text('Mettre à jour'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              auth.signOut();
            },
            child: const Text('Se déconnecter'),
          )
        ]),
      ),
    );
  }
}
