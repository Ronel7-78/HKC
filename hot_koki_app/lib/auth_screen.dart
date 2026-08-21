import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'app_feedback.dart';
import 'email_auth_screens.dart';
import 'legal_screen.dart';

class AuthResult {
  const AuthResult({required this.role, required this.name});
  final String role;
  final String name;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialRegister = false});
  final bool initialRegister;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _leaf900 = Color(0xFF1F3524);
  static const _leaf700 = Color(0xFF2E4E36);
  static const _cream2 = Color(0xFFF4F3F1);
  static const _flame500 = Color(0xFFF06424);
  static const _inkSoft = Color(0xFF6B6864);
  static const _storage = FlutterSecureStorage();

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _telephone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late bool _register;
  bool _loading = false;
  bool _obscure = true;
  bool _acceptedTerms = false;
  bool _locating = false;
  double? _latitude;
  double? _longitude;
  String? _locationLabel;
  String? _error;

  @override
  void initState() {
    super.initState();
    _register = widget.initialRegister;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _telephone.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_register &&
        (_latitude == null || _longitude == null || _locationLabel == null)) {
      setState(
        () => _error =
            'Utilise ta position actuelle pour définir l’adresse de livraison.',
      );
      return;
    }
    if (!_acceptedTerms) {
      setState(
        () => _error = 'Accepte les conditions d’utilisation pour continuer.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/${_register ? 'register' : 'login'}',
            ),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(
              _register
                  ? {
                      'name': _name.text.trim(),
                      'email': _email.text.trim(),
                      'telephone': _normalisePhone(_telephone.text),
                      'password': _password.text,
                      'password_confirmation': _confirmation.text,
                      'adresse_texte': _locationLabel,
                      'latitude': _latitude,
                      'longitude': _longitude,
                      'conditions_acceptees': _acceptedTerms,
                    }
                  : {
                      'email': _email.text.trim(),
                      'password': _password.text,
                      'conditions_acceptees': _acceptedTerms,
                    },
            ),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (data['code'] == 'EMAIL_NON_VERIFIE') {
          await _openVerification(
            (data['email'] ?? _email.text.trim()).toString(),
          );
          return;
        }
        throw Exception(_extractError(data));
      }

      if (data['verification_requise'] == true) {
        await _openVerification(_email.text.trim());
        return;
      }

      await _completeAuthentication(data, registered: _register);
    } catch (error) {
      if (mounted) {
        final message = error is TimeoutException
            ? 'Le serveur Hot Koki ne répond pas. Vérifiez que Laravel est démarré et que le téléphone utilise le même réseau.'
            : error.toString().replaceFirst('Exception: ', '');
        setState(() => _error = message);
        await AppFeedback.error(context, message: message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openVerification(String email) async {
    final data = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: email)),
    );
    if (data != null && mounted) {
      await _completeAuthentication(data, registered: _register);
    }
  }

  Future<void> _completeAuthentication(
    Map<String, dynamic> data, {
    required bool registered,
  }) async {
    final user = data['user'] as Map<String, dynamic>;
    await _storage.write(key: 'auth_token', value: data['token'].toString());
    if (!mounted) return;
    await AppFeedback.success(
      context,
      title: registered ? 'Compte créé' : 'Connexion réussie',
      message: registered
          ? 'Bienvenue chez Hot Koki ! Votre compte est prêt.'
          : 'Heureux de vous revoir.',
    );
    if (!mounted) return;
    Navigator.pop(
      context,
      AuthResult(role: user['role'].toString(), name: user['name'].toString()),
    );
  }

  String _normalisePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.startsWith('237') ? digits : '237$digits';
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Active la localisation du téléphone pour continuer.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw Exception('La permission de localisation a été refusée.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Autorise la localisation depuis les réglages du téléphone.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      String label = 'Position actuelle';
      try {
        final places = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (places.isNotEmpty) {
          final place = places.first;
          label =
              [
                    place.street,
                    place.subLocality,
                    place.locality,
                    place.administrativeArea,
                  ]
                  .where((part) => part != null && part.trim().isNotEmpty)
                  .map((part) => part!.trim())
                  .toSet()
                  .join(', ');
        }
      } catch (_) {
        label = 'Position actuelle détectée';
      }

      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationLabel = label;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String _extractError(Map<String, dynamic> data) {
    if (data['message'] != null) return data['message'].toString();
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return 'Une erreur est survenue. Réessaie.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream2,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_leaf700, _leaf900],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Center(
                      child: Image.asset(
                        'assets/images/hot_koki_logo.jpeg',
                        height: 94,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Le goût du quartier, livré chaud à Bertoua.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -25),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x19000000),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('Connexion'),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('Inscription'),
                            ),
                          ],
                          selected: {_register},
                          onSelectionChanged: (value) => setState(() {
                            _register = value.first;
                            _error = null;
                          }),
                        ),
                        if (_register) ...[
                          const SizedBox(height: 18),
                          _field(
                            _name,
                            'Nom complet',
                            Icons.person_outline,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Nom obligatoire'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: _cream2,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: _locationLabel == null
                                    ? Colors.transparent
                                    : _leaf700,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _locationLabel == null
                                          ? Icons.location_searching
                                          : Icons.location_on,
                                      color: _leaf700,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Adresse de livraison',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: _locationLabel != null,
                                      onChanged: _locating
                                          ? null
                                          : (enabled) {
                                              if (enabled) {
                                                _useCurrentLocation();
                                              } else {
                                                setState(() {
                                                  _latitude = null;
                                                  _longitude = null;
                                                  _locationLabel = null;
                                                });
                                              }
                                            },
                                    ),
                                  ],
                                ),
                                if (_locating)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: LinearProgressIndicator(
                                      color: _flame500,
                                    ),
                                  )
                                else if (_locationLabel != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: Text(
                                      _locationLabel!,
                                      style: const TextStyle(
                                        color: _inkSoft,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                else
                                  const Padding(
                                    padding: EdgeInsets.only(top: 5),
                                    child: Text(
                                      'Active pour détecter ta position. Les coordonnées restent invisibles et sécurisées.',
                                      style: TextStyle(
                                        color: _inkSoft,
                                        fontSize: 11,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _field(
                          _email,
                          'Adresse email',
                          Icons.email_outlined,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) => v == null || !v.contains('@')
                              ? 'Email invalide'
                              : null,
                        ),
                        if (_register) ...[
                          const SizedBox(height: 14),
                          _field(
                            _telephone,
                            'Téléphone',
                            Icons.phone_outlined,
                            keyboard: TextInputType.phone,
                            prefix: '+237 ',
                            validator: (v) =>
                                v == null ||
                                    v.replaceAll(RegExp(r'\D'), '').length != 9
                                ? 'Numéro camerounais invalide'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 14),
                        _field(
                          _password,
                          'Mot de passe',
                          Icons.lock_outline,
                          obscure: _obscure,
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                          validator: (v) => v == null || v.length < 8
                              ? '8 caractères minimum'
                              : null,
                        ),
                        if (!_register)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ForgotPasswordScreen(
                                          initialEmail: _email.text.trim(),
                                        ),
                                      ),
                                    ),
                              child: const Text('Mot de passe oublié ?'),
                            ),
                          ),
                        if (_register) ...[
                          const SizedBox(height: 14),
                          _field(
                            _confirmation,
                            'Confirmer le mot de passe',
                            Icons.lock_reset_outlined,
                            obscure: true,
                            validator: (v) => v != _password.text
                                ? 'Les mots de passe diffèrent'
                                : null,
                          ),
                        ],
                        CheckboxListTile(
                          value: _acceptedTerms,
                          onChanged: (value) =>
                              setState(() => _acceptedTerms = value ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'J’accepte les documents ci-dessous.',
                            style: TextStyle(fontSize: 11, color: _inkSoft),
                          ),
                          subtitle: Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _legalLink(
                                'Conditions d’utilisation',
                                LegalDocument.terms,
                              ),
                              const Text('et', style: TextStyle(fontSize: 11)),
                              _legalLink(
                                'Politique de confidentialité',
                                LegalDocument.privacy,
                              ),
                            ],
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: _flame500,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _register
                                        ? 'Créer mon compte'
                                        : 'Se connecter',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    bool obscure = false,
    String? prefix,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: _cream2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: _flame500, width: 1.5),
        ),
      ),
    );
  }

  Widget _legalLink(String label, LegalDocument document) => TextButton(
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LegalScreen(document: document)),
    ),
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(label, style: const TextStyle(fontSize: 11)),
  );
}
