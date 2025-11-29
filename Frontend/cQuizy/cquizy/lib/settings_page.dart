import 'package:flutter/material.dart';
import 'theme.dart';

const double kSettingsDesktopBreakpoint = 700.0;

class SettingsPage extends StatefulWidget {
  final VoidCallback onLogout;

  const SettingsPage({super.key, required this.onLogout});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _selectedSection = 'Profil';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop =
            constraints.maxWidth > kSettingsDesktopBreakpoint;

        if (isDesktop) {
          // Desktop view with collapsible sidebar
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 220,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 220,
                      child: _buildSidebar(context, isDesktop: true),
                    ),
                  ),
                ),
                Expanded(child: _buildContent(context, isDesktop: true)),
              ],
            ),
          );
        } else {
          // Mobile view with drawer
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            drawer: Drawer(child: _buildSidebar(context, isDesktop: false)),
            body: _buildContent(context, isDesktop: false),
          );
        }
      },
    );
  }

  Widget _buildSidebar(BuildContext context, {required bool isDesktop}) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: isDesktop
            ? const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'Beállítások',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Divider(color: theme.dividerColor, height: 20),
          _buildNavItem(context, 'Profil', Icons.person, isDesktop: isDesktop),
          _buildNavItem(
            context,
            'Megjelenés és Kezelés',
            Icons.palette,
            isDesktop: isDesktop,
          ),
          _buildNavItem(context, 'Nyelv', Icons.language, isDesktop: isDesktop),
          _buildNavItem(
            context,
            'Értesítés',
            Icons.notifications,
            isDesktop: isDesktop,
          ),
          _buildNavItem(
            context,
            'Kisegítő lehetőségek',
            Icons.accessibility,
            isDesktop: isDesktop,
          ),
          _buildNavItem(
            context,
            'Általános',
            Icons.settings,
            isDesktop: isDesktop,
          ),
          const Spacer(),
          // Logo
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo/logo_2.png', height: 16),
              const SizedBox(width: 8),
              Text(
                'cQuizy',
                style: TextStyle(
                  color: theme.textTheme.titleMedium?.color?.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Logout button
          // Logout button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Kijelentkezés'),
                      content: const Text('Biztosan ki szeretne jelentkezni?'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(
                            'Mégse',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Close dialog
                            widget.onLogout();
                            Navigator.of(context).pop(); // Close settings page
                          },
                          child: Text(
                            'Kijelentkezés',
                            style: TextStyle(color: theme.primaryColor),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Kijelentkezés',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String title,
    IconData icon, {
    VoidCallback? onTap,
    required bool isDesktop,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedSection == title && onTap == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Material(
        color: isSelected
            ? theme.primaryColor.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            if (onTap != null) {
              onTap();
            } else {
              setState(() {
                _selectedSection = title;
              });
              if (!isDesktop) {
                Navigator.of(context).pop(); // Close drawer on mobile
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? theme.primaryColor
                      : theme.iconTheme.color?.withOpacity(0.6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? theme.primaryColor
                          : theme.textTheme.bodyLarge?.color,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required bool isDesktop}) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Column(
          children: [
            // Top bar with menu/collapse toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  if (!isDesktop)
                    Builder(
                      builder: (context) => IconButton(
                        icon: Icon(Icons.menu, color: theme.iconTheme.color),
                        onPressed: () {
                          Scaffold.of(context).openDrawer();
                        },
                      ),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _selectedSection,
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildSectionContent(context)),
          ],
        ),
        // Floating Back Button
        Positioned(
          bottom: 24,
          left: 24,
          child: Tooltip(
            message: 'Vissza',
            child: InkWell(
              onTap: () {
                if (!isDesktop) {
                  Navigator.of(context).pop(); // Close drawer
                }
                Navigator.of(context).pop(); // Close settings page
              },
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContent(BuildContext context) {
    switch (_selectedSection) {
      case 'Általános':
        return _buildGeneralSettings(context);
      case 'Profil':
        return _buildProfileSettings(context);
      case 'Megjelenés és Kezelés':
        return _buildAppearanceSettings(context);
      case 'Nyelv':
        return _buildLanguageSettings(context);
      case 'Értesítés':
        return _buildNotificationSettings(context);
      case 'Kisegítő lehetőségek':
        return _buildAccessibilitySettings(context);
      default:
        return Container();
    }
  }

  Widget _buildGeneralSettings(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      children: [
        _buildSettingsCard(
          context,
          title: 'Verzió',
          subtitle: 'Alkalmazás verzió információ',
          trailing: Text(
            '1.0.0',
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingsCard(
          context,
          title: 'Névjegy',
          subtitle: 'Az alkalmazásról',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildProfileSettings(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      children: [
        Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: theme.primaryColor,
                child: const Text(
                  'JD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'John Doe',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Diák',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Profil szerkesztése'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(color: theme.primaryColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSettings(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = ThemeInherited.of(context);
    final isDark = themeProvider.isDarkMode;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'TÉMA',
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'Alapértelmezett téma kiválasztása:',
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Theme selection - always stacked on mobile for better UX
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 500) {
              // Mobile: Stack vertically
              return Column(
                children: [
                  _buildThemeOption(
                    context,
                    title: 'Sötét',
                    isSelected: isDark,
                    onTap: () => themeProvider.toggleTheme(true),
                  ),
                  const SizedBox(height: 12),
                  _buildThemeOption(
                    context,
                    title: 'Világos',
                    isSelected: !isDark,
                    onTap: () => themeProvider.toggleTheme(false),
                  ),
                  const SizedBox(height: 12),
                  _buildThemeOption(
                    context,
                    title: 'Rendszer téma',
                    isSelected: false,
                    onTap: () {},
                  ),
                ],
              );
            } else {
              // Desktop: Row layout
              return Row(
                children: [
                  Expanded(
                    child: _buildThemeOption(
                      context,
                      title: 'Sötét',
                      isSelected: isDark,
                      onTap: () => themeProvider.toggleTheme(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildThemeOption(
                      context,
                      title: 'Világos',
                      isSelected: !isDark,
                      onTap: () => themeProvider.toggleTheme(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildThemeOption(
                      context,
                      title: 'Rendszer téma',
                      isSelected: false,
                      onTap: () {},
                    ),
                  ),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'VISSZAJELZÉSEK',
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingsCard(
          context,
          title: 'Haptikus visszajelzés',
          subtitle: 'Rezgés interakciók során',
          trailing: Switch(
            value: true,
            activeColor: theme.primaryColor,
            onChanged: (val) {},
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
        ),
        const SizedBox(height: 12),
        _buildSettingsCard(
          context,
          title: 'Hangjelzések',
          subtitle: 'Hangeffektek',
          trailing: Switch(
            value: false,
            activeColor: theme.primaryColor,
            onChanged: (val) {},
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
        ),
      ],
    );
  }

  Widget _buildLanguageSettings(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      children: [
        _buildSettingsCard(
          context,
          title: 'Magyar',
          subtitle: 'Jelenlegi nyelv',
          trailing: const Icon(Icons.check, color: Colors.green),
        ),
        const SizedBox(height: 12),
        _buildSettingsCard(
          context,
          title: 'English',
          subtitle: 'Hamarosan',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildNotificationSettings(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      children: [
        _buildSettingsCard(
          context,
          title: 'Tesztek értesítései',
          subtitle: 'Új tesztek és határidők',
          trailing: Switch(
            value: true,
            activeColor: theme.primaryColor,
            onChanged: (val) {},
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
        ),
        const SizedBox(height: 12),
        _buildSettingsCard(
          context,
          title: 'Csoportos értesítések',
          subtitle: 'Csoporttagság és tevékenységek',
          trailing: Switch(
            value: true,
            activeColor: theme.primaryColor,
            onChanged: (val) {},
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
        ),
      ],
    );
  }

  Widget _buildAccessibilitySettings(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      children: [
        _buildSettingsCard(
          context,
          title: 'Betűméret',
          subtitle: 'Szöveg méretének beállítása',
          onTap: () {},
        ),
        const SizedBox(height: 12),
        _buildSettingsCard(
          context,
          title: 'Magas kontraszt',
          subtitle: 'Jobb láthatóság',
          trailing: Switch(
            value: false,
            activeColor: theme.primaryColor,
            onChanged: (val) {},
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
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.dividerColor,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (isSelected)
              Icon(Icons.check_circle, color: theme.primaryColor, size: 28)
            else
              Icon(
                Icons.circle_outlined,
                color: theme.iconTheme.color?.withOpacity(0.3),
                size: 28,
              ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? theme.primaryColor
                    : theme.textTheme.bodyLarge?.color,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title,
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 15,
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
            (onTap != null
                ? Icon(
                    Icons.arrow_forward_ios,
                    color: theme.iconTheme.color?.withOpacity(0.3),
                    size: 16,
                  )
                : null),
      ),
    );
  }
}
