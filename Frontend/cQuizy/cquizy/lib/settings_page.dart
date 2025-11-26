import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1c1c1c),
        elevation: 0,
        title: const Text('Beállítások', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Profil'),
          const SizedBox(height: 10),
          _buildProfileCard(),
          const SizedBox(height: 30),
          _buildSectionHeader('Általános'),
          const SizedBox(height: 10),
          _buildSettingsItem(
            icon: Icons.notifications_outlined,
            title: 'Értesítések',
            subtitle: 'Kezeld az értesítéseidet',
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.language,
            title: 'Nyelv',
            subtitle: 'Magyar',
            onTap: () {},
          ),
          const SizedBox(height: 30),
          _buildSectionHeader('Megjelenés'),
          const SizedBox(height: 10),
          _buildSettingsItem(
            icon: Icons.dark_mode_outlined,
            title: 'Sötét mód',
            subtitle: 'Bekapcsolva',
            trailing: Switch(
              value: true,
              onChanged: (val) {},
              activeColor: const Color(0xFFff3b5f),
            ),
            onTap: () {},
          ),
          const SizedBox(height: 30),
          _buildSectionHeader('Egyéb'),
          const SizedBox(height: 10),
          _buildSettingsItem(
            icon: Icons.info_outline,
            title: 'Névjegy',
            subtitle: 'Verzió 1.0.0',
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.logout,
            title: 'Kijelentkezés',
            titleColor: const Color(0xFFff3b5f),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFff3b5f),
            child: Text(
              'JD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'John Doe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Diák',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(icon, color: titleColor ?? Colors.white, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                ),
              )
            : null,
        trailing:
            trailing ??
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.3),
              size: 16,
            ),
      ),
    );
  }
}
