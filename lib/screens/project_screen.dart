import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import '../models/project.dart';
import '../services/storage_service.dart';

class ProjectScreen extends StatefulWidget {
  final Project project;

  const ProjectScreen({super.key, required this.project});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final StorageService _storage = StorageService();
  int _currentTab = 0; // 0 = EDITOR, 1 = PROJECT

  // Open files for the EDITOR tab
  final List<String> _openFiles = [];
  String? _activeFilePath;
  final Map<String, TextEditingController> _controllers = {};

  // Current directory being viewed in PROJECT tab
  late String _currentDir;

  List<FileSystemEntity> _entities = [];
  bool _loadingFiles = false;

  @override
  void initState() {
    super.initState();
    _currentDir = widget.project.path;
    _loadDirectory();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDirectory() async {
    setState(() => _loadingFiles = true);
    final list = await _storage.listDirectory(_currentDir);
    setState(() {
      _entities = list;
      _loadingFiles = false;
    });
  }

  void _openFile(String path) async {
    if (!_openFiles.contains(path)) {
      final content = await _storage.readFile(path) ?? '';
      _controllers[path] = TextEditingController(text: content);
      setState(() {
        _openFiles.add(path);
        _activeFilePath = path;
        _currentTab = 0; // switch to EDITOR
      });
    } else {
      setState(() {
        _activeFilePath = path;
        _currentTab = 0;
      });
    }
  }

  Future<void> _saveCurrentFile() async {
    if (_activeFilePath == null) return;
    final controller = _controllers[_activeFilePath!];
    if (controller == null) return;

    final success = await _storage.writeFile(_activeFilePath!, controller.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Saved successfully' : 'Failed to save'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _leaveProject() {
    Navigator.pop(context);
  }

  void _runProject() {
    // Simple run feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.project.type == ProjectType.website
              ? 'Run: Opening website preview (coming soon)'
              : 'Run: Executing application (coming soon)',
        ),
      ),
    );
  }

  Future<void> _createFile() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('New File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'File name (e.g. style.css)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final ok = await _storage.createFile(_currentDir, result);
      if (ok) {
        await _loadDirectory();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File already exists or failed')),
        );
      }
    }
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final ok = await _storage.createFolder(_currentDir, result);
      if (ok) {
        await _loadDirectory();
      }
    }
  }

  Future<void> _deleteEntity(FileSystemEntity entity) async {
    final name = p.basename(entity.path);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete?'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await _storage.deleteEntity(entity.path);
      if (ok) {
        // Also close if it was open in editor
        if (_openFiles.contains(entity.path)) {
          _controllers[entity.path]?.dispose();
          _controllers.remove(entity.path);
          _openFiles.remove(entity.path);
          if (_activeFilePath == entity.path) {
            _activeFilePath = _openFiles.isNotEmpty ? _openFiles.last : null;
          }
        }
        await _loadDirectory();
      }
    }
  }

  Future<void> _importFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['html', 'css', 'js', 'dart', 'json', 'txt', 'md', 'png', 'jpg', 'jpeg', 'gif', 'webp', 'mp4', 'mov', 'webm'],
    );

    if (result != null) {
      for (final file in result.files) {
        if (file.path != null) {
          await _storage.importFile(_currentDir, file.path!);
        }
      }
      await _loadDirectory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${result.files.length} file(s)')),
        );
      }
    }
  }

  // ---------- UI Builders ----------

  Widget _buildEditorTab() {
    if (_openFiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit_note, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('No files open', style: TextStyle(color: Colors.grey, fontSize: 16)),
            SizedBox(height: 4),
            Text('Go to PROJECT tab and open a file', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Open file tabs
        SizedBox(
          height: 42,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _openFiles.length,
            itemBuilder: (context, index) {
              final path = _openFiles[index];
              final isActive = path == _activeFilePath;
              return GestureDetector(
                onTap: () => setState(() => _activeFilePath = path),
                child: Container(
                  margin: const EdgeInsets.only(right: 4, top: 4, bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF2D2D2D) : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isActive ? Colors.blueAccent : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        p.basename(path),
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _controllers[path]?.dispose();
                            _controllers.remove(path);
                            _openFiles.remove(path);
                            if (_activeFilePath == path) {
                              _activeFilePath = _openFiles.isNotEmpty ? _openFiles.last : null;
                            }
                          });
                        },
                        child: const Icon(Icons.close, size: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        // Code editor
        Expanded(
          child: _activeFilePath == null
              ? const SizedBox()
              : TextField(
                  controller: _controllers[_activeFilePath!],
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                    filled: true,
                    fillColor: Color(0xFF0D0D0D),
                  ),
                  keyboardType: TextInputType.multiline,
                ),
        ),
      ],
    );
  }

  Widget _buildProjectTab() {
    final isRoot = _currentDir == widget.project.path;

    return Column(
      children: [
        // Path bar + actions
        Container(
          color: const Color(0xFF1A1A1A),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              if (!isRoot)
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  onPressed: () {
                    setState(() {
                      _currentDir = p.dirname(_currentDir);
                    });
                    _loadDirectory();
                  },
                  tooltip: 'Go up',
                ),
              Expanded(
                child: Text(
                  p.relative(_currentDir, from: widget.project.path).isEmpty
                      ? '/'
                      : p.relative(_currentDir, from: widget.project.path),
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.create_new_folder, size: 22),
                onPressed: _createFolder,
                tooltip: 'New Folder',
              ),
              IconButton(
                icon: const Icon(Icons.note_add, size: 22),
                onPressed: _createFile,
                tooltip: 'New File',
              ),
              IconButton(
                icon: const Icon(Icons.upload_file, size: 22),
                onPressed: _importFiles,
                tooltip: 'Import Files',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loadingFiles
              ? const Center(child: CircularProgressIndicator())
              : _entities.isEmpty
                  ? const Center(
                      child: Text('Empty folder', style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      itemCount: _entities.length,
                      itemBuilder: (context, index) {
                        final entity = _entities[index];
                        final isDir = entity is Directory;
                        final name = p.basename(entity.path);

                        return ListTile(
                          leading: Icon(
                            isDir ? Icons.folder : Icons.insert_drive_file,
                            color: isDir ? Colors.amber : Colors.blueGrey,
                          ),
                          title: Text(name),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                            onPressed: () => _deleteEntity(entity),
                          ),
                          onTap: () {
                            if (isDir) {
                              setState(() => _currentDir = entity.path);
                              _loadDirectory();
                            } else {
                              _openFile(entity.path);
                            }
                          },
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
        actions: [
          TextButton(
            onPressed: _leaveProject,
            child: const Text('Leave', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: _saveCurrentFile,
            child: const Text('Save', style: TextStyle(color: Colors.lightBlueAccent)),
          ),
          TextButton(
            onPressed: _runProject,
            child: const Text('Run', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
      body: _currentTab == 0 ? _buildEditorTab() : _buildProjectTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) => setState(() => _currentTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.edit),
            label: 'EDITOR',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder),
            label: 'PROJECT',
          ),
        ],
      ),
    );
  }
}
