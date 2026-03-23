import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/avatar_catalog_service.dart';
import '../services/supabase_service.dart';

class CharacterCreationScreen extends StatefulWidget {
  const CharacterCreationScreen({super.key});

  @override
  State<CharacterCreationScreen> createState() => _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  static const _archetypes = ['fresh_start', 'serious', 'beast_mode', 'elite'];
  static const _genderOptions = ['male', 'female', 'nb'];
  static const _bodyTypeOptions = ['lean', 'athletic', 'buff'];
  static const _hairOptions = ['short', 'long', 'fade', 'bun', 'curly'];
  static const _outfitOptions = ['athleisure', 'performance', 'street', 'pro'];
  static const _skinPalette = [
    Color(0xFFF2D1A6),
    Color(0xFFE8BD78),
    Color(0xFFD9A55B),
    Color(0xFFB27337),
    Color(0xFFC98A43),
    Color(0xFF824F1F),
  ];

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selected = _archetypes.first;
  String _gender = _genderOptions.first;
  String _bodyType = _bodyTypeOptions.first;
  int _hairId = 1;
  int _skinId = 1;
  int _outfitId = 1;
  int _avatarSeed = 1;
  int _avatarQueryNonce = 0;
  int _avatarChoiceIndex = 0;
  bool _avatarLoading = false;
  bool _saving = false;
  String? _message;
  final _avatarCatalog = AvatarCatalogService();
  List<String> _catalogAvatarUrls = const [];

  static const _bgTop = Color(0xFF04181C);
  static const _bgBottom = Color(0xFF040814);
  static const _cardBg = Color(0xFF101828);
  static const _cardBorder = Color(0xFF1F2F3E);
  static const _accent = Color(0xFF1DF7D4);
  static const _textPrimary = Color(0xFFEAF2FF);
  static const _textMuted = Color(0xFF8A9AAC);

