
// lib/group_page.dart

import 'package:flutter/material.dart';
import 'home_page.dart'; // Szükségünk van a Group és CountdownTimerWidget modellekre

class GroupPage extends StatefulWidget {
  final Group group;
  final VoidCallback onBack;
  // *** MÓDOSÍTÁS: Callback a teszt lejáratának jelzésére ***
  final Function(Group) onTestExpired;

  const GroupPage({
    super.key,
    required this.group,
    required this.onBack,
    // *** MÓDOSÍTÁS: A callback kötelezővé tétele ***
    required this.onTestExpired,
  });

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  bool _isMembersPanelVisible = false;
  // *** MÓDOSÍTÁS: Lista a múltbeli tesztek dinamikus tárolására ***
  late List<Map<String, String>> _pastTests;

  @override
  void initState() {
    super.initState();
    // A múltbeli tesztek listájának inicializálása a kezdeti, keménykódolt adatokkal
    _pastTests = [
      {'title': 'Algebra Témazáró I.', 'detail': '5'},
      {'title': 'Számelmélet Dolgozat', 'detail': '4'},
      {'title': 'Félévi Felmérő', 'detail': '-'},
    ];
  }

  // *** MÓDOSÍTÁS: Figyeljük, amikor a widgetet frissítik (pl. a csoport állapota megváltozik) ***
  @override
  void didUpdateWidget(GroupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ellenőrizzük, hogy az aktív teszt "épp most" járt-e le.
    // Ezt onnan tudjuk, hogy korábban volt értesítés (aktív teszt), de most már nincs.
    if (oldWidget.group.hasNotification &&
        !widget.group.hasNotification &&
        oldWidget.group.activeTestTitle != null) {
      // Hozzáadjuk a lejárt tesztet a múltbeli tesztek listájához.
      setState(() {
        _pastTests.insert(0, {
          'title': oldWidget.group.activeTestTitle!,
          'detail': '-', // Alapértelmezett érték a még nem értékelt tesztekhez
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Stack(
            children: [
              _buildTestContent(),
              _buildMembersPanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 40, left: 24, right: 24, bottom: 24),
      decoration: BoxDecoration(
        gradient: widget.group.gradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: widget.onBack,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Vissza a csoportokhoz',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.group.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 2, color: Colors.black38, offset: Offset(1, 1))],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Oktató: ${widget.group.subtitle}',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _isMembersPanelVisible = !_isMembersPanelVisible),
                icon: const Icon(Icons.people_outline, color: Colors.white),
                label: const Text('Tagok', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // *** MÓDOSÍTOTT TARTALOM ***
  Widget _buildTestContent() {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // A kártya automatikusan eltűnik, amint a `hasNotification` false lesz.
        if (widget.group.hasNotification && widget.group.testExpiryDate != null) ...[
          _buildActiveTestCard(),
          const SizedBox(height: 24),
        ],
        
        const HeaderWithDivider(title: 'Jövőbeli tesztek'),
        const SizedBox(height: 16),
        _buildTestCard(
            title: 'Algebra Témazáró II.', detail: '2025. nov. 28.', isGrade: false),
        _buildTestCard(
            title: 'Geometria Röpdolgozat', detail: '2025. dec. 05.', isGrade: false),
        const SizedBox(height: 24),

        const HeaderWithDivider(title: 'Múltbeli tesztek'),
        const SizedBox(height: 16),
        // A múltbeli tesztek dinamikus generálása a `_pastTests` lista alapján
        ..._pastTests.map((test) {
          final isNumeric = int.tryParse(test['detail']!) != null;
          return _buildTestCard(
            title: test['title']!,
            detail: test['detail']!,
            isGrade: isNumeric,
          );
        }).toList(),
        
        // Extra hely a lebegő gomb számára
        const SizedBox(height: 80),
      ],
    );
  }
  
  Widget _buildTestCard({required String title, required String detail, required bool isGrade}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Text(
            detail,
            style: TextStyle(
              color: isGrade ? Colors.white : Colors.white.withOpacity(0.6),
              fontSize: isGrade ? 22 : 14,
              fontWeight: isGrade ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // *** MÓDOSÍTOTT AKTÍV TESZT KÁRTYA ***
  Widget _buildActiveTestCard() {
    final isExpired = widget.group.testExpiryDate!.isBefore(DateTime.now());

    return Card(
      color: const Color(0xFF3a3a3a),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hourglass_bottom, color: Colors.yellow, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Jelenleg aktív teszt',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.group.activeTestTitle ?? 'Nincs cím',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.group.activeTestDescription ?? 'Nincs leírása a tesztnek.',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Készítő: ${widget.group.subtitle}',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (widget.group.testExpiryDate != null)
                      CountdownTimerWidget(
                        expiryDate: widget.group.testExpiryDate!,
                        // A callback meghívása, ami értesíti a HomePage-et
                        onExpired: () => widget.onTestExpired(widget.group),
                      ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: isExpired ? null : () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: isExpired 
                  ? const Color(0xFF4a2e34) 
                  : const Color(0xFFff3b5f).withOpacity(0.2),
              foregroundColor: isExpired
                  ? Colors.white.withOpacity(0.5)
                  : const Color(0xFFff3b5f),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              disabledBackgroundColor: const Color(0xFF4a2e34),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Teszt indítása', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Icon(Icons.play_arrow, size: 20),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMembersPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: 0,
      bottom: 0,
      right: _isMembersPanelVisible ? 0 : -300,
      width: 300,
      child: Container(
        color: const Color(0xFF1a1a1a),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Csoport Tagjai (24)',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => setState(() => _isMembersPanelVisible = false),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: 24,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text('Tag Neve ${index + 1}', style: const TextStyle(color: Colors.white)),
                    subtitle: Text('Felhasználónév${index + 1}',
                        style: TextStyle(color: Colors.white.withOpacity(0.6))),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}