import 'package:flutter/material.dart';
import 'theme.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onLogout;

  const SettingsPage({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeInherited.of(context);
    final isDark = themeProvider.isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Beállítások',
          style: TextStyle(color: theme.appBarTheme.foregroundColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader(context, 'Profil'),
          const SizedBox(height: 10),
          _buildProfileCard(context),
          const SizedBox(height: 30),
          _buildSectionHeader(context, 'Általános'),
          const SizedBox(height: 10),
          _buildSettingsItem(
            context,
            icon: Icons.notifications_outlined,
            title: 'Értesítések',
            subtitle: 'Kezeld az értesítéseidet',
            onTap: () {},
          ),
          _buildSettingsItem(
            context,
            icon: Icons.language,
            title: 'Nyelv',
            subtitle: 'Magyar',
            onTap: () {},
          ),
          const SizedBox(height: 30),
          _buildSectionHeader(context, 'Megjelenés'),
          const SizedBox(height: 10),
          _buildSettingsItem(
            context,
            icon: Icons.dark_mode_outlined,
            title: 'Sötét mód',
            subtitle: isDark ? 'Bekapcsolva' : 'Kikapcsolva',
            trailing: Switch(
              value: isDark,
              activeColor: theme.primaryColor,
              activeTrackColor: theme.primaryColor,
              onChanged: (val) {
                themeProvider.toggleTheme(val);
              },
              thumbColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return theme.colorScheme.outline;
              }),
              trackColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.selected)) {
                  return theme.primaryColor;
                }
                return theme.colorScheme.surfaceContainerHighest;
              }),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
            onTap: () {
              themeProvider.toggleTheme(!isDark);
            },
          ),
          const SizedBox(height: 30),
          _buildSectionHeader(context, 'Egyéb'),
          const SizedBox(height: 10),
          _buildSettingsItem(
            context,
            icon: Icons.info_outline,
            title: 'Névjegy',
            subtitle: 'Verzió 1.0.0',
            onTap: () {},
          ),
          _buildSettingsItem(
            context,
            icon: Icons.logout,
            title: 'Kijelentkezés',
            titleColor: theme.primaryColor,
            onTap: () {
              onLogout();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.primaryColor,
            child: const Text(
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
                Text(
                  'John Doe',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Diák',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: theme.iconTheme.color),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
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
            color: theme.iconTheme.color?.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(
            icon,
            color: titleColor ?? theme.iconTheme.color,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? theme.textTheme.bodyLarge?.color,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                  fontSize: 13,
                ),
              )
            : null,
        trailing:
            trailing ??
            Icon(
              Icons.arrow_forward_ios,
              color: theme.iconTheme.color?.withOpacity(0.3),
              size: 16,
            ),
      ),
    );
  }
}
