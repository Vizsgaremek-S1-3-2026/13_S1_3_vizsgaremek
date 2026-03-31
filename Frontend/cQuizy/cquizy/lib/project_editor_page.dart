import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'api_service.dart';
import 'providers/user_provider.dart';
import 'theme.dart';

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
  bool _hasUnsavedChanges = false;
  bool _showOrderPanel = false;
  bool _showSettingsPanel = false;
  bool _showStatisticsPanel = false;
  int _defaultCorrectPoints = 1;
  int _defaultIncorrectPoints = 0;
  String _editorMode = 'normal'; // 'normal' or 'math'

  double _mathDeviation = 10.0;

  // Question Bank State
  bool _showQuestionBankPanel = false;
  bool _isToolsMenuOpen = false; // For mobile speed dial
  bool _isBankSearching = false;
  List<Map<String, dynamic>> _bankSearchResults = [];
  final TextEditingController _bankSearchController = TextEditingController();
  Timer? _debounce;

  // Undo/Redo Stacks
  final List<List<Map<String, dynamic>>> _undoStack = [];
  final List<List<Map<String, dynamic>>> _redoStack = [];

  final List<String> _questionTypes = [
    'single',
    'multiple',
    'text',
    'matching',
    'ordering',
    'gap_fill',
    'range',
    'category',
    'sentence_ordering',
    'text_block',
    'divider',
  ];
  final Map<String, String> _typeLabels = {
    'single': 'Egyszeres választás',
    'multiple': 'Többszörös választás',
    'text': 'Szöveges válasz',
    'matching': 'Párosítás',
    'ordering': 'Sorba rendezés',
    'gap_fill': 'Kitöltős szöveg',
    'range': 'Intervallum válasz',
    'sentence_ordering': 'Mondat újrarendezés',
  };

  static const double _maxContentWidth = 800.0;

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
    _bankSearchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onBankSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performBankSearch(query);
    });
  }

  Future<void> _exportProject() async {
    final Map<String, dynamic> projectData = {
      'name': _nameController.text,
      'desc': _descController.text,
      'blocks': _blocks,
    };

    try {
      final String jsonString = jsonEncode(projectData);
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Projekt exportálása',
        fileName:
            '${_nameController.text.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}.cq',
        allowedExtensions: ['cq'],
        type: FileType.custom,
      );

      if (outputFile != null) {
        // Enforce extension
        if (!outputFile.endsWith('.cq')) {
          outputFile += '.cq';
        }
        final File file = File(outputFile);
        await file.writeAsString(jsonString);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Projekt sikeresen exportálva!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba az exportálás során: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _saveValidState() {
    // Deep copy current blocks (even if empty, to allow undo to empty state)
    final deepCopy = _blocks.map((b) {
      final block = Map<String, dynamic>.from(b);
      if (block['answers'] != null) {
        block['answers'] = (block['answers'] as List)
            .map((a) => Map<String, dynamic>.from(a))
            .toList();
      }
      return block;
    }).toList();

    _undoStack.add(deepCopy);
    if (_undoStack.length > 20) _undoStack.removeAt(0); // Limit history
    _redoStack.clear();
    _hasUnsavedChanges = true;
  }

  List<String> _validateBlock(Map<String, dynamic> block) {
    final errors = <String>[];
    final type = block['type'] ?? 'single';

    // Non-question types don't need validation
    if (type == 'text_block' || type == 'divider') {
      return errors; // No validation needed
    }

    // Question text check
    if ((block['question'] ?? '').trim().isEmpty) {
      errors.add('A kérdés szövege nem lehet üres.');
    }

    // Type-specific checks
    if (type == 'single' || type == 'multiple') {
      final answers = block['answers'] as List?;
      if (answers == null || answers.isEmpty) {
        errors.add('Vegyél fel legalább egy választ.');
      } else {
        final hasCorrect = answers.any((a) => a['is_correct'] == true);
        if (!hasCorrect) {
          errors.add('Válassz legalább egy helyes választ.');
        }
        for (var i = 0; i < answers.length; i++) {
          if ((answers[i]['text'] ?? '').trim().isEmpty) {
            errors.add('A(z) ${i + 1}. válasz szövege üres.');
          }
        }
      }
    } else if (type == 'gap_fill') {
      final text = block['gap_text'] ?? '';
      final answers = block['answers'] as List? ?? [];

      if (text.trim().isEmpty) {
        errors.add('A kitöltős szöveg nem lehet üres.');
      }

      final exp = RegExp(r'\{(\d+)\}');
      final matches = exp.allMatches(text);
      final usedIndices = <int>{};
      for (final match in matches) {
        final idxStr = match.group(1);
        if (idxStr != null) {
          final idx = int.tryParse(idxStr);
          if (idx != null) usedIndices.add(idx);
        }
      }

      if (usedIndices.isEmpty) {
        errors.add('Használj legalább egy {szám} jelölést a szövegben.');
      }

      for (final idx in usedIndices) {
        final hasAnswer = answers.any(
          (a) => a['gap_index'].toString() == idx.toString(),
        );
        if (!hasAnswer) {
          errors.add('A {$idx} jelöléshez nincs válasz definiálva.');
        }
      }

      if (_hasDuplicateGaps(text)) {
        errors.add(
          'Néhány jelölés ({1}, {2}...) többször szerepel a szövegben.',
        );
      }
    } else if (type == 'matching') {
      final answers = block['answers'] as List? ?? [];
      if (answers.length < 1) {
        errors.add('Vegyél fel legalább egy párt.');
      } else {
        for (var i = 0; i < answers.length; i++) {
          final a = answers[i];
          if ((a['text'] ?? '').trim().isEmpty ||
              (a['match_text'] ?? '').trim().isEmpty) {
            errors.add(
              'A(z) ${i + 1}. párosítás hiányos (fogalom vagy definíció hiányzik).',
            );
          }
        }
      }
    } else if (type == 'ordering') {
      final answers = block['answers'] as List? ?? [];
      if (answers.length < 2) {
        errors.add('Sorrendezéshez legalább 2 elem kell.');
      } else {
        for (var i = 0; i < answers.length; i++) {
          if ((answers[i]['text'] ?? '').trim().isEmpty) {
            errors.add('A(z) ${i + 1}. elem szövege üres.');
          }
        }
      }
    } else if (type == 'category') {
      final categories = block['categories'] as List? ?? [];
      if (categories.isEmpty) {
        errors.add('Vegyél fel legalább egy kategóriát.');
      } else {
        for (var j = 0; j < categories.length; j++) {
          final cat = categories[j];
          final catName = (cat['name'] ?? '').trim();
          if (catName.isEmpty) {
            errors.add('A(z) ${j + 1}. kategória neve üres.');
          }
          final items = cat['items'] as List? ?? [];
          if (items.isEmpty) {
            errors.add(
              'A(z) ${catName.isEmpty ? j + 1 : catName} kategóriának nincs eleme.',
            );
          } else if (items.any((it) => (it as String).trim().isEmpty)) {
            errors.add(
              'A(z) ${catName.isEmpty ? j + 1 : catName} kategóriában van üres elem.',
            );
          }
        }
      }
    } else if (type == 'range') {
      final answers = block['answers'] as List? ?? [];
      if (answers.isEmpty) {
        errors.add('Definiálj egy helyes értéket.');
      } else {
        final a = answers[0];
        if (a['correct_value'] == null && a['text'] == null) {
          errors.add('A helyes érték nem érvényes szám.');
        }
        // Tolerance is optional, usually defaults to 0
      }
    } else if (type == 'sentence_ordering') {
      final answers = block['answers'] as List? ?? [];
      if (answers.isEmpty) {
        errors.add('Írj be egy mondatot és válaszd a "Bontás" gombot.');
      } else {
        for (var i = 0; i < answers.length; i++) {
          if ((answers[i]['text'] ?? '').trim().isEmpty) {
            errors.add('A(z) ${i + 1}. szó üres.');
          }
        }
      }
    } else if (type == 'text') {
      // Nyílt kérdésnél nem kötelező a helyes válasz
    }

    return errors;
  }

  bool _validateAll() {
    final allErrors = <Map<String, dynamic>>[];
    for (var i = 0; i < _blocks.length; i++) {
      final errors = _validateBlock(_blocks[i]);
      if (errors.isNotEmpty) {
        allErrors.add({'index': i + 1, 'errors': errors});
      }
    }

    if (allErrors.isNotEmpty) {
      _showValidationErrorDialog(allErrors);
      return false;
    }
    return true;
  }

  void _showValidationErrorDialog(List<Map<String, dynamic>> allErrors) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Color(0xFFFFB74D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Hiba a mentés előtt',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A projekt mentése nem lehetséges, amíg az alábbiakat ki nem javítod:',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.8,
                        ),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: allErrors.length > 5 ? 6 : allErrors.length,
                        itemBuilder: (context, idx) {
                          if (idx == 5) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '...és további ${allErrors.length - 5} kérdésnél található hiba.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: theme.disabledColor,
                                ),
                              ),
                            );
                          }
                          final err = allErrors[idx];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${err['index']}. kérdés',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.orangeAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.orangeAccent.withOpacity(
                                          0.2,
                                        ),
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...(err['errors'] as List<String>).map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(
                                      left: 4,
                                      bottom: 4,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '• ',
                                          style: TextStyle(
                                            color: Colors.orangeAccent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            e,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: theme
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Footer Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Rendben, javítom',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();

    setState(() {
      // Save current state to redo
      final deepCopy = _blocks.map((b) {
        final block = Map<String, dynamic>.from(b);
        if (block['answers'] != null) {
          block['answers'] = (block['answers'] as List)
              .map((a) => Map<String, dynamic>.from(a))
              .toList();
        }
        return block;
      }).toList();
      _redoStack.add(deepCopy);

      _blocks = _undoStack.removeLast();
      // If undo stack is empty, we're back to original state
      _hasUnsavedChanges = _undoStack.isNotEmpty;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();

    setState(() {
      // Save current to undo
      final deepCopy = _blocks.map((b) {
        final block = Map<String, dynamic>.from(b);
        if (block['answers'] != null) {
          block['answers'] = (block['answers'] as List)
              .map((a) => Map<String, dynamic>.from(a))
              .toList();
        }
        return block;
      }).toList();
      _undoStack.add(deepCopy);

      _blocks = _redoStack.removeLast();
      // Redoing means we have changes again
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _performBankSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _bankSearchResults = []);
      return;
    }

    setState(() => _isBankSearching = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token;
      if (token != null) {
        final api = ApiService();
        final results = await api.searchUserBlocks(token, query);
        if (mounted) {
          setState(() {
            _bankSearchResults = results;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isBankSearching = false);
    }
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
                if (!_questionTypes.contains(block['type'])) {
                  block['type'] = 'single';
                }
                // For divider and text_block, set content from maintext
                final blockType = block['type'];
                if (blockType == 'divider' || blockType == 'text_block') {
                  block['content'] = block['maintext']?.toString() ?? '';
                }
                if (block['answers'] != null) {
                  block['answers'] = List<Map<String, dynamic>>.from(
                    (block['answers'] as List).map((a) {
                      final answer = Map<String, dynamic>.from(a);
                      answer['points'] ??= (answer['is_correct'] == true)
                          ? 1
                          : 0;
                      return answer;
                    }),
                  );
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

  void _addQuestionFromBank(Map<String, dynamic> bankItem) {
    if (!mounted) return;
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();

    setState(() {
      final newBlock = Map<String, dynamic>.from(bankItem);
      // Remove ID to ensure it's treated as a new block for this project (or keep if needed for linking, but better new)
      newBlock.remove('id');
      newBlock['project_id'] = widget.projectId; // Assign to current project
      newBlock['order'] = _blocks.length;

      // Ensure answers are mutable lists/maps
      if (newBlock['answers'] != null) {
        newBlock['answers'] = (newBlock['answers'] as List)
            .map((a) => Map<String, dynamic>.from(a))
            .toList();
      } else {
        newBlock['answers'] = [];
      }

      _blocks.add(newBlock);

      // Close panel after adding? Or keep open for multi-add? User preference usually multi-add.
      // Showing a snackbar confirmation is good practice.
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Kérdés hozzáadva'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Widget helpers
  Widget _buildSettingsInput({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: () => onChanged(value - 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    value.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: () => onChanged(value + 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveProject() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final token = userProvider.token;
    if (token == null) return;

    if (!_validateAll()) {
      return;
    }

    setState(() => _isSaving = true);

    // Clean up blocks for API - ensure ALL fields match schema exactly
    final cleanedBlocks = _blocks.asMap().entries.map((entry) {
      final block = Map<String, dynamic>.from(entry.value);

      // Build a clean block matching the API schema exactly
      final cleanBlock = <String, dynamic>{};

      // Note: NOT including 'id' - server uses URL parameter for identification

      // type: required, default to 'single'
      final blockType = block['type']?.toString() ?? 'single';
      cleanBlock['type'] = blockType;

      // maintext: required string
      // For dividers, use 'content' field; for others, use 'question' as fallback
      final maintext = block['maintext']?.toString() ?? '';
      if (blockType == 'divider' || blockType == 'text_block') {
        // For divider/text_block, use content field for maintext
        cleanBlock['maintext'] = maintext.isEmpty
            ? (block['content']?.toString() ?? '')
            : maintext;
      } else {
        // For regular questions, use question as fallback
        cleanBlock['maintext'] = maintext.isEmpty
            ? (block['question']?.toString() ?? '')
            : maintext;
      }

      // question: required string
      cleanBlock['question'] = block['question']?.toString() ?? '';

      // subtext: required string (empty if not set)
      cleanBlock['subtext'] = block['subtext']?.toString() ?? '';

      // image_url: required string (empty if not set)
      cleanBlock['image_url'] = block['image_url']?.toString() ?? '';

      // link_url: required string (empty if not set)
      cleanBlock['link_url'] = block['link_url']?.toString() ?? '';

      // gap_text: required string (empty if not set)
      cleanBlock['gap_text'] = block['gap_text']?.toString() ?? '';

      // Clean up answers with ALL required fields
      final answers = List<Map<String, dynamic>>.from(block['answers'] ?? []);
      cleanBlock['answers'] = answers.asMap().entries.map((answerEntry) {
        final answer = answerEntry.value;
        final int answerIndex = answerEntry.key;

        final cleanAnswer = <String, dynamic>{};

        // Note: NOT including 'id' - server manages IDs

        // text: required string
        cleanAnswer['text'] = answer['text']?.toString() ?? '';

        // is_correct: required bool
        // For 'text' type questions, all answers MUST be correct for the backend
        if (blockType == 'text') {
          cleanAnswer['is_correct'] = true;
        } else {
          cleanAnswer['is_correct'] = answer['is_correct'] == true;
        }

        // points: required int
        cleanAnswer['points'] = (answer['points'] as num?)?.toInt() ?? 0;

        // order: required int - MUST be sequential
        cleanAnswer['order'] = answerIndex;

        // match_text: required string (for matching questions)
        cleanAnswer['match_text'] = answer['match_text']?.toString() ?? '';

        // gap_index: required int (for gap-fill questions)
        cleanAnswer['gap_index'] = (answer['gap_index'] as num?)?.toInt() ?? 0;

        // numeric_value: required int (for numeric questions)
        cleanAnswer['numeric_value'] =
            (answer['numeric_value'] as num?)?.toInt() ?? 0;

        // tolerance: required int (for numeric questions)
        cleanAnswer['tolerance'] = (answer['tolerance'] as num?)?.toInt() ?? 0;

        return cleanAnswer;
      }).toList();

      return cleanBlock;
    }).toList();

    final data = {
      'name': _nameController.text,
      'desc': _descController.text.isEmpty ? '-' : _descController.text,
      'blocks': cleanedBlocks,
    };

    final api = ApiService();

    // Log payload to Developer Console for debugging
    if (userProvider.isDeveloperMode) {
      userProvider.addLog('PAYLOAD: ${data.toString()}');
    }

    try {
      await api.updateProject(token, widget.projectId, data);

      if (!mounted) return;
      setState(() => _isSaving = false);
      setState(() => _hasUnsavedChanges = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Projekt sikeresen mentve!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      final msg = e.toString();
      userProvider.addLog(msg); // Log to developer console

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            userProvider.isDeveloperMode
                ? 'Hiba: $msg'
                : 'Hiba a projekt mentésekor',
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _addQuestion() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Válassz kérdéstípust',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(
                  Icons.radio_button_checked,
                  color: theme.primaryColor,
                ),
                title: Text(
                  'Hagyományos (egy válasz)',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addQuestionBlock('single');
                },
              ),
              ListTile(
                leading: Icon(Icons.check_box, color: theme.primaryColor),
                title: Text(
                  'Több válasz',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addQuestionBlock('multiple');
                },
              ),
              ListTile(
                leading: Icon(Icons.text_fields, color: theme.primaryColor),
                title: Text(
                  'Szöveges válasz',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addQuestionBlock('text');
                },
              ),
              ListTile(
                leading: Icon(Icons.thumbs_up_down, color: theme.primaryColor),
                title: Text(
                  'Igaz / Hamis',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addTrueFalseQuestion();
                },
              ),
              ListTile(
                leading: Icon(Icons.compare_arrows, color: theme.primaryColor),
                title: Text(
                  'Párosítás',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                ),
                subtitle: Text(
                  'Fogalmak és definíciók összekötése',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addMatchingQuestion();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.format_list_numbered,
                  color: theme.primaryColor,
                ),
                title: Text(
                  'Sorba rendezés',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                ),
                subtitle: Text(
                  'Elemek helyes sorrendbe állítása',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addOrderingQuestion();
                },
              ),
              ListTile(
                leading: Icon(Icons.short_text, color: theme.primaryColor),
                title: Text(
                  'Kitöltős szöveg',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                ),
                subtitle: Text(
                  'Hiányzó szavak kitöltése szövegben',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addGapFillQuestion();
                },
              ),
              ListTile(
                leading: Icon(Icons.straighten, color: theme.primaryColor),
                title: Text(
                  'Intervallum válasz',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                ),
                subtitle: Text(
                  'Szám megadása toleranciával',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addRangeQuestion();
                },
              ),

              ListTile(
                leading: Icon(Icons.sort_by_alpha, color: theme.primaryColor),
                title: Text(
                  'Mondat újrarendezés',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                ),
                subtitle: Text(
                  'Összekevert szavak sorbarendezése',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addSentenceOrderingQuestion();
                },
              ),
              const Divider(height: 24),
              // Non-question elements
              ListTile(
                leading: Icon(Icons.notes, color: theme.primaryColor),
                title: Text(
                  'Szöveg blokk',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                ),
                subtitle: Text(
                  'Magyarázat vagy instrukció hozzáadása',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addTextBlock();
                },
              ),
              ListTile(
                leading: Icon(Icons.horizontal_rule, color: theme.primaryColor),
                title: Text(
                  'Elválasztó',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                ),
                subtitle: Text(
                  'Vonal opcionális szöveggel',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addDividerBlock();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applySettingsToAll() {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();

    setState(() {
      for (var block in _blocks) {
        final type = block['type'] ?? 'single';
        if (block['answers'] != null) {
          final answers = block['answers'] as List;

          if (type == 'gap_fill' ||
              type == 'matching' ||
              type == 'ordering' ||
              type == 'sentence_ordering') {
            // For these types, all defined answers are parts of the solution -> Correct Points
            for (var answer in answers) {
              answer['points'] = _defaultCorrectPoints;
            }
          } else if (type == 'range') {
            if (answers.isNotEmpty) {
              answers[0]['points'] = _defaultCorrectPoints;
            }
          } else if (type == 'category') {
            // Categories have nested items, but blocks might store points_per_item at top level?
            // Checking _buildCategoryAnswers: points_per_item is in block root or handled differently.
            // Actually category points are usually per item. Let's check if we can update block['points_per_item']?
            // Code view line 1242 shows "Pont / helyes elem".
            block['points_per_item'] = _defaultCorrectPoints;
          } else {
            // Single / Multiple choice
            for (var answer in answers) {
              if (answer['is_correct'] == true) {
                answer['points'] = _defaultCorrectPoints;
              } else {
                answer['points'] = _defaultIncorrectPoints;
              }
            }
          }
        } else if (type == 'category') {
          // Category might not have 'answers' array but 'categories' array.
          // But points are usually defined at block level or per item.
          block['points_per_item'] = _defaultCorrectPoints;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Pontszámok frissítve minden kérdésnél!'),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _confirmDeleteProject() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red, Color(0xFFFF5252)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Projekt Törlése',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Biztosan törölni szeretnéd a "${_nameController.text}" projektet?',
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ez a művelet nem vonható vissza! A projekt és az összes kérdése törlésre kerül.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                    const SizedBox(height: 32),
                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(
                            'Mégse',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Törlés'),
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
    );

    if (confirmed == true && mounted) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final token = userProvider.token;
      if (token == null) return;

      setState(() => _isLoading = true);
      final api = ApiService();
      final success = await api.deleteProject(token, widget.projectId);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        Navigator.of(
          context,
        ).pop(true); // Return true to indicate deletion/update
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Projekt sikeresen törölve'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Hiba a projekt törlésekor'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _addQuestionBlock(String type) {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();
    setState(() {
      _blocks.add({
        'order': _blocks.length,
        'question': '',
        'type': type,
        'subtext': '',
        'image_url': '',
        'link_url': '',
        'answers': [
          {
            'text': '',
            'is_correct': type == 'text',
            'points': type == 'text' ? 1 : 0
          },
          {
            'text': '',
            'is_correct': type == 'text',
            'points': type == 'text' ? 1 : 0
          },
        ],
      });
    });
  }

  void _addTrueFalseQuestion() {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();
    setState(() {
      _blocks.add({
        'order': _blocks.length,
        'question': '',
        'type': 'single', // T/F is technically single selection
        'subtext': '',
        'image_url': '',
        'link_url': '',
        'answers': [
          {'text': 'Igaz', 'is_correct': true, 'points': 1},
          {'text': 'Hamis', 'is_correct': false, 'points': 0},
        ],
      });
    });
  }

  void _addMatchingQuestion() {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();
    setState(() {
      _blocks.add({
        'order': _blocks.length,
        'question': '',
        'type': 'matching',
        'subtext': '',
        'image_url': '',
        'link_url': '',
        'answers': [
          {'text': '', 'match_text': '', 'points': 1},
          {'text': '', 'match_text': '', 'points': 1},
        ],
      });
    });
  }

  void _addOrderingQuestion() {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();
    setState(() {
      _blocks.add({
        'order': _blocks.length,
        'question': '',
        'type': 'ordering',
        'subtext': '',
        'image_url': '',
        'link_url': '',
        'answers': [
          {'text': '', 'order': 0, 'points': 1},
          {'text': '', 'order': 1, 'points': 1},
          {'text': '', 'order': 2, 'points': 1},
        ],
      });
    });
  }

  void _addGapFillQuestion() {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();
    setState(() {
      _blocks.add({
        'order': _blocks.length,
        'question': '',
        'type': 'gap_fill',
        'subtext': 'Használd a {1}, {2}, stb. jelölést a kitöltendő helyekhez',
        'image_url': '',
        'link_url': '',
        // gap_text contains the full text with {1}, {2} placeholders
        'gap_text': 'A víz {1} fokon forr. A jég {2} fokon olvad.',
        // answers contains the correct answers for each gap
        'answers': [
          {'gap_index': 1, 'text': '100', 'points': 1},
          {'gap_index': 2, 'text': '0', 'points': 1},
        ],
      });
    });
  }

  void _addRangeQuestion() {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();
    setState(() {
      _blocks.add({
        'order': _blocks.length,
        'question': '',
        'type': 'range',
        'subtext': '',
        'image_url': '',
        'link_url': '',
        // Range answer: correct value with tolerance
        'answers': [
          {
            'correct_value': 100,
            'tolerance': 5, // Accepts 95-105
            'points': 1,
          },
        ],
      });
    });
  }

  void _addSentenceOrderingQuestion() {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();
    setState(() {
      _blocks.add({
        'order': _blocks.length,
        'question': '',
        'type': 'sentence_ordering',
        'subtext': 'Rakd helyes sorrendbe a szavakat!',
        'image_url': '',
        'link_url': '',
        // The words list for reordering
        'answers': [
          {'text': 'Példa', 'points': 1},
          {'text': 'mondat', 'points': 1},
        ],
      });
    });
  }

  void _addTextBlock() {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();
    setState(() {
      _blocks.add({
        'order': _blocks.length,
        'type': 'text_block',
        'content': '', // The text content
        'answers': [], // No answers for text blocks
      });
    });
  }

  void _addDividerBlock() {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();
    setState(() {
      _blocks.add({
        'order': _blocks.length,
        'type': 'divider',
        'content': '', // Optional label text (can be empty)
        'answers': [], // No answers for dividers
      });
    });
  }

  void _addSentenceWord(int blockIndex) {
    _saveValidState();
    setState(() {
      final answers = List<Map<String, dynamic>>.from(
        _blocks[blockIndex]['answers'] ?? [],
      );
      answers.add({'text': '', 'points': 1});
      _blocks[blockIndex]['answers'] = answers;
    });
  }

  Widget _buildSentenceOrderingAnswers(
    int blockIndex,
    List<Map<String, dynamic>> answers,
    ThemeData theme,
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick entry field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mondat bevitele (szóközökkel választva)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(
                        text: _blocks[blockIndex]['_temp_sentence'] ?? '',
                      ),
                      onChanged: (val) =>
                          _blocks[blockIndex]['_temp_sentence'] = val,
                      onSubmitted: (val) {
                        if (val.trim().isEmpty) return;
                        _saveValidState();
                        final words = val.trim().split(RegExp(r'\s+'));
                        setState(() {
                          _blocks[blockIndex]['answers'] = words
                              .map((w) => {'text': w, 'points': 1})
                              .toList();
                          _blocks[blockIndex]['_temp_sentence'] =
                              ''; // Clear after split
                        });
                      },
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                      decoration: _inputDecoration(
                        hint: 'Ird ide a teljes mondatot...',
                        theme: theme,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final val = _blocks[blockIndex]['_temp_sentence'] ?? '';
                      if (val.trim().isEmpty) return;
                      _saveValidState();
                      final words = val.trim().split(RegExp(r'\s+'));
                      setState(() {
                        _blocks[blockIndex]['answers'] = words
                            .map((w) => {'text': w, 'points': 1})
                            .toList();
                        _blocks[blockIndex]['_temp_sentence'] =
                            ''; // Clear after split
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor.withOpacity(0.1),
                      foregroundColor: primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Bontás'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Words list
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: answers.length,
          onReorder: (oldIdx, newIdx) {
            _saveValidState();
            setState(() {
              if (newIdx > oldIdx) newIdx--;
              final item = answers.removeAt(oldIdx);
              answers.insert(newIdx, item);
              _blocks[blockIndex]['answers'] = answers;
            });
          },
          itemBuilder: (context, idx) {
            final answer = answers[idx];
            return Padding(
              key: ValueKey('sentence_${blockIndex}_$idx'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    if (answers.length > 1)
                      ReorderableDragStartListener(
                        index: idx,
                        child: Icon(
                          Icons.drag_indicator,
                          size: 20,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.4,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(
                          text: answer['text'] ?? '',
                        ),
                        onChanged: (val) {
                          _blocks[blockIndex]['answers'][idx]['text'] = val;
                        },
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Szó...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: TextField(
                        controller: TextEditingController(
                          text: (answer['points'] ?? 1).toString(),
                        ),
                        onChanged: (val) {
                          _blocks[blockIndex]['answers'][idx]['points'] =
                              int.tryParse(val) ?? 1;
                        },
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: 'pt',
                          hintStyle: TextStyle(
                            color: theme.hintColor,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: primaryColor.withOpacity(0.1),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    if (answers.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.redAccent,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36),
                        onPressed: () {
                          _saveValidState();
                          setState(() {
                            answers.removeAt(idx);
                            _blocks[blockIndex]['answers'] = answers;
                          });
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => _addSentenceWord(blockIndex),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Új szó hozzáadása'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchingAnswers(
    int blockIndex,
    List<Map<String, dynamic>> answers,
    ThemeData theme,
    Color primaryColor,
  ) {
    return Column(
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Fogalom',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 16, color: theme.hintColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Definíció',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(width: 40), // Space for delete button
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Pair rows
        ...answers.asMap().entries.map((entry) {
          final idx = entry.key;
          final answer = entry.value;
          final points = answer['points'] ?? 1;
          return Padding(
            key: ValueKey('matching_${blockIndex}_$idx'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: TextEditingController(
                      text: answer['text'] ?? '',
                    ),
                    onChanged: (val) {
                      _blocks[blockIndex]['answers'][idx]['text'] = val;
                    },
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 14,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Fogalom...',
                      theme: theme,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.compare_arrows, size: 18, color: primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: TextEditingController(
                      text: answer['match_text'] ?? '',
                    ),
                    onChanged: (val) {
                      _blocks[blockIndex]['answers'][idx]['match_text'] = val;
                    },
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 14,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Definíció...',
                      theme: theme,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Points field
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: TextEditingController(text: points.toString()),
                    onChanged: (val) {
                      _blocks[blockIndex]['answers'][idx]['points'] =
                          int.tryParse(val) ?? 1;
                    },
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'pt',
                      hintStyle: TextStyle(
                        color: theme.hintColor,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: primaryColor.withOpacity(0.1),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (answers.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () => _removeAnswer(blockIndex, idx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36),
                  ),
              ],
            ),
          );
        }),
        // Add pair button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => _addMatchingPair(blockIndex),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Pár hozzáadása'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _addMatchingPair(int blockIndex) {
    _saveValidState();
    setState(() {
      final answers = List<Map<String, dynamic>>.from(
        _blocks[blockIndex]['answers'] ?? [],
      );
      answers.add({'text': '', 'match_text': '', 'points': 1});
      _blocks[blockIndex]['answers'] = answers;
    });
  }

  Widget _buildOrderingAnswers(
    int blockIndex,
    List<Map<String, dynamic>> answers,
    ThemeData theme,
    Color primaryColor,
  ) {
    return Column(
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: answers.length,
          onReorder: (oldIdx, newIdx) {
            _saveValidState();
            setState(() {
              if (newIdx > oldIdx) newIdx--;
              final ans = List<Map<String, dynamic>>.from(
                _blocks[blockIndex]['answers'],
              );
              final item = ans.removeAt(oldIdx);
              ans.insert(newIdx, item);
              // Update order values
              for (int i = 0; i < ans.length; i++) {
                ans[i]['order'] = i;
              }
              _blocks[blockIndex]['answers'] = ans;
            });
          },
          itemBuilder: (context, idx) {
            final answer = answers[idx];
            return Padding(
              key: ValueKey('ordering_${blockIndex}_$idx'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  if (answers.length > 1)
                    ReorderableDragStartListener(
                      index: idx,
                      child: Icon(Icons.drag_indicator, color: theme.hintColor),
                    )
                  else
                    const SizedBox(width: 20),
                  const SizedBox(width: 8),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(
                        text: answer['text'] ?? '',
                      ),
                      onChanged: (val) {
                        _blocks[blockIndex]['answers'][idx]['text'] = val;
                      },
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 14,
                      ),
                      decoration: _inputDecoration(
                        hint: 'Elem szövege...',
                        theme: theme,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Points field
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: TextEditingController(
                        text: (answer['points'] ?? 1).toString(),
                      ),
                      onChanged: (val) {
                        _blocks[blockIndex]['answers'][idx]['points'] =
                            int.tryParse(val) ?? 1;
                      },
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'pt',
                        hintStyle: TextStyle(
                          color: theme.hintColor,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: primaryColor.withOpacity(0.1),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  if (answers.length > 2)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () => _removeAnswer(blockIndex, idx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36),
                    ),
                ],
              ),
            );
          },
        ),
        // Add element button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => _addOrderingElement(blockIndex),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Elem hozzáadása'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _addOrderingElement(int blockIndex) {
    _saveValidState();
    setState(() {
      final answers = List<Map<String, dynamic>>.from(
        _blocks[blockIndex]['answers'] ?? [],
      );
      answers.add({'text': '', 'order': answers.length, 'points': 1});
      _blocks[blockIndex]['answers'] = answers;
    });
  }

  // === GAP FILL UI ===
  bool _hasDuplicateGaps(String text) {
    final exp = RegExp(r'\{(\d+)\}');
    final matches = exp.allMatches(text);
    final seen = <String>{};
    for (final match in matches) {
      final gapId = match.group(1);
      if (gapId != null) {
        if (seen.contains(gapId)) return true;
        seen.add(gapId);
      }
    }
    return false;
  }

  Widget _buildGapFillAnswers(
    int blockIndex,
    Map<String, dynamic> block,
    ThemeData theme,
    Color primaryColor,
  ) {
    final gapText = block['gap_text'] ?? '';
    final answers = List<Map<String, dynamic>>.from(block['answers'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gap text editor
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Szöveg ({1}, {2}... jelölésekkel)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AnswerTextField(
                text: gapText,
                onChanged: (val) {
                  setState(() {
                    _blocks[blockIndex]['gap_text'] = val;
                    // Auto-generate answers for new gaps
                    final exp = RegExp(r'\{(\d+)\}');
                    final matches = exp.allMatches(val);
                    final currentAnswers =
                        _blocks[blockIndex]['answers'] as List? ?? [];
                    final existingIndices = currentAnswers
                        .map((a) => a['gap_index'] as int?)
                        .toSet();

                    for (final match in matches) {
                      final idxStr = match.group(1);
                      if (idxStr != null) {
                        final idx = int.tryParse(idxStr);
                        if (idx != null && !existingIndices.contains(idx)) {
                          currentAnswers.add({
                            'text': '',
                            'gap_index': idx,
                            'points':
                                _defaultCorrectPoints, // Use global default
                          });
                          existingIndices.add(idx);
                        }
                      }
                    }
                    _blocks[blockIndex]['answers'] = currentAnswers;
                  });
                },
                maxLines: 3,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration:
                    _inputDecoration(
                      hint: 'Pl: A víz {1} fokon forr...',
                      theme: theme,
                    ).copyWith(
                      focusedBorder: _hasDuplicateGaps(gapText)
                          ? OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Colors.orange,
                                width: 2,
                              ),
                            )
                          : null,
                    ),
              ),
              if (_hasDuplicateGaps(gapText))
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Figyelem: Néhány jelölés többször szerepel!',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Helyes válaszok',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Answer rows
        ...answers.asMap().entries.map((entry) {
          final idx = entry.key;
          final answer = entry.value;
          return Padding(
            key: ValueKey('gap_${blockIndex}_$idx'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final marker = '{${answer['gap_index'] ?? idx + 1}}';
                    if (gapText.contains(marker)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'A(z) $marker jelölés már szerepel a szövegben!',
                          ),
                          backgroundColor: Colors.orange.shade800,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          width: 280,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                      return;
                    }
                    _saveValidState();
                    setState(() {
                      _blocks[blockIndex]['gap_text'] = (gapText) + marker;
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '{${answer['gap_index'] ?? idx + 1}}',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(
                      text: answer['text'] ?? '',
                    ),
                    onChanged: (val) {
                      _blocks[blockIndex]['answers'][idx]['text'] = val;
                    },
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 14,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Helyes válasz...',
                      theme: theme,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: TextEditingController(
                      text: (answer['points'] ?? 1).toString(),
                    ),
                    onChanged: (val) {
                      _blocks[blockIndex]['answers'][idx]['points'] =
                          int.tryParse(val) ?? 1;
                    },
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'pt',
                      hintStyle: TextStyle(
                        color: theme.hintColor,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: primaryColor.withOpacity(0.1),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (answers.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () => _removeAnswer(blockIndex, idx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36),
                  ),
              ],
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => _addGapAnswer(blockIndex),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Új kitöltendő hely'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _addGapAnswer(int blockIndex) {
    _saveValidState();
    setState(() {
      final answers = List<Map<String, dynamic>>.from(
        _blocks[blockIndex]['answers'] ?? [],
      );
      // Find max gap index to avoid collision
      int maxIndex = 0;
      for (final a in answers) {
        final idx = a['gap_index'] as int? ?? 0;
        if (idx > maxIndex) maxIndex = idx;
      }
      answers.add({
        'gap_index': maxIndex + 1,
        'text': '',
        'points': _defaultCorrectPoints, // Use global default
      });
      _blocks[blockIndex]['answers'] = answers;
    });
  }

  // === RANGE UI ===
  Widget _buildRangeAnswers(
    int blockIndex,
    List<Map<String, dynamic>> answers,
    ThemeData theme,
    Color primaryColor,
  ) {
    final answer = answers.isNotEmpty
        ? answers[0]
        : {'correct_value': 0.0, 'tolerance': 0.0, 'points': 1};
    // Use num to support both int and double
    final num correctValue = (answer['correct_value'] as num?) ?? 0.0;
    final num tolerance = (answer['tolerance'] as num?) ?? 0.0;
    final points = answer['points'] ?? 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Helyes érték',
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                    const SizedBox(height: 4),
                    _AnswerTextField(
                      text: correctValue.toString(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      onChanged: (val) {
                        final newVal =
                            num.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                        setState(() {
                          if (answers.isEmpty) {
                            _blocks[blockIndex]['answers'] = [
                              {
                                'correct_value': newVal,
                                'tolerance': 0.0,
                                'points': 1,
                              },
                            ];
                          } else {
                            _blocks[blockIndex]['answers'][0]['correct_value'] =
                                newVal;
                          }
                        });
                      },
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: _inputDecoration(hint: '3.14', theme: theme),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tolerancia (±)',
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                    const SizedBox(height: 4),
                    _AnswerTextField(
                      text: tolerance.toString(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      onChanged: (val) {
                        final newVal =
                            num.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                        setState(() {
                          if (answers.isEmpty) {
                            _blocks[blockIndex]['answers'] = [
                              {
                                'correct_value': 0.0,
                                'tolerance': newVal,
                                'points': 1,
                              },
                            ];
                          } else {
                            _blocks[blockIndex]['answers'][0]['tolerance'] =
                                newVal;
                          }
                        });
                      },
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 16,
                      ),
                      decoration: _inputDecoration(hint: '0.1', theme: theme),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 70,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pont',
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: TextEditingController(
                        text: points.toString(),
                      ),
                      onChanged: (val) {
                        if (answers.isNotEmpty) {
                          _blocks[blockIndex]['answers'][0]['points'] =
                              int.tryParse(val) ?? 1;
                        }
                      },
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: primaryColor.withOpacity(0.1),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Elfogadott tartomány: ${(correctValue - tolerance).toStringAsFixed(1)} – ${(correctValue + tolerance).toStringAsFixed(1)}',
                    style: TextStyle(color: primaryColor, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === CATEGORY UI ===
  Widget _buildCategoryAnswers(
    int blockIndex,
    Map<String, dynamic> block,
    ThemeData theme,
    Color primaryColor,
  ) {
    final categories = List<Map<String, dynamic>>.from(
      block['categories'] ?? [],
    );
    final pointsPerItem = block['points_per_item'] ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Points per item setting
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Pont / helyes elem:',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: TextEditingController(
                    text: pointsPerItem.toString(),
                  ),
                  onChanged: (val) {
                    _blocks[blockIndex]['points_per_item'] =
                        int.tryParse(val) ?? 1;
                  },
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: primaryColor.withOpacity(0.1),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Categories
        ...categories.asMap().entries.map((catEntry) {
          final catIdx = catEntry.key;
          final category = catEntry.value;
          final items = List<String>.from(category['items'] ?? []);

          return Container(
            key: ValueKey('cat_${blockIndex}_$catIdx'),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(
                          text: category['name'] ?? '',
                        ),
                        onChanged: (val) {
                          _blocks[blockIndex]['categories'][catIdx]['name'] =
                              val;
                        },
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Kategória neve...',
                          hintStyle: TextStyle(color: theme.hintColor),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (categories.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _removeCategory(blockIndex, catIdx),
                      ),
                  ],
                ),
                const Divider(height: 16),
                // Items in category
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...items.asMap().entries.map((itemEntry) {
                      final itemIdx = itemEntry.key;
                      final itemText = itemEntry.value;
                      return Chip(
                        label: Text(itemText),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () =>
                            _removeCategoryItem(blockIndex, catIdx, itemIdx),
                        backgroundColor: primaryColor.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                // Add item row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(),
                        decoration: InputDecoration(
                          hintText: 'Új elem...',
                          hintStyle: TextStyle(
                            color: theme.hintColor,
                            fontSize: 13,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onSubmitted: (val) {
                          if (val.isNotEmpty) {
                            _addCategoryItem(blockIndex, catIdx, val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: () => _addCategory(blockIndex),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Kategória hozzáadása'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _addCategory(int blockIndex) {
    _saveValidState();
    setState(() {
      final categories = List<Map<String, dynamic>>.from(
        _blocks[blockIndex]['categories'] ?? [],
      );
      categories.add({
        'name': '',
        'items': [''],
      });
      _blocks[blockIndex]['categories'] = categories;
    });
  }

  void _removeCategory(int blockIndex, int catIdx) {
    _saveValidState();
    setState(() {
      final categories = List<Map<String, dynamic>>.from(
        _blocks[blockIndex]['categories'] ?? [],
      );
      if (categories.length > 1) {
        categories.removeAt(catIdx);
        _blocks[blockIndex]['categories'] = categories;
      }
    });
  }

  void _addCategoryItem(int blockIndex, int catIdx, String item) {
    _saveValidState();
    setState(() {
      final categories = List<Map<String, dynamic>>.from(
        _blocks[blockIndex]['categories'] ?? [],
      );
      final items = List<String>.from(categories[catIdx]['items'] ?? []);
      items.add(item);
      categories[catIdx]['items'] = items;
      _blocks[blockIndex]['categories'] = categories;
    });
  }

  void _removeCategoryItem(int blockIndex, int catIdx, int itemIdx) {
    _saveValidState();
    setState(() {
      final categories = List<Map<String, dynamic>>.from(
        _blocks[blockIndex]['categories'] ?? [],
      );
      final items = List<String>.from(categories[catIdx]['items'] ?? []);
      if (items.length > 1) {
        items.removeAt(itemIdx);
        categories[catIdx]['items'] = items;
        _blocks[blockIndex]['categories'] = categories;
      }
    });
  }

  void _removeQuestion(int index) {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();
    setState(() {
      _blocks.removeAt(index);
      for (int i = 0; i < _blocks.length; i++) {
        _blocks[i]['order'] = i;
      }
    });
  }

  void _addAnswer(int blockIndex) {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();
    setState(() {
      final answers = List<Map<String, dynamic>>.from(
        _blocks[blockIndex]['answers'] ?? [],
      );
      final blockType = _blocks[blockIndex]['type'] ?? 'single';
      answers.add({
        'text': '',
        'is_correct': blockType == 'text',
        'points': blockType == 'text' ? 1 : _defaultIncorrectPoints,
      });
      _blocks[blockIndex]['answers'] = answers;
    });
  }

  void _removeAnswer(int blockIndex, int answerIndex) {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();
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

  void _onReorderQuestions(int oldIndex, int newIndex) {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _blocks.removeAt(oldIndex);
      _blocks.insert(newIndex, item);
      for (int i = 0; i < _blocks.length; i++) {
        _blocks[i]['order'] = i;
      }
    });
  }

  void _onReorderAnswers(int blockIndex, int oldIndex, int newIndex) {
    _saveValidState();
    final themeProvider = ThemeInherited.of(context);
    themeProvider.triggerHaptic();
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final answers = List<Map<String, dynamic>>.from(
        _blocks[blockIndex]['answers'] ?? [],
      );
      final item = answers.removeAt(oldIndex);
      answers.insert(newIndex, item);
      _blocks[blockIndex]['answers'] = answers;
    });
  }

  // Regenerate distractors for math blocks
  void _updateMathBlock(Map<String, dynamic> block) {
    if (block['type'] != 'single') return;
    _saveValidState();

    final answers = block['answers'] as List;
    Map<String, dynamic>? correctAnswer;

    // Find the correct answer
    for (var a in answers) {
      if (a['is_correct'] == true) {
        correctAnswer = a;
        break;
      }
    }

    if (correctAnswer != null) {
      final correctVal = int.tryParse(correctAnswer['text'] ?? '');
      if (correctVal != null) {
        final random = Random();
        final generatedValues = <int>{correctVal};

        // Update incorrect answers
        for (var a in answers) {
          if (a['is_correct'] != true) {
            int newVal;
            int attempts = 0;
            do {
              int offset = random.nextInt(_mathDeviation.round()) + 1;
              if (random.nextBool()) offset = -offset;
              newVal = correctVal + offset;
              attempts++;
            } while (generatedValues.contains(newVal) && attempts < 10);

            generatedValues.add(newVal);
            a['text'] = newVal.toString();
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: LoadingAnimationWidget.newtonCradle(
                  color: primaryColor,
                  size: 80,
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  // Main scrollable content
                  SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16.0 : 40.0,
                      vertical: 40.0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _maxContentWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header like "Projektek" style
                            Text(
                              'Projekt szerkesztő',
                              style: TextStyle(
                                color: theme.textTheme.titleMedium?.color
                                    ?.withOpacity(0.8),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(height: 1, color: theme.dividerColor),
                            const SizedBox(height: 24),

                            // Project Name
                            _buildSectionWithDivider('Projekt neve', theme),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _nameController,
                              hint: 'Add meg a projekt nevét...',
                              theme: theme,
                            ),
                            const SizedBox(height: 24),

                            // Project Description
                            _buildSectionWithDivider('Projekt leírása', theme),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _descController,
                              hint: 'Add meg a projekt leírását...',
                              theme: theme,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 32),

                            // Questions Header
                            Text(
                              'Kérdések',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Questions List
                            if (_blocks.isEmpty)
                              _buildEmptyState(theme)
                            else
                              ReorderableListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                buildDefaultDragHandles: false,
                                itemCount: _blocks.length,
                                onReorder: _onReorderQuestions,
                                proxyDecorator: (child, index, animation) {
                                  return Material(
                                    color: Colors.transparent,
                                    elevation: 8,
                                    shadowColor: primaryColor.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(16),
                                    child: child,
                                  );
                                },
                                itemBuilder: (context, index) {
                                  return _buildQuestionCard(
                                    key: ValueKey(_blocks[index].hashCode),
                                    index: index,
                                    block: _blocks[index],
                                    theme: theme,
                                  );
                                },
                              ),

                            // Add Question Button (inline after questions)
                            const SizedBox(height: 16),
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: _addQuestion,
                                icon: const Icon(Icons.add, size: 20),
                                label: const Text('Új kérdés hozzáadása'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Scrim to close panels when clicking outside
                  if (_showOrderPanel ||
                      _showSettingsPanel ||
                      _showQuestionBankPanel ||
                      _showStatisticsPanel)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _showOrderPanel = false;
                            _showSettingsPanel = false;
                            _showQuestionBankPanel = false;
                            _showStatisticsPanel = false;
                          });
                        },
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                  // Unified Tools Speed Dial (Question Bank, Statistics, Settings, Order)
                  // Unified Tools Speed Dial (Question Bank, Statistics, Settings, Order)
                  Positioned(
                    right: isMobile ? 16 : 24,
                    bottom: isMobile ? 80 : 96, // Above the Save button row
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.end, // Aligns labels to the right
                      children: [
                        // Expandable buttons (Always visible on Desktop, collapsible on Mobile)
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: (!isMobile || _isToolsMenuOpen) ? 1.0 : 0.0,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 200),
                            scale: (!isMobile || _isToolsMenuOpen) ? 1.0 : 0.0,
                            alignment: Alignment.bottomCenter,
                            child: IgnorePointer(
                              ignoring: !(!isMobile || _isToolsMenuOpen),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Helper for side buttons with labels
                                  _buildSideMenuButton(
                                    icon: Icons.library_books,
                                    label: 'Kérdésbank',
                                    onTap: () {
                                      setState(() {
                                        _showQuestionBankPanel =
                                            !_showQuestionBankPanel;
                                        if (isMobile) _isToolsMenuOpen = false;
                                        if (_showQuestionBankPanel) {
                                          _showSettingsPanel = false;
                                          _showOrderPanel = false;
                                          _showStatisticsPanel = false;
                                        }
                                      });
                                    },
                                    theme: theme,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSideMenuButton(
                                    icon: Icons.analytics_outlined,
                                    label: 'Statisztika',
                                    onTap: () {
                                      setState(() {
                                        _showStatisticsPanel =
                                            !_showStatisticsPanel;
                                        if (isMobile) _isToolsMenuOpen = false;
                                        if (_showStatisticsPanel) {
                                          _showQuestionBankPanel = false;
                                          _showSettingsPanel = false;
                                          _showOrderPanel = false;
                                        }
                                      });
                                    },
                                    theme: theme,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSideMenuButton(
                                    icon: Icons.tune,
                                    label: 'Beállítások',
                                    onTap: () {
                                      setState(() {
                                        _showSettingsPanel =
                                            !_showSettingsPanel;
                                        if (isMobile) _isToolsMenuOpen = false;
                                        if (_showSettingsPanel) {
                                          _showQuestionBankPanel = false;
                                          _showOrderPanel = false;
                                          _showStatisticsPanel = false;
                                        }
                                      });
                                    },
                                    theme: theme,
                                  ),
                                  if (_blocks.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    _buildSideMenuButton(
                                      icon: Icons.reorder,
                                      label: 'Sorrend',
                                      onTap: () {
                                        setState(() {
                                          _showOrderPanel = !_showOrderPanel;
                                          if (isMobile)
                                            _isToolsMenuOpen = false;
                                          if (_showOrderPanel) {
                                            _showQuestionBankPanel = false;
                                            _showSettingsPanel = false;
                                            _showStatisticsPanel = false;
                                          }
                                        });
                                      },
                                      theme: theme,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Main toggle button (Only visible on Mobile)
                        if (isMobile) ...[
                          const SizedBox(
                            height: 16,
                          ), // Gap between menu and toggle
                          Material(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            elevation: 4,
                            child: InkWell(
                              onTap: () {
                                ThemeInherited.of(context).triggerHaptic();
                                setState(
                                  () => _isToolsMenuOpen = !_isToolsMenuOpen,
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 44, // Matches FAB size
                                height: 44,
                                alignment: Alignment.center,
                                child: AnimatedRotation(
                                  duration: const Duration(milliseconds: 200),
                                  turns: _isToolsMenuOpen ? 0.125 : 0,
                                  child: Icon(
                                    _isToolsMenuOpen
                                        ? Icons.close
                                        : Icons.build_outlined,
                                    color: theme.iconTheme.color,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Floating bottom buttons at screen edges
                  Positioned(
                    left: isMobile ? 16 : 24,
                    bottom: 24,
                    child: Tooltip(
                      message: 'Vissza',
                      child: InkWell(
                        onTap: () async {
                          if (_hasUnsavedChanges) {
                            final shouldLeave = await showDialog<bool>(
                              context: context,
                              builder: (context) => Dialog(
                                backgroundColor: Colors.transparent,
                                child: Container(
                                  width: 340,
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Orange header
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.orange.shade600,
                                              Colors.orange.shade400,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                            topRight: Radius.circular(20),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.warning_rounded,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Mentetlen változások',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Content
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Text(
                                          'Biztosan ki szeretnél lépni mentés nélkül? A módosításaid elvesznek.',
                                          style: TextStyle(
                                            color: theme
                                                .textTheme
                                                .bodyLarge
                                                ?.color,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      // Buttons
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          20,
                                          0,
                                          20,
                                          20,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: Text(
                                                'Mégse',
                                                style: TextStyle(
                                                  color: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.color,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.orange.shade600,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: const Text('Kilépés'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            if (shouldLeave == true && mounted) {
                              Navigator.of(context).pop();
                            }
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        customBorder: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Stack(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: primaryColor,
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
                            // Warning badge
                            if (_hasUnsavedChanges)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.scaffoldBackgroundColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.priority_high,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Save and Undo/Redo Buttons
                  Positioned(
                    right: isMobile ? 16 : 24,
                    bottom: 24,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Undo Button
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Material(
                            color: _undoStack.isNotEmpty
                                ? theme.cardColor
                                : theme.cardColor.withOpacity(0.5),
                            elevation: _undoStack.isNotEmpty ? 2 : 0,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: _undoStack.isNotEmpty ? _undo : null,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.undo,
                                  size: 20,
                                  color: _undoStack.isNotEmpty
                                      ? theme.iconTheme.color
                                      : theme.iconTheme.color?.withOpacity(0.3),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Redo Button
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Material(
                            color: _redoStack.isNotEmpty
                                ? theme.cardColor
                                : theme.cardColor.withOpacity(0.5),
                            elevation: _redoStack.isNotEmpty ? 2 : 0,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: _redoStack.isNotEmpty ? _redo : null,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.redo,
                                  size: 20,
                                  color: _redoStack.isNotEmpty
                                      ? theme.iconTheme.color
                                      : theme.iconTheme.color?.withOpacity(0.3),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Main Save Button
                        Material(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(12),
                          elevation: 0,
                          child: InkWell(
                            onTap: _isSaving ? null : _saveProject,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: isMobile ? 44 : 56,
                              width: isMobile ? 44 : null,
                              padding: isMobile
                                  ? null
                                  : const EdgeInsets.symmetric(horizontal: 24),
                              alignment: Alignment.center,
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : isMobile
                                  ? const Icon(
                                      Icons.save,
                                      color: Colors.white,
                                      size: 22,
                                    )
                                  : Row(
                                      children: const [
                                        Icon(
                                          Icons.save,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Mentés',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Floating question order editor and toggle button

                  // Settings Panel (Side Panel)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    top: 0,
                    bottom: 0,
                    right: _showSettingsPanel
                        ? 0
                        : -(isMobile
                              ? MediaQuery.of(context).size.width * 0.85
                              : 380.0),
                    width: isMobile
                        ? MediaQuery.of(context).size.width * 0.85
                        : 380.0,
                    child: _buildSettingsPanel(theme),
                  ),

                  // Statistics Panel (Side Panel)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    top: 0,
                    bottom: 0,
                    right: _showStatisticsPanel
                        ? 0
                        : -(isMobile
                              ? MediaQuery.of(context).size.width * 0.85
                              : 380.0),
                    width: isMobile
                        ? MediaQuery.of(context).size.width * 0.85
                        : 380.0,
                    child: _buildStatisticsPanel(theme, isMobile),
                  ),

                  // Order Panel (Side Panel)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    top: 0,
                    bottom: 0,
                    right: _showOrderPanel
                        ? 0
                        : -(isMobile
                              ? MediaQuery.of(context).size.width * 0.85
                              : 380.0),
                    width: isMobile
                        ? MediaQuery.of(context).size.width * 0.85
                        : 380.0,
                    child: _buildOrderPanel(theme),
                  ),
                  // Question Bank Panel (Overlay)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    top: 0,
                    bottom: 0,
                    right: _showQuestionBankPanel
                        ? 0
                        : -(isMobile
                              ? MediaQuery.of(context).size.width * 0.85
                              : 380.0),
                    width: isMobile
                        ? MediaQuery.of(context).size.width * 0.85
                        : 380.0,
                    child: _buildQuestionBankPanel(theme, isMobile),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 56,
              color: theme.primaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Még nincsenek kérdések',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adj hozzá az első kérdésedet!',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionWithDivider(String text, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.titleMedium?.color?.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: theme.dividerColor),
      ],
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
          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
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

  Widget _buildQuestionCard({
    required Key key,
    required int index,
    required Map<String, dynamic> block,
    required ThemeData theme,
  }) {
    final rawType = block['type'] ?? 'single';
    final primaryColor = theme.primaryColor;

    // Handle text_block type - simple text display card
    if (rawType == 'text_block') {
      return Container(
        key: key,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
              ),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(Icons.drag_indicator, color: theme.hintColor),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.notes, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Szöveg blokk',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red.shade400,
                    onPressed: () => _removeQuestion(index),
                  ),
                ],
              ),
            ),
            // Content TextField
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: TextEditingController(text: block['content'] ?? '')
                  ..selection = TextSelection.fromPosition(
                    TextPosition(offset: (block['content'] ?? '').length),
                  ),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Írj ide szöveget, magyarázatot...',
                  hintStyle: TextStyle(color: theme.hintColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                ),
                onChanged: (val) {
                  setState(() {
                    block['content'] = val;
                  });
                },
              ),
            ),
          ],
        ),
      );
    }

    // Handle divider type - horizontal line with optional text
    if (rawType == 'divider') {
      return Container(
        key: key,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_indicator, color: theme.hintColor),
              ),
              const SizedBox(width: 8),
              Icon(Icons.horizontal_rule, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Elválasztó',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodySmall?.color,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(height: 1, color: theme.dividerColor),
                    ),
                    if ((block['content'] ?? '').isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          block['content'],
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(height: 1, color: theme.dividerColor),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Edit label button
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                color: theme.hintColor,
                onPressed: () async {
                  final controller = TextEditingController(
                    text: block['content'] ?? '',
                  );
                  final result = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Elválasztó felirat'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'pl. 1. Rész (üresen hagyható)',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Mégse'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, controller.text),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      block['content'] = result;
                    });
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Colors.red.shade400,
                onPressed: () => _removeQuestion(index),
              ),
            ],
          ),
        ),
      );
    }

    final answers = List<Map<String, dynamic>>.from(block['answers'] ?? []);
    // Ensure selectedType is a valid option, otherwise default to 'single'
    final selectedType = _questionTypes.contains(rawType) ? rawType : 'single';

    // Check validation status
    final errors = _validateBlock(block);
    final hasErrors = errors.isNotEmpty;
    final effectiveColor = hasErrors ? Colors.amber : primaryColor;

    return Stack(
      key: key,
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [effectiveColor, effectiveColor.withOpacity(0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Header with drag handle
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_indicator,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Kérdés',
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Inline Validation Badge
                      (() {
                        final bErrors = _validateBlock(block);
                        if (bErrors.isEmpty) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 12,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Hibás kitöltés',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      })(),
                      const Spacer(),
                    ],
                  ),
                ),

                // Type Dropdown
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedType,
                        isExpanded: true,
                        dropdownColor: theme.cardColor,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: 14,
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
                              // If changing to 'text', ensure all answers are marked as correct
                              if (value == 'text') {
                                if (_blocks[index]['answers'] != null) {
                                  for (var a in _blocks[index]['answers']) {
                                    a['is_correct'] = true;
                                    if (a['points'] == 0) a['points'] = 1;
                                  }
                                }
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Delete Question Button

                // Question Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: TextEditingController(
                      text: block['question'] ?? '',
                    ),
                    onChanged: (val) => _blocks[index]['question'] = val,
                    maxLines: 2,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: _inputDecoration(
                      hint: 'Írd ide a kérdést...',
                      theme: theme,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Subtext
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: TextEditingController(
                      text: block['subtext'] ?? '',
                    ),
                    onChanged: (val) => _blocks[index]['subtext'] = val,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 13,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Opcionális segédszöveg...',
                      theme: theme,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Image URL
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: TextEditingController(
                      text: block['image_url'] ?? '',
                    ),
                    onChanged: (val) => _blocks[index]['image_url'] = val,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 13,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Opcionális kép URL...',
                      theme: theme,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Link URL
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: TextEditingController(
                      text: block['link_url'] ?? '',
                    ),
                    onChanged: (val) => _blocks[index]['link_url'] = val,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 13,
                    ),
                    decoration: _inputDecoration(
                      hint: 'Opcionális link URL...',
                      theme: theme,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Answers Section - varies by type
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    selectedType == 'text'
                        ? 'Helyes válaszok'
                        : selectedType == 'matching'
                        ? 'Párok (bal → jobb)'
                        : selectedType == 'ordering'
                        ? 'Elemek (helyes sorrendben)'
                        : selectedType == 'gap_fill'
                        ? 'Kitöltendő szöveg'
                        : selectedType == 'range'
                        ? 'Elfogadott érték'
                        : selectedType == 'category'
                        ? 'Kategóriák'
                        : selectedType == 'sentence_ordering'
                        ? 'Mondat szavai'
                        : 'Válaszok',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Type-specific answer editors
                if (selectedType == 'matching')
                  _buildMatchingAnswers(index, answers, theme, primaryColor)
                else if (selectedType == 'ordering')
                  _buildOrderingAnswers(index, answers, theme, primaryColor)
                else if (selectedType == 'gap_fill')
                  _buildGapFillAnswers(index, block, theme, primaryColor)
                else if (selectedType == 'range')
                  _buildRangeAnswers(index, answers, theme, primaryColor)
                else if (selectedType == 'category')
                  _buildCategoryAnswers(index, block, theme, primaryColor)
                else if (selectedType == 'sentence_ordering')
                  _buildSentenceOrderingAnswers(
                    index,
                    answers,
                    theme,
                    primaryColor,
                  )
                else
                  // Standard answers list with reordering
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: answers.length,
                    onReorder: (oldIdx, newIdx) =>
                        _onReorderAnswers(index, oldIdx, newIdx),
                    itemBuilder: (context, ansIndex) {
                      return _buildAnswerRow(
                        key: ValueKey(
                          '${index}_${ansIndex}_${answers[ansIndex].hashCode}',
                        ),
                        blockIndex: index,
                        answerIndex: ansIndex,
                        answer: answers[ansIndex],
                        theme: theme,
                        isTextType: selectedType == 'text',
                      );
                    },
                  ),

                // Add Answer Button (only for standard types)
                if (![
                  'matching',
                  'ordering',
                  'gap_fill',
                  'range',
                  'category',
                  'sentence_ordering',
                ].contains(selectedType))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: ElevatedButton.icon(
                      onPressed: () => _addAnswer(index),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        selectedType == 'text'
                            ? 'Helyes válasz hozzáadása'
                            : 'Válasz hozzáadása',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                // Delete Question Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: TextButton.icon(
                    onPressed: () => _removeQuestion(index),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Kérdés törlése'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: -42,
          top: 12,
          child: Text(
            '#${index + 1}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: effectiveColor.withOpacity(0.8),
              letterSpacing: -1,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required ThemeData theme,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
        fontSize: 14,
      ),
      filled: true,
      fillColor: theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildAnswerRow({
    required Key key,
    required int blockIndex,
    required int answerIndex,
    required Map<String, dynamic> answer,
    required ThemeData theme,
    bool isTextType = false,
  }) {
    final isCorrect = answer['is_correct'] ?? false;
    final points = answer['points'] ?? 0;

    // Determine if we should show the math refresh icon
    bool showMathRefresh = false;
    if (_editorMode == 'math' &&
        _blocks[blockIndex]['type'] == 'single' &&
        !isCorrect) {
      final blockAnswers = _blocks[blockIndex]['answers'] as List;
      for (var a in blockAnswers) {
        if (a['is_correct'] == true) {
          if (int.tryParse(a['text'] ?? '') != null) {
            showMathRefresh = true;
          }
          break;
        }
      }
    }

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Drag handle for answer
          if (_blocks[blockIndex]['answers'].length > 1)
            ReorderableDragStartListener(
              index: answerIndex,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.drag_indicator,
                  size: 20,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
                ),
              ),
            )
          else
            const SizedBox(width: 28),

          // Answer text field
          Expanded(
            child: _AnswerTextField(
              text: answer['text'] ?? '',
              onChanged: (val) {
                setState(() {
                  _blocks[blockIndex]['answers'][answerIndex]['text'] = val;
                });
              },
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: isTextType
                    ? 'Elfogadott válasz...'
                    : 'Válasz szövege...',
                suffixIcon: showMathRefresh
                    ? IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Random szám generálása',
                        onPressed: () {
                          // Find correct answer in this block
                          final blockAnswers =
                              _blocks[blockIndex]['answers'] as List;
                          Map<String, dynamic>? correctAnswer;
                          for (var a in blockAnswers) {
                            if (a['is_correct'] == true) {
                              correctAnswer = a;
                              break;
                            }
                          }

                          if (correctAnswer != null) {
                            final correctVal = int.tryParse(
                              correctAnswer['text'] ?? '',
                            );
                            if (correctVal != null) {
                              // Generate random non-colliding number
                              int newVal;
                              int attempts = 0;
                              final random = Random();
                              do {
                                int offset =
                                    random.nextInt(_mathDeviation.round()) + 1;
                                if (random.nextBool()) offset = -offset;
                                newVal = correctVal + offset;
                                attempts++;
                              } while (newVal == correctVal && attempts < 10);

                              setState(() {
                                _blocks[blockIndex]['answers'][answerIndex]['text'] =
                                    newVal.toString();
                              });
                            }
                          }
                        },
                      )
                    : null,
                hintStyle: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
                ),
                filled: true,
                fillColor: theme.cardColor,
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

          // Points field
          SizedBox(
            width: 50,
            child: TextField(
              controller: TextEditingController(text: points.toString()),
              onChanged: (val) {
                _blocks[blockIndex]['answers'][answerIndex]['points'] =
                    int.tryParse(val) ?? 0;
              },
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*')),
              ],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'Pt',
                hintStyle: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
                  fontSize: 12,
                ),
                filled: true,
                fillColor: theme.primaryColor.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Correct checkbox with label
          if (!isTextType)
            Column(
              children: [
                Checkbox(
                  value: isCorrect,
                  onChanged: (val) {
                    setState(() {
                      bool isSingle = _blocks[blockIndex]['type'] == 'single';
                      if (isSingle && val == true) {
                        for (var a in _blocks[blockIndex]['answers']) {
                          a['is_correct'] = false;
                          a['points'] = _defaultIncorrectPoints;
                        }
                      }

                      _blocks[blockIndex]['answers'][answerIndex]['is_correct'] =
                          val ?? false;
                      if (val == true &&
                          (_blocks[blockIndex]['answers'][answerIndex]['points'] ==
                              _defaultIncorrectPoints)) {
                        _blocks[blockIndex]['answers'][answerIndex]['points'] =
                            _defaultCorrectPoints;
                      } else if (val == false) {
                        _blocks[blockIndex]['answers'][answerIndex]['points'] =
                            _defaultIncorrectPoints;
                      }
                    });
                  },
                  activeColor: Colors.green,
                  side: BorderSide(color: theme.dividerColor),
                ),
                Text(
                  'Helyes',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),

          // Delete button
          if (_blocks[blockIndex]['answers'].length > (isTextType ? 1 : 2))
            ElevatedButton(
              onPressed: () => _removeAnswer(blockIndex, answerIndex),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.redAccent,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: const Size(40, 48), // Match input height
                fixedSize: const Size(40, 48), // Force square-ish shape
              ),
              child: const Icon(Icons.delete_outline, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionBankPanel(ThemeData theme, bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = (screenWidth > 500) ? 380.0 : screenWidth * 0.85;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: 0,
      bottom: 0,
      right: _showQuestionBankPanel ? 0 : -panelWidth,
      width: panelWidth,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            bottomLeft: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                theme.brightness == Brightness.dark ? 0.5 : 0.1,
              ),
              blurRadius: 15,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor, width: 1),
                ),
                color: theme.cardColor, // Ensure header matches background
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.library_books,
                    size: 24,
                    color: theme.iconTheme.color,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Kérdésbank',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        setState(() => _showQuestionBankPanel = false),
                    icon: Icon(
                      Icons.close,
                      color: theme.iconTheme.color?.withOpacity(0.7),
                    ),
                    tooltip: 'Bezárás',
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _bankSearchController,
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                decoration: InputDecoration(
                  hintText: 'Keresés...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.iconTheme.color?.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  isDense: true,
                ),
                onChanged: _onBankSearchChanged,
              ),
            ),

            // Content List
            Expanded(
              child: _isBankSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _bankSearchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: theme.disabledColor.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _bankSearchController.text.isEmpty
                                ? 'Írj be egy kifejezést a kereséshez'
                                : 'Nincs találat.',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _bankSearchResults.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _bankSearchResults[index];
                        final question = item['question'] ?? 'Névtelen kérdés';
                        final type = item['type'] ?? 'unknown';
                        final answersCount =
                            (item['answers'] as List?)?.length ?? 0;

                        return Material(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => _addQuestionFromBank(item),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      type == 'single'
                                          ? Icons.radio_button_checked
                                          : type == 'multiple'
                                          ? Icons.check_box
                                          : Icons.text_fields,
                                      size: 20,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          question,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: theme
                                                .textTheme
                                                .bodyLarge
                                                ?.color,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$answersCount válaszlehetőség',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme
                                                .textTheme
                                                .bodyMedium
                                                ?.color
                                                ?.withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.add_circle_outline,
                                    size: 24,
                                    color: theme.primaryColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPanel(ThemeData theme) {
    return Container(
      key: const ValueKey('SettingsPanel'),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.5 : 0.1,
            ),
            blurRadius: 15,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 1),
              ),
              color: theme.cardColor,
            ),
            child: Row(
              children: [
                Icon(Icons.tune, size: 24, color: theme.iconTheme.color),
                const SizedBox(width: 12),
                Text(
                  'Beállítások',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _showSettingsPanel = false),
                  icon: Icon(
                    Icons.close,
                    color: theme.iconTheme.color?.withOpacity(0.7),
                  ),
                  tooltip: 'Bezárás',
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Standard Settings
                  Row(
                    children: [
                      Expanded(
                        child: _buildSettingsInput(
                          label: 'Helyes válasz',
                          value: _defaultCorrectPoints,
                          onChanged: (val) =>
                              setState(() => _defaultCorrectPoints = val),
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSettingsInput(
                          label: 'Helytelen válasz',
                          value: _defaultIncorrectPoints,
                          onChanged: (val) =>
                              setState(() => _defaultIncorrectPoints = val),
                          theme: theme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _applySettingsToAll,
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Alkalmazás mindenkire'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: theme.dividerColor),
                  const SizedBox(height: 16),
                  // Math Mode
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calculate,
                                  color: theme.primaryColor,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Matematika mód',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _editorMode == 'math',
                              onChanged: (val) {
                                setState(() {
                                  _editorMode = val ? 'math' : 'standard';
                                  if (_editorMode == 'math' &&
                                      _blocks.isNotEmpty) {
                                    for (var block in _blocks)
                                      _updateMathBlock(block);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        if (_editorMode == 'math') ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Automatikus válaszgenerálás matematikai kifejezésekhez.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_editorMode == 'math') ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Generált számok eltérése',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${_mathDeviation.round()}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 16,
                              ),
                              activeTrackColor: theme.primaryColor,
                              inactiveTrackColor: theme.primaryColor
                                  .withOpacity(0.2),
                            ),
                            child: Slider(
                              value: _mathDeviation,
                              min: 1,
                              max: 50,
                              divisions: 49,
                              label: _mathDeviation.round().toString(),
                              onChanged: (val) =>
                                  setState(() => _mathDeviation = val),
                            ),
                          ),
                        ),
                        const Text('50'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Divider(color: theme.dividerColor),
                  const SizedBox(height: 24),

                  // Project Actions
                  Text(
                    'PROJEKT MŰVELETEK',
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.6,
                      ),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _showSettingsPanel = false);
                        _exportProject();
                      },
                      icon: const Icon(Icons.download, size: 20),
                      label: const Text('Projekt Exportálása'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Danger Zone
                  const SizedBox(height: 32),
                  Text(
                    'VESZÉLYES ZÓNA',
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.6,
                      ),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _confirmDeleteProject,
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text('Projekt Törlése'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderPanel(ThemeData theme) {
    return Container(
      key: const ValueKey('OrderPanel'),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.5 : 0.1,
            ),
            blurRadius: 15,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 1),
              ),
              color: theme.cardColor,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.format_list_numbered,
                  size: 24,
                  color: theme.iconTheme.color,
                ),
                const SizedBox(width: 12),
                Text(
                  'Sorrend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _showOrderPanel = false),
                  icon: Icon(
                    Icons.close,
                    color: theme.iconTheme.color?.withOpacity(0.7),
                  ),
                  tooltip: 'Bezárás',
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _blocks.isEmpty
                ? Center(
                    child: Text(
                      'Még nincsenek kérdések',
                      style: TextStyle(color: theme.disabledColor),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    buildDefaultDragHandles: false,
                    itemCount: _blocks.length,
                    onReorder: _onReorderQuestions,
                    itemBuilder: (context, index) {
                      final question = _blocks[index]['question'] ?? '';
                      final displayText = question.isEmpty
                          ? 'Névtelen kérdés'
                          : question;
                      return Container(
                        key: ValueKey('order_$index'),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.5),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                          title: Text(
                            displayText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: Icon(
                              Icons.drag_indicator,
                              color: theme.disabledColor,
                            ),
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

  Widget _buildStatisticsPanel(ThemeData theme, bool isMobile) {
    // 1. Calculate Metrics
    int totalPoints = 0;
    int deductiblePoints = 0;
    int questionCount = _blocks.length;
    int wordCount = 0;
    // totalQuestionLength removed (unused)
    int maxQuestionLength = 0;
    int emptyFields = 0;
    Map<String, int> typeDistribution = {};
    Set<String> uniqueQuestions = {};
    int duplicateCount = 0;
    int validBlocks = 0;

    for (var block in _blocks) {
      // Points
      final type = block['type'] ?? 'single';
      final question = (block['question'] ?? '').toString();

      if (question.trim().isNotEmpty) {
        if (uniqueQuestions.contains(question)) {
          duplicateCount++;
        } else {
          uniqueQuestions.add(question);
        }
      } else {
        emptyFields++;
      }

      // Word count
      wordCount += question.split(RegExp(r'\s+')).length;
      if (question.length > maxQuestionLength) {
        maxQuestionLength = question.length;
      }

      // Type Distribution
      typeDistribution[type] = (typeDistribution[type] ?? 0) + 1;

      // Validity
      if (_validateBlock(block).isEmpty) validBlocks++;

      // Points calculation based on type
      if (['single', 'multiple', 'ordering'].contains(type)) {
        final answers = block['answers'] as List? ?? [];
        for (var ans in answers) {
          final points = (ans['points'] as num? ?? 0).toInt();
          if (ans['is_correct'] == true || type == 'ordering') {
            totalPoints += points;
          } else {
            deductiblePoints += points.abs();
          }
          if ((ans['text'] ?? '').trim().isEmpty) emptyFields++;
        }
      } else if (type == 'matching') {
        final answers = block['answers'] as List? ?? [];
        for (var ans in answers) {
          final points = (ans['points'] as num? ?? 0).toInt();
          totalPoints += points;
          if ((ans['text'] ?? '').trim().isEmpty) emptyFields++;
          if ((ans['match_text'] ?? '').trim().isEmpty) emptyFields++;
        }
      } else if (type == 'sentence_ordering') {
        final answers = block['answers'] as List? ?? [];
        totalPoints +=
            answers.length; // Assuming 1 point per word/position roughly
      } else if (type == 'gap_fill') {
        final answers = block['answers'] as List? ?? [];
        for (var ans in answers) {
          final points = (ans['points'] as num? ?? 0).toInt();
          totalPoints += points;
        }
      } else if (type == 'category') {
        final categories = block['categories'] as List? ?? [];
        final pointsPerItem = (block['points_per_item'] as num? ?? 1).toInt();
        for (var cat in categories) {
          final items = cat['items'] as List? ?? [];
          totalPoints += items.length * pointsPerItem;
        }
      } else if (type == 'range') {
        final answers = block['answers'] as List? ?? [];
        if (answers.isNotEmpty) {
          totalPoints += (answers[0]['points'] as num? ?? 1).toInt();
        }
      } else if (type == 'text') {
        final answers = block['answers'] as List? ?? [];
        int maxP = 0;
        for (var ans in answers) {
          final p = (ans['points'] as num? ?? 0).toInt();
          if (p > maxP) maxP = p;
        }
        totalPoints += maxP;
      }
    }

    // Difficulty Heuristic (0-100)
    // Based on length, complex types, and sheer volume
    double difficultyScore = 0;
    difficultyScore += questionCount * 2; // Volume
    difficultyScore +=
        (wordCount / questionCount.clamp(1, 999)) * 0.5; // Verbosity
    if (typeDistribution['gap_fill'] != null)
      difficultyScore += typeDistribution['gap_fill']! * 5;
    if (typeDistribution['matching'] != null)
      difficultyScore += typeDistribution['matching']! * 4;
    difficultyScore = difficultyScore.clamp(0.0, 100.0);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.5 : 0.1,
            ),
            blurRadius: 15,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 1),
              ),
              color: theme.cardColor,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 24,
                  color: theme.iconTheme.color,
                ),
                const SizedBox(width: 12),
                Text(
                  'Statisztika',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _showStatisticsPanel = false),
                  icon: Icon(
                    Icons.close,
                    color: theme.iconTheme.color?.withOpacity(0.7),
                  ),
                  tooltip: 'Bezárás',
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Score Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        theme,
                        'Összpont',
                        totalPoints.toString(),
                        Icons.stars,
                        Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        theme,
                        'Levonás',
                        '-$deductiblePoints',
                        Icons.remove_circle_outline,
                        Colors.redAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Validation & Health
                Text(
                  'Projekt Egészség',
                  style: TextStyle(
                    color: theme.hintColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                _buildHealthBar(theme, validBlocks, questionCount),
                const SizedBox(height: 16),
                _buildStatRow(
                  theme,
                  'Érvényes kérdések',
                  '$validBlocks / $questionCount',
                ),
                _buildStatRow(
                  theme,
                  'Üres mezők',
                  '$emptyFields db',
                  isWarning: emptyFields > 0,
                ),
                _buildStatRow(
                  theme,
                  'Ismétlődő kérdés',
                  '$duplicateCount db',
                  isWarning: duplicateCount > 0,
                ),

                const Divider(height: 32),

                // Complexity
                Text(
                  'Komplexitás',
                  style: TextStyle(
                    color: theme.hintColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDifficultyMeter(theme, difficultyScore),
                const SizedBox(height: 16),
                _buildStatRow(theme, 'Szószám', '$wordCount'),
                _buildStatRow(
                  theme,
                  'Max. kérdéshossz',
                  '$maxQuestionLength kar.',
                ),

                const Divider(height: 32),

                // Distribution
                Text(
                  'Típusok megoszlása',
                  style: TextStyle(
                    color: theme.hintColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                ...typeDistribution.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _buildDistributionRow(
                      theme,
                      e.key,
                      e.value,
                      questionCount,
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

  Widget _buildStatCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          Text(title, style: TextStyle(fontSize: 12, color: theme.hintColor)),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    ThemeData theme,
    String label,
    String value, {
    bool isWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isWarning
                  ? Colors.redAccent
                  : theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBar(ThemeData theme, int valid, int total) {
    double progress = total == 0 ? 0 : valid / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: theme.dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0
                  ? Colors.green
                  : (progress > 0.5 ? Colors.orange : Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyMeter(ThemeData theme, double score) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nehézségi szint',
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            Text(
              '${score.toInt()}/100',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 8,
            backgroundColor: theme.dividerColor,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionRow(
    ThemeData theme,
    String typeKey,
    int count,
    int total,
  ) {
    // Map internal types to readable names
    final names = {
      'single': 'Feleletválasztós',
      'multiple': 'Többszörös választás',
      'text': 'Szöveges',
      'matching': 'Párosítás',
      'ordering': 'Sorrend',
      'gap_fill': 'Hiányos szöveg',
      'range': 'Intervallum',
      'sentence_ordering': 'Mondatrendezés',
    };

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            names[typeKey] ?? typeKey,
            style: TextStyle(
              fontSize: 13,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: count / total,
                    minHeight: 6,
                    backgroundColor: theme.dividerColor.withOpacity(0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count db',
                style: TextStyle(fontSize: 12, color: theme.hintColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSideMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          elevation: 2,
          child: InkWell(
            onTap: () {
              ThemeInherited.of(context).triggerHaptic();
              onTap();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Icon(icon, color: theme.iconTheme.color, size: 22),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnswerTextField extends StatefulWidget {
  final String text;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final TextStyle? style;
  final int maxLines;
  final TextInputType? keyboardType;

  const _AnswerTextField({
    Key? key,
    required this.text,
    required this.onChanged,
    required this.decoration,
    this.style,
    this.maxLines = 1,
    this.keyboardType,
  }) : super(key: key);

  @override
  _AnswerTextFieldState createState() => _AnswerTextFieldState();
}

class _AnswerTextFieldState extends State<_AnswerTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(covariant _AnswerTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _controller.text) {
      _controller.text = widget.text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: widget.decoration,
      style: widget.style,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
    );
  }
}
