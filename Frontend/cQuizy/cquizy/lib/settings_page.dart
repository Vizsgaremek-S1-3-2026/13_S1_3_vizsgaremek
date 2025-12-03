import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'theme.dart';
import 'dart:math' as math;

const double kSettingsDesktopBreakpoint = 700.0;

class SettingsPage extends StatefulWidget {
  final VoidCallback onLogout;

  const SettingsPage({super.key, required this.onLogout});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  String _selectedSection = 'Profil';
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

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
                  color: theme.textTheme.titleMedium?.color?.withValues(
                    alpha: 0.7,
                  ),
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
            ? theme.primaryColor.withValues(alpha: 0.1)
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
                      : theme.iconTheme.color?.withValues(alpha: 0.6),
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
                      color: Colors.black.withValues(alpha: 0.2),
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
      case 'Értesítések':
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
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
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
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: 360,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: WavePainter(
                    animation: _waveController,
                    color: theme.primaryColor,
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: theme.primaryColor,
                        backgroundImage: user.pfpUrl != null
                            ? NetworkImage(user.pfpUrl!)
                            : null,
                        child: user.pfpUrl == null
                            ? Text(
                                user.firstName.isNotEmpty
                                    ? user.firstName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${user.lastName} ${user.firstName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '@${user.username}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (user.nickname != null && user.nickname!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        user.nickname!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              _buildProfileInfoRow(
                context,
                Icons.email_outlined,
                'E-mail',
                user.email,
              ),
              const Divider(height: 32),
              _buildProfileInfoRow(
                context,
                Icons.calendar_today_outlined,
                'Csatlakozott',
                user.dateJoined.toString().split(' ')[0],
              ),
              const Divider(height: 32),
              _buildProfileInfoRow(
                context,
                Icons.verified_user_outlined,
                'Státusz',
                user.isActive ? 'Aktív' : 'Inaktív',
              ),
              if (user.isSuperuser) ...[
                const Divider(height: 32),
                _buildProfileInfoRow(
                  context,
                  Icons.admin_panel_settings_outlined,
                  'Jogosultság',
                  'Adminisztrátor',
                ),
              ] else if (user.isStaff) ...[
                const Divider(height: 32),
                _buildProfileInfoRow(
                  context,
                  Icons.security_outlined,
                  'Jogosultság',
                  'Moderátor',
                ),
              ],
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditProfileDialog(context, user),
                      icon: const Icon(Icons.edit, size: 20),
                      label: const Text('Profil szerkesztése'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.primaryColor,
                        side: BorderSide(color: theme.primaryColor, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showChangePasswordDialog(context),
                      icon: const Icon(Icons.lock_outline, size: 20),
                      label: const Text('Jelszó módosítása'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.primaryColor,
                        side: BorderSide(color: theme.primaryColor, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showDeleteAccountDialog(context),
                  icon: const Icon(Icons.delete_forever, size: 20),
                  label: const Text('Fiók törlése'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 120),
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
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
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
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
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

  Widget _buildProfileInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.primaryColor, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.6,
                ),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showEditProfileDialog(BuildContext context, dynamic user) {
    final firstNameController = TextEditingController(text: user.firstName);
    final lastNameController = TextEditingController(text: user.lastName);
    final nicknameController = TextEditingController(text: user.nickname);
    final emailController = TextEditingController(text: user.email);
    final pfpUrlController = TextEditingController(text: user.pfpUrl ?? '');
    final passwordController = TextEditingController();
    final theme = Theme.of(context);
    final originalEmail = user.email;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
      transitionBuilder: (context, a1, a2, widget) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
          child: FadeTransition(
            opacity: a1,
            child: StatefulBuilder(
              builder: (context, setState) {
                final isEmailChanged = emailController.text != originalEmail;

                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    width: 500,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with gradient
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.primaryColor,
                                theme.primaryColor.withValues(alpha: 0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Profil szerkesztése',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Content
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDialogTextField(
                                      lastNameController,
                                      'Vezetéknév',
                                      Icons.person_outline,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildDialogTextField(
                                      firstNameController,
                                      'Keresztnév',
                                      Icons.person_outline,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _buildDialogTextField(
                                nicknameController,
                                'Becenév',
                                Icons.badge_outlined,
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: emailController,
                                decoration: InputDecoration(
                                  labelText: 'E-mail',
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    color: theme.primaryColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {});
                                },
                              ),
                              if (isEmailChanged) ...[
                                const SizedBox(height: 24),
                                TextField(
                                  controller: passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: 'Jelszó (megerősítéshez)',
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      color: theme.primaryColor,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: theme.primaryColor,
                                        width: 2,
                                      ),
                                    ),
                                    helperText:
                                        'Az email módosításához szükséges',
                                  ),
                                  onChanged: (value) {
                                    setState(() {});
                                  },
                                ),
                              ],
                              const SizedBox(height: 24),
                              _buildDialogTextField(
                                pfpUrlController,
                                'Profilkép URL',
                                Icons.image_outlined,
                              ),
                              const SizedBox(height: 32),

                              // Actions
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      ),
                                    ),
                                    child: Text(
                                      'Mégse',
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.6),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton(
                                    // Disable button if email changed but password is empty
                                    onPressed:
                                        (isEmailChanged &&
                                            passwordController.text.isEmpty)
                                        ? null
                                        : () async {
                                            bool success = true;

                                            // If email changed, call changeEmail endpoint
                                            if (isEmailChanged) {
                                              success = await context
                                                  .read<UserProvider>()
                                                  .changeEmail(
                                                    emailController.text,
                                                    passwordController.text,
                                                  );
                                            }

                                            // Update other fields
                                            if (success) {
                                              final updateData = {
                                                'first_name':
                                                    firstNameController.text,
                                                'last_name':
                                                    lastNameController.text,
                                                'nickname':
                                                    nicknameController.text,
                                                'pfp_url':
                                                    pfpUrlController
                                                        .text
                                                        .isEmpty
                                                    ? null
                                                    : pfpUrlController.text,
                                              };

                                              success = await context
                                                  .read<UserProvider>()
                                                  .updateUser(updateData);
                                            }

                                            if (context.mounted) {
                                              // Only close dialog if successful
                                              if (success) {
                                                Navigator.pop(context);
                                              }

                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    success
                                                        ? 'Profil sikeresen frissítve'
                                                        : 'Hiba történt a frissítés során',
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  backgroundColor: success
                                                      ? Colors.green
                                                      : Colors.red,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.primaryColor,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: theme
                                          .primaryColor
                                          .withValues(alpha: 0.3),
                                      disabledForegroundColor: Colors.white
                                          .withValues(alpha: 0.5),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 4,
                                      shadowColor: theme.primaryColor
                                          .withValues(alpha: 0.4),
                                    ),
                                    child: const Text(
                                      'Mentés',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final theme = Theme.of(context);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
      transitionBuilder: (context, a1, a2, widget) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
          child: FadeTransition(
            opacity: a1,
            child: StatefulBuilder(
              builder: (context, setState) {
                // Password validation checks
                final hasMinLength = newPasswordController.text.length >= 8;
                final hasUppercase = RegExp(
                  r'[A-Z]',
                ).hasMatch(newPasswordController.text);
                final hasLowercase = RegExp(
                  r'[a-z]',
                ).hasMatch(newPasswordController.text);
                final hasDigit = RegExp(
                  r'[0-9]',
                ).hasMatch(newPasswordController.text);

                final isPasswordValid =
                    hasMinLength && hasUppercase && hasLowercase && hasDigit;
                final passwordsMatch =
                    newPasswordController.text.isNotEmpty &&
                    newPasswordController.text ==
                        confirmPasswordController.text;
                final currentPasswordFilled =
                    currentPasswordController.text.isNotEmpty;

                final isSaveEnabled =
                    currentPasswordFilled && isPasswordValid && passwordsMatch;

                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    width: 500,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with gradient
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.primaryColor,
                                theme.primaryColor.withValues(alpha: 0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock_reset,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Jelszó módosítása',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Content
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              _buildDialogTextField(
                                currentPasswordController,
                                'Jelenlegi jelszó',
                                Icons.lock_outline,
                                isPassword: true,
                                onChanged: (value) => setState(() {}),
                              ),
                              const SizedBox(height: 24),
                              _buildDialogTextField(
                                newPasswordController,
                                'Új jelszó',
                                Icons.lock_reset,
                                isPassword: true,
                                onChanged: (value) => setState(() {}),
                              ),
                              const SizedBox(height: 12),
                              // Password requirements
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildPasswordRequirement(
                                    hasMinLength,
                                    'Legalább 8 karakter',
                                  ),
                                  _buildPasswordRequirement(
                                    hasUppercase,
                                    'Nagybetű',
                                  ),
                                  _buildPasswordRequirement(
                                    hasLowercase,
                                    'Kisbetű',
                                  ),
                                  _buildPasswordRequirement(hasDigit, 'Szám'),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildDialogTextField(
                                confirmPasswordController,
                                'Új jelszó megerősítése',
                                Icons.check_circle_outline,
                                isPassword: true,
                                onChanged: (value) => setState(() {}),
                              ),
                              if (confirmPasswordController.text.isNotEmpty &&
                                  !passwordsMatch)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    'A jelszavak nem egyeznek',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 32),

                              // Actions
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      ),
                                    ),
                                    child: Text(
                                      'Mégse',
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withValues(alpha: 0.6),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  ElevatedButton(
                                    // Disable button if conditions not met
                                    onPressed: !isSaveEnabled
                                        ? null
                                        : () async {
                                            final success = await context
                                                .read<UserProvider>()
                                                .changePassword(
                                                  currentPasswordController
                                                      .text,
                                                  newPasswordController.text,
                                                );

                                            if (context.mounted) {
                                              // Only close on success
                                              if (success) {
                                                Navigator.pop(context);
                                              }

                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    success
                                                        ? 'Jelszó sikeresen módosítva'
                                                        : 'Hiba történt a módosítás során',
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  backgroundColor: success
                                                      ? Colors.green
                                                      : Colors.red,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.primaryColor,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: theme
                                          .primaryColor
                                          .withValues(alpha: 0.3),
                                      disabledForegroundColor: Colors.white
                                          .withValues(alpha: 0.5),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 4,
                                      shadowColor: theme.primaryColor
                                          .withValues(alpha: 0.4),
                                    ),
                                    child: const Text(
                                      'Módosítás',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
      transitionBuilder: (context, a1, a2, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(a1),
          child: FadeTransition(
            opacity: a1,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                width: 500,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with gradient (Red for danger)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red,
                              Colors.red.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Fiók törlése',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Text(
                              'Biztosan törölni szeretnéd a fiókodat? Ez a művelet nem visszavonható, és minden adatod elveszik.',
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildDialogTextField(
                              passwordController,
                              'Jelszó megerősítése',
                              Icons.lock_outline,
                              isPassword: true,
                              validator: (value) => value?.isEmpty ?? true
                                  ? 'Kötelező mező'
                                  : null,
                            ),
                            const SizedBox(height: 32),

                            // Actions
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                  ),
                                  child: Text(
                                    'Mégse',
                                    style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withValues(alpha: 0.6),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: () async {
                                    if (formKey.currentState?.validate() ??
                                        false) {
                                      final success = await context
                                          .read<UserProvider>()
                                          .deleteAccount(
                                            passwordController.text,
                                          );

                                      if (context.mounted) {
                                        if (success) {
                                          Navigator.pop(
                                            context,
                                          ); // Close dialog
                                          widget.onLogout(); // Trigger logout
                                          Navigator.pop(
                                            context,
                                          ); // Close settings page
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'Hiba történt a törlés során. Ellenőrizd a jelszót.',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              backgroundColor: Colors.red,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                    shadowColor: Colors.red.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  child: const Text(
                                    'Végleges törlés',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper widget for password requirements
  Widget _buildPasswordRequirement(bool met, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            color: met ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: met ? Colors.green : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isPassword = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
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
                color: theme.iconTheme.color?.withValues(alpha: 0.3),
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
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.5,
                  ),
                  fontSize: 13,
                ),
              )
            : null,
        trailing:
            trailing ??
            (onTap != null
                ? Icon(
                    Icons.arrow_forward_ios,
                    color: theme.iconTheme.color?.withValues(alpha: 0.3),
                    size: 16,
                  )
                : null),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  WavePainter({required this.animation, required this.color})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.8), color],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final y = size.height - 20;

    path.moveTo(0, 0);
    path.lineTo(0, y);

    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        y +
            10 *
                math.sin(
                  (i / size.width * 2 * math.pi) +
                      (animation.value * 2 * math.pi),
                ),
      );
    }

    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) => true;
}
