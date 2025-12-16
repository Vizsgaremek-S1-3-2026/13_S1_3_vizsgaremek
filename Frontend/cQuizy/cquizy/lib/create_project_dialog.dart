import 'package:flutter/material.dart';

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key});

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Új Projekt Létrehozása'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Projekt neve',
                  hintText: 'pl. Töri beadandó',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'A projekt neve kötelező';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Leírás (opcionális)',
                  hintText: 'Rövid leírás a projektről...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mégse'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'desc': _descController.text.trim(),
              });
            }
          },
          child: const Text('Létrehozás'),
        ),
      ],
    );
  }
}
