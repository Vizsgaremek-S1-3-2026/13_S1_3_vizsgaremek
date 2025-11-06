// lib/group_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // A vágólaphoz szükséges
import 'home_page.dart';

class GroupPage extends StatefulWidget {
  final Group group;
  final VoidCallback onBack;
  final Function(Group) onTestExpired;

  const GroupPage({
    super.key,
    required this.group,
    required this.onBack,
    required this.onTestExpired,
  });

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  bool _isMembersPanelVisible = false;
  late List<Map<String, String>> _pastTests;

  @override
  void initState() {
    super.initState();
    _pastTests = [
      {'title': 'Algebra Témazáró I.', 'detail': '5'},
      {'title': 'Számelmélet Dolgozat', 'detail': '4'},
      {'title': 'Félévi Felmérő', 'detail': '-'},
    ];
  }

  @override
  void didUpdateWidget(GroupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.hasNotification &&
        !widget.group.hasNotification &&
        oldWidget.group.activeTestTitle != null) {
      setState(() {
        _pastTests.insert(0, {
          'title': oldWidget.group.activeTestTitle!,
          'detail': '-',
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Stack(
              children: [
                _buildTestContent(),
                if (_isMembersPanelVisible)
                  GestureDetector(
                    onTap: () => setState(() => _isMembersPanelVisible = false),
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                _buildMembersPanel(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: !_isMembersPanelVisible
          ? FloatingActionButton(
              onPressed: () {
                // Ide jöhet a tag hozzáadása logika
              },
              backgroundColor: const Color(0xFFff3b5f),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            )
          : null,
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
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
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
                        shadows: [
                          Shadow(
                              blurRadius: 2,
                              color: Colors.black38,
                              offset: Offset(1, 1))
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Oktató: ${widget.group.subtitle}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9), fontSize: 18),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _isMembersPanelVisible = !_isMembersPanelVisible),
                icon: const Icon(Icons.people_outline, color: Colors.white),
                label: const Text('Tagok', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.7)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestContent() {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        if (widget.group.hasNotification && widget.group.testExpiryDate != null) ...[
          _buildActiveTestCard(),
          const SizedBox(height: 24),
        ],
        const HeaderWithDivider(title: 'Jövőbeli tesztek'),
        const SizedBox(height: 16),
        _buildTestCard(
            title: 'Algebra Témazáró II.',
            detail: '2025. nov. 28.',
            isGrade: false),
        _buildTestCard(
            title: 'Geometria Röpdolgozat',
            detail: '2025. dec. 05.',
            isGrade: false),
        const SizedBox(height: 24),
        const HeaderWithDivider(title: 'Múltbeli tesztek'),
        const SizedBox(height: 16),
        ..._pastTests.map((test) {
          final isNumeric = int.tryParse(test['detail']!) != null;
          return _buildTestCard(
            title: test['title']!,
            detail: test['detail']!,
            isGrade: isNumeric,
          );
        }).toList(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildTestCard(
      {required String title, required String detail, required bool isGrade}) {
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
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
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
                    Icon(Icons.hourglass_bottom,
                        color: Colors.yellow, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Jelenleg aktív teszt',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
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
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.group.activeTestDescription ??
                                'Nincs leírása a tesztnek.',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Készítő: ${widget.group.subtitle}',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (widget.group.testExpiryDate != null)
                      CountdownTimerWidget(
                        expiryDate: widget.group.testExpiryDate!,
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
                Text('Teszt indítása',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Icon(Icons.play_arrow, size: 20),
              ],
            ),
          )
        ],
      ),
    );
  }

  // *** MÓDOSÍTOTT TAGOK PANEL ***
  Widget _buildMembersPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: -10,
      bottom: 0,
      right: _isMembersPanelVisible ? 0 : -300,
      width: 300,
      child: Container(
        decoration: BoxDecoration(
            color: const Color(0xFF1a1a1a),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                offset: const Offset(-5, 0),
              )
            ]),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.group, color: Colors.white, size: 24),
                  const Text('Csoport Tagjai (24)',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () =>
                        setState(() => _isMembersPanelVisible = false),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            _buildInviteCodeCard(),
            Expanded(
              // *** MÓDOSÍTÁS KEZDETE: ListView-ra cserélve a szekciók miatt ***
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                children: [
                  // --- ADMIN SZEKCIÓ ---
                  _buildSectionHeader('ADMIN'),
                  const Divider(color: Colors.white12, height: 1),

                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: const Color(0xFFed2f5b),
                      child: Icon(Icons.star, color: Colors.white),
                    ),
                    title: const Text(
                      'Admin Neve 1',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Admin',
                      style: TextStyle(color: const Color(0xFFED2F5B)),
                    ),
                    trailing: Icon(
                      Icons.workspace_premium, // Korona ikon
                      color: const Color(0xFFed2f5b),
                    ),
                  ),
                  // --- TAGOK SZEKCIÓ ---
                  _buildSectionHeader('TAGOK (23)'),
                  const Divider(color: Colors.white12, height: 1),

                  // A többi 23 tag generálása
                  ...List.generate(23, (index) {
                    final memberIndex = index + 1; // Tag Neve 2-től indul
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        'Tag Neve $memberIndex',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Felhasználónév$memberIndex',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: Colors.red.shade300),
                        tooltip: 'Tag eltávolítása',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('Tag $memberIndex eltávolítása...'),
                              backgroundColor: Colors.red.shade400,
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
              // *** MÓDOSÍTÁS VÉGE ***
            ),
          ],
        ),
      ),
    );
  }

  // Segédfüggvény a szekciófejlécekhez
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInviteCodeCard() {
    const inviteCode = 'X7B2-K9P5';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MEGHÍVÓKÓD',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: 4),
              Text(
                inviteCode,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Új kód generálása',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Új meghívókód generálása...'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined, color: Colors.white70),
                tooltip: 'Kód másolása',
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Meghívókód a vágólapra másolva!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}