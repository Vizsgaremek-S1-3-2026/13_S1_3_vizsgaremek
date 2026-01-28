import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';

class DeveloperConsole extends StatefulWidget {
  const DeveloperConsole({super.key});

  @override
  State<DeveloperConsole> createState() => _DeveloperConsoleState();
}

class _DeveloperConsoleState extends State<DeveloperConsole> {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final logs = userProvider.logs;
    final theme = Theme.of(context);

    return Container(
      width: 600,
      height: 500,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal, color: theme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Fejlesztői Konzol',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Napló másolása',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: logs.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Napló a vágólapra másolva'),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Napló törlése',
                  onPressed: () => userProvider.clearLogs(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'Nincs bejegyzés a naplóban',
                      style: TextStyle(color: theme.disabledColor),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    reverse:
                        true, 
                    itemBuilder: (context, index) {
                      final log = logs[logs.length - 1 - index];
                      final isError =
                          log.contains('Hiba') ||
                          log.contains('Exception') ||
                          log.contains('Status:');

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SelectableText(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: isError
                                ? Colors.red
                                : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
