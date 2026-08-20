import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'app_feedback.dart';

const _leaf900 = Color(0xFF1F3524);
const _cream = Color(0xFFFFF8EE);
const _flame = Color(0xFFE0672F);

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, required this.email});

  final String email;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) {
      setState(() => _error = 'Saisissez les 6 chiffres reçus par email.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _post('/email/verify', {
        'email': widget.email,
        'code': _code.text,
      });
      if (!mounted) return;
      await AppFeedback.success(
        context,
        title: 'Email vérifié',
        message: 'Votre compte Hot Koki est maintenant sécurisé.',
      );
      if (mounted) Navigator.pop(context, data);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final data = await _post('/email/resend', {'email': widget.email});
      if (mounted) {
        await AppFeedback.success(
          context,
          title: 'Demande prise en compte',
          message: data['message'].toString(),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _cream,
    appBar: AppBar(title: const Text('Vérifier mon email')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 34,
                      backgroundColor: Color(0xFFFFE8E5),
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        color: _flame,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Consultez votre boîte mail',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: _leaf900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Un code temporaire a été envoyé à\n${widget.email}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _code,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 10,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Code à 6 chiffres',
                        counterText: '',
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _verify,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Valider le code'),
                      ),
                    ),
                    TextButton(
                      onPressed: _resending ? null : _resend,
                      child: Text(
                        _resending ? 'Envoi en cours…' : 'Renvoyer le code',
                      ),
                    ),
                    const Text(
                      'Le code expire après 10 minutes.',
                      style: TextStyle(fontSize: 11),
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

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email;
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_validEmail(_email.text)) {
      setState(() => _error = 'Saisissez une adresse email valide.');
      return;
    }
    await _run(() async {
      final data = await _post('/forgot-password', {
        'email': _email.text.trim(),
      });
      if (!mounted) return;
      setState(() => _codeSent = true);
      await AppFeedback.success(
        context,
        title: 'Vérifiez votre email',
        message: data['message'].toString(),
      );
    });
  }

  Future<void> _reset() async {
    if (_code.text.length != 6) {
      setState(() => _error = 'Le code doit contenir 6 chiffres.');
      return;
    }
    if (_password.text.length < 8) {
      setState(
        () => _error = 'Le mot de passe doit contenir au moins 8 caractères.',
      );
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }
    await _run(() async {
      final data = await _post('/reset-password', {
        'email': _email.text.trim(),
        'code': _code.text,
        'password': _password.text,
        'password_confirmation': _confirmation.text,
      });
      if (!mounted) return;
      await AppFeedback.success(
        context,
        title: 'Mot de passe modifié',
        message: data['message'].toString(),
      );
      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _cream,
    appBar: AppBar(title: const Text('Mot de passe oublié')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.lock_reset_rounded, size: 62, color: _flame),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              readOnly: _codeSent,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Adresse email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Code reçu',
                  counterText: '',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmation,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading
                    ? null
                    : (_codeSent ? _reset : _requestCode),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _codeSent
                            ? 'Réinitialiser mon mot de passe'
                            : 'Recevoir un code',
                      ),
              ),
            ),
            if (_codeSent)
              TextButton(
                onPressed: _loading ? null : _requestCode,
                child: const Text('Renvoyer le code'),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<Map<String, dynamic>> _post(
  String path,
  Map<String, dynamic> body,
) async {
  final response = await http
      .post(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) throw Exception(first.first);
    }
    throw Exception(data['message'] ?? 'Une erreur est survenue.');
  }
  return data;
}

bool _validEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

String _message(Object error) => error is TimeoutException
    ? 'Le serveur ne répond pas. Vérifiez votre connexion.'
    : error.toString().replaceFirst('Exception: ', '');