  @override
  void initState() {
    super.initState();
    _loadCatalogAvatars();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  String _skinToneKey() {
    if (_skinId <= 2) return 'fair';
    if (_skinId == 3) return 'medium';
    if (_skinId <= 5) return 'tan';
    return 'deep';
  }

  Future<void> _loadCatalogAvatars() async {
    final nonce = ++_avatarQueryNonce;

    setState(() {
      _avatarLoading = true;
    });

    try {
      final urls = await _avatarCatalog.fetchMatchingUrls(
        gender: _gender,
        bodyType: _bodyType,
        skinTone: _skinToneKey(),
      );

      if (!mounted || nonce != _avatarQueryNonce) return;

      setState(() {
        _catalogAvatarUrls = urls;
        _avatarChoiceIndex = 0;
      });
    } catch (_) {
      if (!mounted || nonce != _avatarQueryNonce) return;
      setState(() {
        _catalogAvatarUrls = const [];
      });
    } finally {
      if (mounted && nonce == _avatarQueryNonce) {
        setState(() {
          _avatarLoading = false;
        });
      }
    }
  }

  void _cycleAvatar() {
    if (_catalogAvatarUrls.isNotEmpty) {
      setState(() {
        _avatarChoiceIndex = (_avatarChoiceIndex + 1) % _catalogAvatarUrls.length;
      });
      return;
    }

    setState(() {
      _avatarSeed = DateTime.now().millisecondsSinceEpoch;
    });
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim());

    if (uid == null) {
      setState(() => _message = 'No Firebase user found. Return to Splash.');
      return;
    }
    if (name.length < 3 || name.length > 20) {
      setState(() => _message = 'Name should be between 3 and 20 characters.');
      return;
    }
    if (age == null || age < 13 || age > 100) {
      setState(() => _message = 'Enter a valid age between 13 and 100.');
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      await SupabaseService.ensureInitialized();

      final response = await SupabaseService.client.functions.invoke(
        'sync-user',
        headers: {'x-fitcity-uid': uid},
        body: {
          'name': name,
          'archetype': _selected,
          'avatar_config': {
            'hair_id': _hairId,
            'skin_id': _skinId,
            'outfit_id': _outfitId,
            'gender': _gender,
            'body_type': _bodyType,
            'avatar_url': _avatarUrl(),
            'avatar_source': _catalogAvatarUrls.isNotEmpty ? 'supabase_ai_catalog' : 'dicebear_fallback',
          },
          'district_name': '$name\'s District',
          'real_age': age,
        },
      );

      if (response.status >= 400) {
        throw Exception('sync-user failed: ${response.data}');
      }

      if (!mounted) return;
      context.go('/tasks');
    } catch (e) {
      setState(() => _message = 'Save failed: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  IconData _genderIcon(String g) {
    switch (g) {
      case 'male':
        return Icons.male;
      case 'female':
        return Icons.female;
      default:
        return Icons.transgender;
    }
  }

  IconData _bodyTypeIcon(String b) {
    switch (b) {
      case 'lean':
        return Icons.accessibility_new;
      case 'athletic':
        return Icons.sports_gymnastics;
      default:
        return Icons.fitness_center;
    }
  }

  String _archetypeTitle(String a) {
    if (a == 'fresh_start') return 'Fresh Start';
    if (a == 'beast_mode') return 'Beast Mode';
    if (a == 'elite') return 'Elite Athlete';
    return 'Serious';
  }

  String _archetypeSubtitle(String a) {
    if (a == 'fresh_start') return 'Beginner focus';
    if (a == 'beast_mode') return 'Advanced grind';
    if (a == 'elite') return 'Pro performance';
    return 'Intermediate';
  }

  String _archetypeEmoji(String a) {
    if (a == 'fresh_start') return '🌱';
    if (a == 'beast_mode') return '🔥';
    if (a == 'elite') return '🏆';
    return '💪';
  }

  IconData _hairIcon(String hair) {
    if (hair == 'short') return Icons.content_cut;
    if (hair == 'long') return Icons.face_6;
    if (hair == 'fade') return Icons.auto_fix_high;
    if (hair == 'bun') return Icons.face_retouching_natural;
    return Icons.waves;
  }

  IconData _outfitIcon(String outfit) {
    if (outfit == 'athleisure') return Icons.checkroom;
    if (outfit == 'performance') return Icons.sports;
    if (outfit == 'street') return Icons.style;
    return Icons.workspace_premium;
  }

  String _avatarUrl() {
    if (_catalogAvatarUrls.isNotEmpty) {
      return _catalogAvatarUrls[_avatarChoiceIndex % _catalogAvatarUrls.length];
    }

    final seed = '${_nameController.text.trim().isEmpty ? 'fitcity' : _nameController.text.trim()}-$_gender-$_bodyType-h$_hairId-s$_skinId-o$_outfitId-$_selected-$_avatarSeed';
    final encoded = Uri.encodeComponent(seed);
    return 'https://api.dicebear.com/9.x/personas/png?seed=$encoded&backgroundType=gradientLinear';
  }

  InputDecoration _pillInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: _textMuted),
      counterText: '',
      filled: true,
      fillColor: const Color(0xFF0E1C2A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: _accent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasName = _nameController.text.trim().length >= 3;
    final parsedAge = int.tryParse(_ageController.text.trim());
    final hasAge = parsedAge != null && parsedAge >= 13 && parsedAge <= 100;

    return Scaffold(
      backgroundColor: _bgBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 26),
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/splash');
                      }
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: const Icon(Icons.arrow_back, color: _textPrimary),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'FITCITY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Create Your',
                style: TextStyle(color: _textPrimary, fontSize: 50 / 2, fontWeight: FontWeight.w700),
              ),
              const Text(
                'Character',
                style: TextStyle(color: _accent, fontSize: 56 / 2, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1C2A),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: hasName ? _accent : Colors.white12),
                      ),
                      child: Text(
                        hasName ? 'Name ready' : 'Add character name',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: hasName ? _accent : _textMuted, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1C2A),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: hasAge ? _accent : Colors.white12),
                      ),
                      child: Text(
                        hasAge ? 'Age ready' : 'Add age',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: hasAge ? _accent : _textMuted, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: _cardBorder),
                  boxShadow: [
                    BoxShadow(color: _accent.withValues(alpha: 0.06), blurRadius: 20, spreadRadius: 2),
                  ],
                ),
                child: Stack(
                  children: [
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF374557), Color(0xFF111827)],
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.06),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Transform(
                                alignment: Alignment.bottomCenter,
                                transform: Matrix4.identity()
                                  ..translate(0.0, 14.0)
                                  ..scale(1.34),
                                child: Image.network(
                                  _avatarUrl(),
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(color: _accent),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(Icons.person, size: 120, color: Color(0x55FFFFFF)),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: InkWell(
                        onTap: _cycleAvatar,
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                          ),
                          child: const Icon(Icons.autorenew, size: 20, color: _textPrimary),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'CHARACTER NAME',
                style: TextStyle(color: _textMuted, fontWeight: FontWeight.w700, letterSpacing: 2.0, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                maxLength: 20,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: _textPrimary, fontSize: 16),
                decoration: _pillInputDecoration('Enter name...'),
              ),
              const SizedBox(height: 18),
              const Text(
                'YOUR AGE',
                style: TextStyle(color: _textMuted, fontWeight: FontWeight.w700, letterSpacing: 2.0, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _textPrimary, fontSize: 16),
                decoration: _pillInputDecoration('Enter age (13-100)'),
              ),
              const SizedBox(height: 18),
              const Text(
                'GENDER IDENTITY',
                style: TextStyle(color: _textMuted, fontWeight: FontWeight.w700, letterSpacing: 2.0, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: _genderOptions.map((g) {
                  final selected = _gender == g;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() => _gender = g);
                          _loadCatalogAvatars();
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: selected ? _accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: selected ? _accent : Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_genderIcon(g), color: selected ? _accent : _textMuted, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                g == 'nb' ? 'NB' : '${g[0].toUpperCase()}${g.substring(1)}',
                                style: TextStyle(color: selected ? _textPrimary : _textMuted, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              const Text(
                'BODY TYPE',
                style: TextStyle(color: _textMuted, fontWeight: FontWeight.w700, letterSpacing: 2.0, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: _bodyTypeOptions.map((b) {
                  final selected = _bodyType == b;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() => _bodyType = b);
                          _loadCatalogAvatars();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 104,
                          decoration: BoxDecoration(
                            color: selected ? _accent.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: selected ? _accent : Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_bodyTypeIcon(b), color: selected ? _accent : _textMuted, size: 30),
                              const SizedBox(height: 8),
                              Text(
                                '${b[0].toUpperCase()}${b.substring(1)}',
                                style: TextStyle(color: selected ? _textPrimary : _textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              const Text(
                'SKIN TONE',
                style: TextStyle(color: _textMuted, fontWeight: FontWeight.w700, letterSpacing: 2.0, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_skinPalette.length, (i) {
                  final selected = _skinId == i + 1;
                  return InkWell(
                    onTap: () {
                      setState(() => _skinId = i + 1);
                      _loadCatalogAvatars();
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _skinPalette[i],
                        shape: BoxShape.circle,
                        border: Border.all(color: selected ? _accent : Colors.white24, width: selected ? 3 : 1),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
              if (_avatarLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(color: _accent),
                ),
              const Text(
                'HAIR STYLE',
                style: TextStyle(color: _textMuted, fontWeight: FontWeight.w700, letterSpacing: 2.0, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(_hairOptions.length, (index) {
                  final isSelected = _hairId == index + 1;
                  final hair = _hairOptions[index];
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index == _hairOptions.length - 1 ? 0 : 8),
                      child: InkWell(
                        onTap: () => setState(() => _hairId = index + 1),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: isSelected ? _accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: isSelected ? _accent : Colors.white12),
                          ),
                          child: Icon(
                            _hairIcon(hair),
                            color: isSelected ? _accent : _textMuted,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
              const Text(
                'OUTFIT VIBE',
                style: TextStyle(color: _textMuted, fontWeight: FontWeight.w700, letterSpacing: 2.0, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(_outfitOptions.length, (index) {
                  final isSelected = _outfitId == index + 1;
                  final outfit = _outfitOptions[index];
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index == _outfitOptions.length - 1 ? 0 : 8),
                      child: InkWell(
                        onTap: () => setState(() => _outfitId = index + 1),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: isSelected ? _accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: isSelected ? _accent : Colors.white12),
                          ),
                          child: Icon(
                            _outfitIcon(outfit),
                            color: isSelected ? _accent : _textMuted,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
              const Text(
                'CHOOSE YOUR FITNESS ERA',
                style: TextStyle(color: _textMuted, fontWeight: FontWeight.w700, letterSpacing: 2.0, fontSize: 12),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _archetypes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.08,
                ),
                itemBuilder: (context, index) {
                  final a = _archetypes[index];
                  final selected = _selected == a;

                  return InkWell(
                    onTap: () => setState(() => _selected = a),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: selected ? _accent : (a == 'elite' ? const Color(0xFF7A2F3B) : Colors.white12),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_archetypeEmoji(a), style: const TextStyle(fontSize: 24)),
                          const Spacer(),
                          Text(_archetypeTitle(a), style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 22 / 2)),
                          const SizedBox(height: 4),
                          Text(_archetypeSubtitle(a), style: const TextStyle(color: _textMuted)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              if (_saving) const LinearProgressIndicator(color: _accent),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(colors: [Color(0xFF1BE5C8), Color(0xFF16D4F4)]),
                  boxShadow: [
                    BoxShadow(color: _accent.withValues(alpha: 0.30), blurRadius: 18, spreadRadius: 1),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size.fromHeight(64),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'CONTINUE',
                        style: TextStyle(
                          color: Color(0xFF08111F),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          fontSize: 24 / 2,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward, color: Color(0xFF08111F)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final active = i == 0;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? _accent : const Color(0xFF4A5A6C),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x22FF4D67),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x55FF4D67)),
                  ),
                  child: Text(_message!, style: const TextStyle(color: _textPrimary)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
