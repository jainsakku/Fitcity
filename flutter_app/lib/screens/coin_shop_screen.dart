import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/phase4_service.dart';
import '../services/supabase_service.dart';

class CoinShopScreen extends StatefulWidget {
  const CoinShopScreen({super.key});

  @override
  State<CoinShopScreen> createState() => _CoinShopScreenState();
}

class _CoinShopScreenState extends State<CoinShopScreen> {
  static const _bgTop = Color(0xFF04181C);
  static const _bgBottom = Color(0xFF040814);
  static const _accent = Color(0xFF1DF7D4);
  static const _textPrimary = Color(0xFFEAF2FF);
  static const _textMuted = Color(0xFF8A9AAC);
  static const _danger = Color(0xFFFF6A76);

  final _service = Phase4Service();
  final _tabs = const ['all', 'building_skin', 'color', 'effect', 'character'];
  String _selected = 'all';

  bool _loading = true;
  bool _buying = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  List<String> _owned = const [];
  int? _balance;
  StreamSubscription<List<Map<String, dynamic>>>? _userSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _service.getShopItems();
      final owned = await _service.getOwnedItems();
      final profile = await _service.getUserProfile();

      if (!mounted) return;
      setState(() {
        _items = items;
        _owned = owned;
        _balance = (profile?['coins'] as num?)?.toInt() ?? 0;
        _loading = false;
      });

      _attachUserRealtime();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _attachUserRealtime() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _userSub?.cancel();
    _userSub = SupabaseService.client
        .from('users')
        .stream(primaryKey: ['uid'])
        .eq('uid', uid)
        .listen((rows) {
          if (!mounted || rows.isEmpty) return;
          final coins = (rows.first['coins'] as num?)?.toInt();
          if (coins == null) return;
          setState(() => _balance = coins);
        });
  }

  Future<void> _purchase(String itemId) async {
    setState(() {
      _buying = true;
      _error = null;
    });

    try {
      final result = await _service.purchaseItem(itemId);
      if (!mounted) return;
      setState(() {
        _balance = (result['balance'] as num?)?.toInt() ?? _balance;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selected == 'all') return _items;
    return _items.where((i) => i['category'] == _selected).toList();
  }

  @override
  Widget build(BuildContext context) {
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
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _accent))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go('/profile');
                              }
                            },
                            icon: const Icon(Icons.arrow_back, color: _textPrimary),
                          ),
                          const Expanded(
                            child: Text(
                              'Coin Shop',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _textPrimary, fontSize: 30, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF13263A), Color(0xFF0F1C2A)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Customize Your Skyline', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
                                  SizedBox(height: 4),
                                  Text('Unlock skins, effects and character upgrades.', style: TextStyle(color: _textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.auto_awesome, color: _accent),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF102330),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('💰 ${_balance ?? 0} Coins', style: const TextStyle(color: _accent, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _tabs.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final key = _tabs[i];
                            final selected = key == _selected;
                            final label = switch (key) {
                              'building_skin' => 'Skins',
                              'effect' => 'Effects',
                              'character' => 'Character',
                              'color' => 'Colors',
                              _ => 'All',
                            };
                            return InkWell(
                              onTap: () => setState(() => _selected = key),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: selected ? _accent : const Color(0xFF0F1C2A),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  label,
                                  style: TextStyle(color: selected ? const Color(0xFF08111F) : _textMuted, fontWeight: FontWeight.w700),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filtered.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.82,
                        ),
                        itemBuilder: (_, i) {
                          final item = _filtered[i];
                          final id = item['id'] as String;
                          final name = item['name'] as String? ?? 'Item';
                          final category = item['category'] as String? ?? 'misc';
                          final price = (item['price'] as num?)?.toInt() ?? 0;
                          final owned = _owned.contains(id);
                          final previewUrl = (item['preview_url'] as String?)?.trim();

                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1C2A),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: owned ? _accent : Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: const LinearGradient(colors: [Color(0xFF213B4E), Color(0xFF152636)]),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: previewUrl != null && previewUrl.isNotEmpty
                                                ? Image.network(
                                                    previewUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                        ),
                                        if (previewUrl == null || previewUrl.isEmpty)
                                          const Center(child: Icon(Icons.domain, color: _accent, size: 36)),
                                        if (owned)
                                          Positioned(
                                            right: 8,
                                            top: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _accent,
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: const Text('OWNED', style: TextStyle(color: Color(0xFF08111F), fontSize: 10, fontWeight: FontWeight.w800)),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
                                Text(category, style: const TextStyle(color: _textMuted, fontSize: 11)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text('💰 $price', style: const TextStyle(color: _accent, fontWeight: FontWeight.w700)),
                                    const Spacer(),
                                    ElevatedButton(
                                      onPressed: owned || _buying ? null : () => _purchase(id),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: owned ? Colors.grey.shade700 : _accent,
                                        foregroundColor: const Color(0xFF08111F),
                                        minimumSize: const Size(64, 30),
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                      ),
                                      child: Text(owned ? 'Owned' : 'Buy'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (_buying) const LinearProgressIndicator(color: _accent),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: _danger)),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
