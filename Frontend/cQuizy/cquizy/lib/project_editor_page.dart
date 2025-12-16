import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';
import 'providers/user_provider.dart';

class ProjectEditorPage extends StatefulWidget {
  final int projectId;
  final String initialName;
  final String initialDesc;

  const ProjectEditorPage({
    super.key,
    required this.projectId,
    required this.initialName,
    required this.initialDesc,
  });

  @override
  State<ProjectEditorPage> createState() => _ProjectEditorPageState();
}

class _ProjectEditorPageState extends State<ProjectEditorPage> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  List<Map<String, dynamic>> _blocks = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _questionTypes = ['single', 'multiple', 'text'];
  final Map<String, String> _typeLabels = {
    'single': 'Egyszeres választás',
    'multiple': 'Többszörös választás',
    'text': 'Szöveges válasz',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descController = TextEditingController(text: widget.initialDesc);
    _fetchProjectDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchProjectDetails() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    final api = ApiService();
    final data = await api.getProjectDetails(token, widget.projectId);

    if (mounted && data != null) {
      setState(() {
        _nameController.text = data['name'] ?? widget.initialName;
        _descController.text = data['desc'] ?? widget.initialDesc;
        _blocks = List<Map<String, dynamic>>.from(
          (data['blocks'] as List?)?.map((b) {
                final block = Map<String, dynamic>.from(b);
                if (block['type'] is String) {
                  block['type'] = (block['type'] as String).toLowerCase();
                }
                // Ensure type is valid, fallback to 'single' if not
                if (!_questionTypes.contains(block['type'])) {
                  block['type'] = 'single';
                }
                return block;
              }) ??
              [],
        );
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProject() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    setState(() => _isSaving = true);

    final data = {
      'name': _nameController.text,
      'desc': _descController.text,
      'blocks': _blocks,
    };

    final api = ApiService();
    final result = await api.updateProject(token, widget.projectId, data);

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Projekt sikeresen mentve!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hiba a projekt mentésekor'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addQuestion() {
    setState(() {
      _blocks.add({
        'order': _blocks.length,
        'question': '',
        'type': 'single',
        'subtext': '',
        'image_url': '',
        'link_url': '',
        'answers': [
          {'text': '', 'is_correct': false},
          {'text': '', 'is_correct': false},
        ],
      });
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _blocks.removeAt(index);
      for (int i = 0; i < _blocks.length; i++) {
        _blocks[i]['order'] = i;
      }
    });
  }

  void _addAnswer(int blockIndex) {
    setState(() {
      final answers = List<Map<String, dynamic>>.from(
        _blocks[blockIndex]['answers'] ?? [],
      );
      answers.add({'text': '', 'is_correct': false});
      _blocks[blockIndex]['answers'] = answers;
    });
  }

  void _removeAnswer(int blockIndex, int answerIndex) {
    setState(() {
      final answers = List<Map<String, dynamic>>.from(
        _blocks[blockIndex]['answers'] ?? [],
      );
      if (answers.length > 1) {
        answers.removeAt(answerIndex);
        _blocks[blockIndex]['answers'] = answers;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Projekt Szerkesztő',
          style: TextStyle(
            color: theme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveProject,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, size: 18),
              label: const Text('Mentés'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project Name Section
                  _buildSectionLabel('Projekt neve', theme),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Add meg a projekt nevét...',
                    theme: theme,
                  ),
                  const SizedBox(height: 24),

                  // Project Description Section
                  _buildSectionLabel('Projekt leírása', theme),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _descController,
                    hint: 'Add meg a projekt leírását...',
                    theme: theme,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  // Divider
                  Container(height: 1, color: theme.dividerColor),
                  const SizedBox(height: 24),

                  // Questions Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kérdések',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _addQuestion,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Új kérdés'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Questions List
                  if (_blocks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.quiz_outlined,
                              size: 48,
                              color: theme.textTheme.titleMedium?.color,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Még nincsenek kérdések',
                              style: TextStyle(
                                color: theme.textTheme.titleMedium?.color,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Adj hozzá az első kérdésedet!',
                              style: TextStyle(
                                color: theme.textTheme.titleMedium?.color
                                    ?.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._blocks.asMap().entries.map((entry) {
                      final index = entry.key;
                      final block = entry.value;
                      return _buildQuestionCard(index, block, theme);
                    }),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String text, ThemeData theme) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: theme.textTheme.titleMedium?.color,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required ThemeData theme,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: theme.textTheme.titleMedium?.color?.withOpacity(0.6),
        ),
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildQuestionCard(
    int index,
    Map<String, dynamic> block,
    ThemeData theme,
  ) {
    final answers = List<Map<String, dynamic>>.from(block['answers'] ?? []);
    final selectedType = block['type'] ?? 'single';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.drag_handle,
                  color: theme.textTheme.titleMedium?.color,
                ),
                const SizedBox(width: 12),
                Text(
                  '${index + 1}. Kérdés',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                // Type Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedType,
                      dropdownColor: theme.cardColor,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 13,
                      ),
                      items: _questionTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(_typeLabels[type] ?? type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _blocks[index]['type'] = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _removeQuestion(index),
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.redAccent,
                  tooltip: 'Kérdés törlése',
                ),
              ],
            ),
          ),

          // Card Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question Text
                _buildTextField(
                  controller: TextEditingController(
                    text: block['question'] ?? '',
                  ),
                  hint: 'Írd ide a kérdést...',
                  theme: theme,
                ),
                const SizedBox(height: 12),

                // Subtext (collapsed by default - show hint)
                TextField(
                  controller: TextEditingController(
                    text: block['subtext'] ?? '',
                  ),
                  onChanged: (val) => _blocks[index]['subtext'] = val,
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Segédszöveg (opcionális)...',
                    hintStyle: TextStyle(
                      color: theme.textTheme.titleMedium?.color?.withOpacity(
                        0.5,
                      ),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: theme.dividerColor.withOpacity(0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.primaryColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),

                // Answers Section (only for choice types)
                if (selectedType != 'text') ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Válaszlehetőségek',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _addAnswer(index),
                        icon: Icon(
                          Icons.add,
                          size: 16,
                          color: theme.primaryColor,
                        ),
                        label: Text(
                          'Új válasz',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ...answers.asMap().entries.map((ansEntry) {
                    final ansIndex = ansEntry.key;
                    final answer = ansEntry.value;
                    return _buildAnswerRow(index, ansIndex, answer, theme);
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerRow(
    int blockIndex,
    int answerIndex,
    Map<String, dynamic> answer,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Correct checkbox
          Checkbox(
            value: answer['is_correct'] ?? false,
            onChanged: (val) {
              setState(() {
                _blocks[blockIndex]['answers'][answerIndex]['is_correct'] =
                    val ?? false;
              });
            },
            activeColor: Colors.green,
            side: BorderSide(color: theme.dividerColor),
          ),
          const SizedBox(width: 8),
          // Answer text field
          Expanded(
            child: TextField(
              controller: TextEditingController(text: answer['text'] ?? ''),
              onChanged: (val) {
                _blocks[blockIndex]['answers'][answerIndex]['text'] = val;
              },
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Válasz szövege...',
                hintStyle: TextStyle(
                  color: theme.textTheme.titleMedium?.color?.withOpacity(0.5),
                ),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Delete button
          IconButton(
            onPressed: () => _removeAnswer(blockIndex, answerIndex),
            icon: const Icon(Icons.close, size: 18),
            color: Colors.redAccent,
            tooltip: 'Válasz törlése',
          ),
        ],
      ),
    );
  }
}
