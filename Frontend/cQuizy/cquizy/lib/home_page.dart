// lib/home_page.dart

import 'package:flutter/material.dart';

// Adatmodell a csoportok dinamikus kezeléséhez.
class Group {
  final String title;
  final String subtitle;
  final Gradient gradient;
  final bool hasNotification;

  Group({
    required this.title,
    required this.subtitle,
    required this.gradient,
    this.hasNotification = false,
  });
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Dinamikusan állítható csoportlisták a kép alapján
    final List<Group> myGroups = [
      Group(
        title: 'Matematika 8.A',
        subtitle: 'Toszt Elek',
        gradient: const LinearGradient(
          colors: [Color(0xff6a1b2d), Color(0xffb72c31)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    ];

    final List<Group> otherGroups = [
      Group(
        title: 'Földrajz 7.C',
        subtitle: 'Csillagos Klára',
        gradient: const LinearGradient(
          colors: [Color(0xff9e6a18), Color(0xffd49c2e)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        hasNotification: true,
      ),
      Group(
        title: 'Hálózati Alapismeretek 9.D',
        subtitle: 'Pók Kevin',
        gradient: const LinearGradient(
          colors: [Color(0xff222a79), Color(0xff3f4aaf)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c),
      body: Row(
        children: [
          // Bal oldali navigációs sáv
          _buildSideNav(),

          // Fő tartalom
          Expanded(
            // A Column helyett ListView-t használunk, hogy a tartalom
            // görgethető legyen, ha nem fér ki.
            child: ListView(
              // A korábbi horizontális paddingot kivettük innen,
              // így a gyerekelemek (a kártyák) kitölthetik a teljes szélességet.
              // Csak a vertikális padding marad.
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              children: [
                // A fejléceknek külön adunk horizontális paddingot.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: const HeaderWithDivider(title: 'Saját Csoportok'),
                ),
                const SizedBox(height: 20),
                // A GroupCard-ok most már teljes szélességűek.
                ...myGroups.map((group) => GroupCard(group: group)).toList(),
                const SizedBox(height: 30),

                // A fejléceknek külön adunk horizontális paddingot.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: const HeaderWithDivider(title: 'További Csoportok'),
                ),
                const SizedBox(height: 20),
                // A GroupCard-ok most már teljes szélességűek.
                ...otherGroups.map((group) => GroupCard(group: group)).toList(),
              ],
            ),
          ),
        ],
      ),
      // Lebegő akciógomb
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Új csoport hozzáadása
        },
        backgroundColor: const Color(0xFFff3b5f),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  // A bal oldali navigációs sávot felépítő widget
  Widget _buildSideNav() {
    return Container(
      width: 280, // Pontosabb szélesség
      color: const Color(0xFF252525),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          SideNavItem(label: 'Csoportok', isSelected: true),
          const SizedBox(height: 8),
          SideNavItem(label: 'Tesztek'),
          const SizedBox(height: 8),
          SideNavItem(label: 'Statisztika'),
          const Spacer(), // A fennmaradó helyet kitölti
          const Padding(
            padding: EdgeInsets.only(left: 12.0, bottom: 8.0),
            child: Row(
              children: [
                Icon(Icons.local_fire_department, color: Color(0xffe53935), size: 22),
                SizedBox(width: 6),
                Text(
                  'cQuizy',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ],
            ),
          ),
          const TestCard(),
          const SizedBox(height: 24),
          SideNavItem(label: 'Profil & Beállítások'),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// Fejléc widget a vékony elválasztó vonallal
class HeaderWithDivider extends StatelessWidget {
  final String title;
  const HeaderWithDivider({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          color: Colors.white.withOpacity(0.1),
        ),
      ],
    );
  }
}

// Csoport kártya widget
class GroupCard extends StatelessWidget {
  final Group group;
  const GroupCard({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        Container(
          height: 100, // Meghatározott magasság
           // A horizontális margót eltávolítottuk, csak az alsó marad.
          margin: const EdgeInsets.only(bottom: 16.0),
          decoration: BoxDecoration(
            gradient: group.gradient,
            // A borderRadius-t nullára állítjuk, hogy a kártya szögletes legyen
            // és kitöltse a teljes szélességet a széleken.
            borderRadius: BorderRadius.circular(0),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // TODO: Csoportra kattintás logikája
              },
              borderRadius: BorderRadius.circular(0),
              child: Padding(
                // A belső paddingot növelhetjük, hogy a szöveg ne legyen a szélén.
                padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (group.hasNotification)
          Positioned(
            right: 10, // Kicsit beljebb hozva
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xfffdd835),
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.all(Radius.circular(5)),
              ),
            ),
          ),
      ],
    );
  }
}


// Oldalsó navigációs elem widgetje
class SideNavItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  const SideNavItem({super.key, required this.label, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          // TODO: Navigációs elemre kattintás logikája
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF4f4f4f),
                radius: 18,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A bal alsó teszt kártya widgetje
class TestCard extends StatelessWidget {
  const TestCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF4e3a15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Földrajz 7.C',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            'Afrika Országai Témazáró',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // TODO: Teszt indítása logika
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF333333).withOpacity(0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Teszt Indítása', style: TextStyle(color: Colors.white)),
                SizedBox(width: 8),
                Icon(Icons.play_arrow, size: 20, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }
}