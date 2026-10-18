import 'package:flutter/material.dart';
import '../models/project.dart';
import '../services/storage_service.dart';
import 'project_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  List<Project> _projects = [];
  bool _loading = true;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final granted = await _storage.requestPermissions();
    setState(() => _permissionGranted = granted);
    await _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _loading = true);
    final list = await _storage.listProjects();
    setState(() {
      _projects = list;
      _loading = false;
    });
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    ProjectType selectedType = ProjectType.website;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Create New Project'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Project Name',
                      hintText: 'MyProject',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),
                  const Text('Project Type', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Website'),
                          selected: selectedType == ProjectType.website,
                          onSelected: (v) {
                            if (v) setDialogState(() => selectedType = ProjectType.website);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Application'),
                          selected: selectedType == ProjectType.application,
                          onSelected: (v) {
                            if (v) setDialogState(() => selectedType = ProjectType.application);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final project = await _storage.createProject(
        nameController.text.trim(),
        selectedType,
      );

      if (project != null) {
        await _loadProjects();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Project "${project.name}" created!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project already exists or failed to create')),
          );
        }
      }
    }
  }

  Future<void> _deleteProject(Project project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Project?'),
        content: Text('Are you sure you want to delete "${project.name}"?\nThis cannot be undone.'),
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
      final success = await _storage.deleteProject(project);
      if (success) {
        await _loadProjects();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Project "${project.name}" deleted')),
          );
        }
      }
    }
  }

  void _openProject(Project project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectScreen(project: project),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LeGame Project Workshop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProjects,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_permissionGranted)
                  Container(
                    width: double.infinity,
                    color: Colors.orange.shade800,
                    padding: const EdgeInsets.all(12),
                    child: const Text(
                      'Storage permission not fully granted. Some features may not work.',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: _projects.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open, size: 80, color: Colors.grey.shade600),
                              const SizedBox(height: 16),
                              const Text(
                                'No projects yet',
                                style: TextStyle(fontSize: 20, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap + to create your first project',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _projects.length,
                          itemBuilder: (context, index) {
                            final project = _projects[index];
                            return Card(
                              color: const Color(0xFF1E1E1E),
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: project.type == ProjectType.website
                                      ? Colors.blue.shade700
                                      : Colors.green.shade700,
                                  child: Icon(
                                    project.type == ProjectType.website
                                        ? Icons.language
                                        : Icons.phone_android,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  project.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${project.typeLabel}  •  ${project.createdAt.toString().substring(0, 16)}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _deleteProject(project),
                                ),
                                onTap: () => _openProject(project),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Project'),
      ),
    );
  }
}
