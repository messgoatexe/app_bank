import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom (affiché)'),),
              const SizedBox(height: 8),
              TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => v==null||v.isEmpty?'Email requis':null,),
              const SizedBox(height: 8),
              TextFormField(controller: _pwdCtrl, decoration: const InputDecoration(labelText: 'Mot de passe'), obscureText: true, validator: (v)=>v==null||v.length<6?'6+ caractères':null,),
              const SizedBox(height: 16),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: _loading ? null : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() { _loading = true; _error = null; });
                  final ok = await auth.signUp(_emailCtrl.text.trim(), _pwdCtrl.text, displayName: _nameCtrl.text.trim());
                  setState(() { _loading = false; });
                  if (!ok) setState(() { _error = 'Impossible de créer le compte (email peut déjà exister)'; });
                  else Navigator.of(context).pop();
                },
                child: _loading ? const CircularProgressIndicator() : const Text('S\'inscrire'),
              ),
            ]),
          )
        ]),
      ),
    );
  }
}
