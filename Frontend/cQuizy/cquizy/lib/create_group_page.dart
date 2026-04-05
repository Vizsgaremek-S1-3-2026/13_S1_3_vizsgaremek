import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'group_page.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'api_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'widgets/group_card.dart';

class CreateGroupPage extends StatefulWidget {
  final bool tutorialMode;

  const CreateGroupPage({super.key, this.tutorialMode = false});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();

  Color _selectedColor = const Color(0xFFE57373); // Default red
  int _protectionLevel = 1; // 0=Nyitott, 1=Védett, 2=Zárolt
  bool _isCreating = false;

  // HSL color picker state
  double _hue = 0.0; // 0-360
  double _saturation = 0.7; // 0-1
  double _lightness = 0.6; // 0-1
  bool _showCustomColorPicker = false;

  // Tutorial GlobalKeys
  final GlobalKey _groupNameKey = GlobalKey();
  final GlobalKey _colorPickerKey = GlobalKey();
  final GlobalKey _protectionSliderKey = GlobalKey();
  final GlobalKey _previewKey = GlobalKey();
  final GlobalKey _createButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Start tutorial after widget is built
    if (widget.tutorialMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startTutorial();
      });
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<UserProvider>().user;
    final teacherName = user != null
        ? '${user.lastName} ${user.firstName}'
        : 'Tanár neve';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Header
                    _buildHeader(theme),

                    // Content
                    Expanded(
                      child: isDesktop
                          ? _buildDesktopLayout(theme, teacherName)
                          : _buildMobileLayout(theme, teacherName),
                    ),
                  ],
                ),
                // Floating Back Button (bottom-left)
                Positioned(
                  bottom: 24,
                  left: 24,
                  child: Tooltip(
                    message: 'Vissza',
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'Új Csoport Létrehozása',
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme, String teacherName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Form Section
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: _buildForm(theme, teacherName),
          ),
        ),

        // Preview Section
        Expanded(
          flex: 2,
          child: Container(
            color: theme.scaffoldBackgroundColor,
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Előnézet',
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color?.withValues(
                      alpha: 0.6,
                    ),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 24),
                _buildPreview(theme, teacherName),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ThemeData theme, String teacherName) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildForm(theme, teacherName),
          const SizedBox(height: 32),
          Text(
            'ELŐNÉZET',
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _buildPreview(theme, teacherName),
          const SizedBox(height: 100), // Extra space at bottom
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme, String teacherName) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Name
          _buildSectionLabel('CSOPORT NEVE', theme),
          const SizedBox(height: 12),
          TextFormField(
            key: _groupNameKey,
            controller: _groupNameController,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            decoration: _buildInputDecoration(
              theme,
              'pl. Matematika 9.A',
              Icons.groups_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'A csoport neve kötelező';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 32),

          // Teacher Name (readonly)
          _buildSectionLabel('TANÁR', theme),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: teacherName,
            enabled: false,
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
            ),
            decoration: _buildInputDecoration(
              theme,
              teacherName,
              Icons.person_outline,
            ),
          ),

          const SizedBox(height: 32),

          // Color Picker
          _buildSectionLabel('CSOPORT SZÍNE', theme),
          const SizedBox(height: 16),
          _buildColorPicker(theme),

          const SizedBox(height: 32),

          // Settings
          _buildSectionLabel('BEÁLLÍTÁSOK', theme),
          const SizedBox(height: 16),
          _buildProtectionSlider(theme),

          const SizedBox(height: 48),

          // Create Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: _createButtonKey,
              onPressed: _isCreating ? null : _createGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: theme.primaryColor.withValues(alpha: 0.4),
              ),
              child: _isCreating
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: LoadingAnimationWidget.newtonCradle(
                        color: Colors.white,
                        size: 24,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Csoport Létrehozása',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, ThemeData theme) {
    return Text(
      text,
      style: TextStyle(
        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    ThemeData theme,
    String hint,
    IconData icon,
  ) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: theme.iconTheme.color?.withValues(alpha: 0.6),
      ),
      filled: true,
      fillColor: theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildColorPicker(ThemeData theme) {
    final colors = [
      // Row 1 - Reds & Oranges
      const Color(0xFFE57373), // Red
      const Color(0xFFEF5350), // Darker Red
      const Color(0xFFFF8A65), // Deep Orange
      const Color(0xFFFFB74D), // Orange
      const Color(0xFFFFD54F), // Amber
      const Color(0xFFFFF176), // Yellow
      // Row 2 - Greens
      const Color(0xFFDCE775), // Lime
      const Color(0xFFAED581), // Light Green
      const Color(0xFF81C784), // Green
      const Color(0xFF66BB6A), // Darker Green
      const Color(0xFF4DB6AC), // Teal
      const Color(0xFF26A69A), // Darker Teal
      // Row 3 - Blues
      const Color(0xFF4DD0E1), // Cyan
      const Color(0xFF4FC3F7), // Light Blue
      const Color(0xFF64B5F6), // Blue
      const Color(0xFF42A5F5), // Darker Blue
      const Color(0xFF7986CB), // Indigo
      const Color(0xFF5C6BC0), // Darker Indigo
      // Row 4 - Purples & others
      const Color(0xFF9575CD), // Deep Purple
      const Color(0xFF7E57C2), // Darker Purple
      const Color(0xFFBA68C8), // Purple
      const Color(0xFFF06292), // Pink
      const Color(0xFFA1887F), // Brown
      const Color(0xFF90A4AE), // Blue Grey
    ];

    return Column(
      key: _colorPickerKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset colors
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((color) {
            final isSelected =
                _selectedColor == color && !_showCustomColorPicker;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedColor = color;
                _showCustomColorPicker = false;
              }),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? theme.primaryColor : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: theme.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: _getContrastColor(color),
                        size: 24,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Custom color section
        InkWell(
          onTap: () =>
              setState(() => _showCustomColorPicker = !_showCustomColorPicker),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showCustomColorPicker
                    ? theme.primaryColor
                    : theme.dividerColor,
                width: _showCustomColorPicker ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _showCustomColorPicker
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: theme.iconTheme.color,
                ),
                const SizedBox(width: 12),
                Text(
                  'Egyedi szín választása',
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_showCustomColorPicker)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: HSLColor.fromAHSL(
                        1.0,
                        _hue,
                        _saturation,
                        _lightness,
                      ).toColor(),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.dividerColor, width: 2),
                    ),
                  ),
              ],
            ),
          ),
        ),

        if (_showCustomColorPicker) ...[
          const SizedBox(height: 16),
          _buildHSLSliders(theme),
        ],
      ],
    );
  }

  Widget _buildHSLSliders(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hue slider
          _buildColorSlider(
            theme: theme,
            label: 'Árnyalat',
            value: _hue,
            max: 360,
            divisions: 72,
            gradientColors: [
              const Color(0xFFFF0000), // Red
              const Color(0xFFFFFF00), // Yellow
              const Color(0xFF00FF00), // Green
              const Color(0xFF00FFFF), // Cyan
              const Color(0xFF0000FF), // Blue
              const Color(0xFFFF00FF), // Magenta
              const Color(0xFFFF0000), // Red (wrap)
            ],
            onChanged: (val) {
              setState(() {
                _hue = val;
                _selectedColor = HSLColor.fromAHSL(
                  1.0,
                  _hue,
                  _saturation,
                  _lightness,
                ).toColor();
              });
            },
          ),
          const SizedBox(height: 16),

          // Saturation slider
          _buildColorSlider(
            theme: theme,
            label: 'Telítettség',
            value: _saturation,
            max: 1,
            divisions: 100,
            gradientColors: [
              HSLColor.fromAHSL(1.0, _hue, 0, _lightness).toColor(),
              HSLColor.fromAHSL(1.0, _hue, 1, _lightness).toColor(),
            ],
            onChanged: (val) {
              setState(() {
                _saturation = val;
                _selectedColor = HSLColor.fromAHSL(
                  1.0,
                  _hue,
                  _saturation,
                  _lightness,
                ).toColor();
              });
            },
          ),
          const SizedBox(height: 16),

          // Lightness slider
          _buildColorSlider(
            theme: theme,
            label: 'Világosság',
            value: _lightness,
            max: 1,
            divisions: 100,
            gradientColors: [
              const Color(0xFF000000), // Black
              HSLColor.fromAHSL(1.0, _hue, _saturation, 0.5).toColor(),
              const Color(0xFFFFFFFF), // White
            ],
            onChanged: (val) {
              setState(() {
                _lightness = val;
                _selectedColor = HSLColor.fromAHSL(
                  1.0,
                  _hue,
                  _saturation,
                  _lightness,
                ).toColor();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColorSlider({
    required ThemeData theme,
    required String label,
    required double value,
    required double max,
    required int divisions,
    required List<Color> gradientColors,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor, width: 1),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              trackHeight: 32,
            ),
            child: Slider(
              value: value,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Color _getContrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Widget _buildProtectionSlider(ThemeData theme) {
    final labels = ['Nyitott', 'Védett', 'Zárolt'];
    final icons = [
      Icons.lock_open_rounded,
      Icons.shield_rounded,
      Icons.lock_rounded,
    ];
    final colors = [Colors.green, Colors.orange, Colors.red];
    final descriptions = [
      'Nincs védelem - házi feladat, gyakorlás',
      'Csalásmegelőzés - screenshot, hangerő, fókusz figyelés',
      'Teljes zárolás - kiosk mód + csalásmegelőzés',
    ];

    return Container(
      key: _protectionSliderKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row with icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (index) {
              final isSelected = _protectionLevel == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _protectionLevel = index),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors[index].withOpacity(0.2)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? colors[index]
                                : theme.dividerColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          icons[index],
                          color: isSelected
                              ? colors[index]
                              : theme.iconTheme.color?.withOpacity(0.5),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[index],
                        style: TextStyle(
                          color: isSelected
                              ? colors[index]
                              : theme.textTheme.bodyMedium?.color?.withOpacity(
                                  0.6,
                                ),
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colors[_protectionLevel],
              inactiveTrackColor: theme.dividerColor,
              thumbColor: colors[_protectionLevel],
              overlayColor: colors[_protectionLevel].withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              trackHeight: 6,
            ),
            child: Slider(
              value: _protectionLevel.toDouble(),
              min: 0,
              max: 2,
              divisions: 2,
              onChanged: (value) =>
                  setState(() => _protectionLevel = value.toInt()),
            ),
          ),
          const SizedBox(height: 12),
          // Description
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors[_protectionLevel].withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: colors[_protectionLevel],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    descriptions[_protectionLevel],
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: theme.primaryColor, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        trailing: Switch(
          value: value,
          activeColor: theme.primaryColor,
          onChanged: onChanged,
          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return theme.colorScheme.outline;
          }),
          trackColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return theme.primaryColor;
            }
            return theme.colorScheme.surfaceContainerHighest;
          }),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme, String teacherName) {
    final groupName = _groupNameController.text.trim().isEmpty
        ? 'Csoport Neve'
        : _groupNameController.text;

    // Get user for instructor names
    final user = context.read<UserProvider>().user;

    // Create a temporary Group for preview
    final previewGroup = Group(
      title: groupName,
      subtitle: 'Oktató: $teacherName',
      ownerName: teacherName,
      instructorFirstName: user?.firstName ?? '',
      instructorLastName: user?.lastName ?? '',
      color: _selectedColor,
    );

    return Container(
      key: _previewKey,
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Card Preview matching home_page.dart GroupCard
          GroupCard(
            group: previewGroup,
            onGroupSelected: (_) {}, // Preview only
          ),
          const SizedBox(height: 16),
          // Info badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoBadge(
                theme,
                Icons.calendar_today,
                'Létrehozva: ${_formatDate(DateTime.now())}',
              ),
              if (_protectionLevel >= 2)
                _buildInfoBadge(theme, Icons.lock, 'Zárolt mód'),
              if (_protectionLevel >= 1 && _protectionLevel < 2)
                _buildInfoBadge(theme, Icons.shield, 'Védett mód'),
              if (_protectionLevel == 0)
                _buildInfoBadge(theme, Icons.lock_open, 'Nyitott mód'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(ThemeData theme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.iconTheme.color?.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}.';
  }

  void _startTutorial() {
    late TutorialCoachMark tutorialCoachMark;
    List<TargetFocus> targets = [];

    // 1. Group Name Field
    targets.add(
      TargetFocus(
        identify: "group_name",
        keyTarget: _groupNameKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Csoport Neve",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Add meg a csoport nevét. Ez az alapvető azonosító, amely megjelenik a csoportkártyán. Például: 'Matematika 9.A' vagy 'Fizika emelt'.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // 2. Color Picker
    targets.add(
      TargetFocus(
        identify: "color_picker",
        keyTarget: _colorPickerKey,
        alignSkip: Alignment.topLeft,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Színválasztás",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Válassz egy színt a csoportnak! Használhatsz előre definiált színeket, vagy alkoss sajátot az egyedi HSL (Árnyalat, Telítettség, Világosság) csúszkákkal.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // 3. Protection Level Slider
    targets.add(
      TargetFocus(
        identify: "protection_slider",
        keyTarget: _protectionSliderKey,
        alignSkip: Alignment.topLeft,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Védelmi Szint",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Állítsd be a csoport védelmi szintjét:\n• Nyitott: Nincs védelem, ideális házi feladathoz\n• Védett: Csalásmegelőzés (screenshot blokkolás, fókusz figyelés)\n• Zárolt: Teljes zárolás kiosk móddal + minden védelemmel",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // 4. Preview
    targets.add(
      TargetFocus(
        identify: "preview",
        keyTarget: _previewKey,
        alignSkip: Alignment.topLeft,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Előnézet",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Itt láthatod élő előnézetben, hogyan fog kinézni a csoportkártya a főoldalon. Minden változtatás azonnal megjelenik!",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // 5. Create Button
    targets.add(
      TargetFocus(
        identify: "create_button",
        keyTarget: _createButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Csoport Létrehozása",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Ha minden beállítás rendben van, kattints ide a csoport létrehozásához! A csoport azonnal megjelenik a főoldalon, és megoszthatod a meghívó kódot a diákokkal.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "Kihagyás",
      paddingFocus: 0,
      opacityShadow: 0.9,
      pulseEnable: true,
      onFinish: () {
        debugPrint("TUTORIAL: Create group tutorial finished");
        _finishTutorial();
      },
      onClickTarget: (target) {
        debugPrint("onClickTarget: $target");
      },
      onSkip: () {
        debugPrint("TUTORIAL: Tutorial skipped");
        _finishTutorial();
        return true;
      },
    );

    // Add a slight delay before showing to ensure rendering is complete
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        tutorialCoachMark.show(context: context);
      }
    });
  }

  bool _isNavigating = false;

  void _finishTutorial() {
    if (_isNavigating) return;
    _isNavigating = true;

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Útmutató befejezve. Visszatérés..."),
          duration: Duration(milliseconds: 1000),
        ),
      );
    }

    // Simple delay to let the snackbar appear and overlay to close
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        debugPrint("TUTORIAL: Popping CreateGroupPage now");
        Navigator.of(
          context,
        ).maybePop(true); // Return true to indicate tutorial completion
      }
    });
  }

  Future<void> _createGroup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isCreating = true);

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token;

      if (token == null) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hiba: Nincs bejelentkezve'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Convert color to hex string (without alpha)
      final colorHex = _selectedColor.value
          .toRadixString(16)
          .substring(2)
          .toUpperCase();

      final apiService = ApiService();
      final result = await apiService.createGroup(
        token,
        _groupNameController.text.trim(),
        colorHex,
      );

      if (!mounted) return;

      setState(() => _isCreating = false);

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Csoport "${_groupNameController.text}" sikeresen létrehozva!',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Hiba a csoport létrehozásakor'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}
