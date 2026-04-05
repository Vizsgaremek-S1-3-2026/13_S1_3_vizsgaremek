import 'package:flutter/material.dart';
import '../group_page.dart';
import 'texture_painter.dart';

class GroupCard extends StatefulWidget {
  final Group group;
  final Function(Group) onGroupSelected;

  const GroupCard({
    super.key,
    required this.group,
    required this.onGroupSelected,
  });

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: Container(
            margin: EdgeInsets.only(
              bottom: isMobile ? 12.0 : 16.0,
              left: isMobile ? 12.0 : 16.0,
              right: isMobile ? 12.0 : 16.0,
            ),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: widget.group.getGradient(context),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: widget.group.color.withValues(
                    alpha: 0.2,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.onGroupSelected(widget.group),
                  onHover: (hovering) => setState(() => _isHovered = hovering),
                  borderRadius: BorderRadius.circular(12),
                  splashColor: Colors.white.withValues(alpha: 0.2),
                  highlightColor: Colors.white.withValues(alpha: 0.1),
                  child: Stack(
                    children: [
                      // Background Texture
                      Positioned.fill(
                        child: CustomPaint(
                          painter: SubtleTexturePainter(
                            color: widget.group.getTextColor(context),
                            opacity: 0.15, // More visible base opacity
                            isHovered: _isHovered,
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 20.0 : 40.0,
                          vertical: isMobile ? 14.0 : 20.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.group.title,
                              style: TextStyle(
                                color: widget.group.getTextColor(context),
                                fontSize: isMobile ? 20 : 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.group.subtitle,
                              style: TextStyle(
                                color: widget.group
                                    .getTextColor(context)
                                    .withOpacity(0.85),
                                fontSize: isMobile ? 13 : 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Notification Dot (Inside clickable area)
                      if (widget.group.hasNotification)
                        Positioned(
                          right: isMobile ? 20 : 30,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xfffdd835),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
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
}
