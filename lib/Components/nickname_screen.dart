import 'package:flutter/material.dart';
import 'package:smash_the_insect/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'firestore_service.dart';

class NicknameScreen extends StatefulWidget {
  final VoidCallback onNicknameSet;

  const NicknameScreen({
    Key? key,
    required this.onNicknameSet,
  }) : super(key: key);

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _nicknameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isChecking = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _validateAndSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isChecking = true;
        _errorMessage = null;
      });

      final nickname = _nicknameController.text.trim();

      // Check if nickname already exists
      final exists = await _firestoreService.checkNicknameExists(nickname);

      if (exists) {
        setState(() {
          _errorMessage = LocaleKeys.nickname_already_exists.tr();
          _isChecking = false;
        });
        return;
      }

      // Save nickname locally
      await _firestoreService.saveNicknameLocally(nickname);

      // Mark first launch as complete
      await _firestoreService.markFirstLaunchComplete();

      setState(() {
        _isChecking = false;
      });

      widget.onNicknameSet();
    }
  }

  String? _validateNickname(String? value) {
    if (value == null || value.isEmpty) {
      return LocaleKeys.nickname_required.tr();
    }

    final trimmed = value.trim();

    if (trimmed.length < 3) {
      return LocaleKeys.nickname_too_short.tr();
    }

    if (trimmed.length > 20) {
      return LocaleKeys.nickname_too_long.tr();
    }

    if (!_firestoreService.isValidNickname(trimmed)) {
      return LocaleKeys.nickname_invalid_chars.tr();
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF87CEEB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_add,
                    size: 80,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 40),

                // Title
                Text(
                  LocaleKeys.enter_nickname.tr(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 4,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Nickname input
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _nicknameController,
                          decoration: InputDecoration(
                            hintText: LocaleKeys.nickname_placeholder.tr(),
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                            prefixIcon: const Icon(
                              Icons.person,
                              color: Colors.white,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                          validator: _validateNickname,
                          textCapitalization: TextCapitalization.none,
                          autocorrect: false,
                          enabled: !_isChecking,
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isChecking ? null : _validateAndSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E8B57),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: Colors.black.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: _isChecking
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.play_arrow,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      LocaleKeys.start.tr(),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
