import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/project.dart';

class StorageService {
  static const String appFolderName = 'com.legame.project';

  /// Returns the base projects directory:
  /// /storage/emulated/0/Android/data/com.legame.project/projects/
  Future<Directory> getProjectsRoot() async {
    // For Android we prefer external storage path matching the requested structure
    if (Platform.isAndroid) {
      // Try to use the Android/data path
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        // externalDir is usually /storage/emulated/0/Android/data/com.legame.project/files
        // We go up and create /projects
        final base = externalDir.parent; // goes to .../com.legame.project
        final projectsDir = Directory(p.join(base.path, 'projects'));
        if (!await projectsDir.exists()) {
          await projectsDir.create(recursive: true);
        }
        return projectsDir;
      }
    }

    // Fallback for other platforms or if external fails
    final appDoc = await getApplicationDocumentsDirectory();
    final projectsDir = Directory(p.join(appDoc.path, 'projects'));
    if (!await projectsDir.exists()) {
      await projectsDir.create(recursive: true);
    }
    return projectsDir;
  }

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;

    // For Android 11+ we need manageExternalStorage for full access
    // but for app-specific directory (Android/data/...) normal storage is enough
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    // Also request manage external storage for broader access if needed
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }

    return status.isGranted || await Permission.manageExternalStorage.isGranted;
  }

  /// Create a new project folder:
  /// projects/"projectname"-website/  or  projects/"projectname"-app/
  Future<Project?> createProject(String name, ProjectType type) async {
    if (name.trim().isEmpty) return null;

    final root = await getProjectsRoot();
    final folderName = '$name-${type == ProjectType.website ? 'website' : 'app'}';
    final projectPath = p.join(root.path, folderName);
    final dir = Directory(projectPath);

    if (await dir.exists()) {
      // Already exists
      return null;
    }

    await dir.create(recursive: true);

    // Create a basic starter file
    if (type == ProjectType.website) {
      final indexFile = File(p.join(projectPath, 'index.html'));
      await indexFile.writeAsString('''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$name</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; background: #1a1a1a; color: #eee; }
    h1 { color: #4fc3f7; }
  </style>
</head>
<body>
  <h1>Welcome to $name</h1>
  <p>This is your new Website project.</p>
</body>
</html>''');
    } else {
      // Application starter
      final mainFile = File(p.join(projectPath, 'main.dart'));
      await mainFile.writeAsString('''// $name - Application Project
void main() {
  print('Hello from $name!');
}
''');
    }

    return Project(
      name: name,
      type: type,
      path: projectPath,
      createdAt: DateTime.now(),
    );
  }

  /// List all existing projects
  Future<List<Project>> listProjects() async {
    final root = await getProjectsRoot();
    final list = <Project>[];

    if (!await root.exists()) return list;

    await for (final entity in root.list()) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        if (name.contains('-website')) {
          final projectName = name.replaceAll('-website', '');
          list.add(Project(
            name: projectName,
            type: ProjectType.website,
            path: entity.path,
            createdAt: (await entity.stat()).modified,
          ));
        } else if (name.contains('-app')) {
          final projectName = name.replaceAll('-app', '');
          list.add(Project(
            name: projectName,
            type: ProjectType.application,
            path: entity.path,
            createdAt: (await entity.stat()).modified,
          ));
        }
      }
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Delete a whole project
  Future<bool> deleteProject(Project project) async {
    try {
      final dir = Directory(project.path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return true;
      }
    } catch (e) {
      print('Error deleting project: $e');
    }
    return false;
  }

  // ---------- File & Folder operations inside a project ----------

  Future<List<FileSystemEntity>> listDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];
    final entities = await dir.list().toList();
    // Sort: folders first, then files
    entities.sort((a, b) {
      final aIsDir = a is Directory;
      final bIsDir = b is Directory;
      if (aIsDir && !bIsDir) return -1;
      if (!aIsDir && bIsDir) return 1;
      return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
    });
    return entities;
  }

  Future<bool> createFile(String parentPath, String fileName) async {
    try {
      final file = File(p.join(parentPath, fileName));
      if (await file.exists()) return false;
      await file.create();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> createFolder(String parentPath, String folderName) async {
    try {
      final dir = Directory(p.join(parentPath, folderName));
      if (await dir.exists()) return false;
      await dir.create();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteEntity(String path) async {
    try {
      final type = await FileSystemEntity.type(path);
      if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else if (type == FileSystemEntityType.file) {
        await File(path).delete();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> readFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      print('Error reading file: $e');
    }
    return null;
  }

  Future<bool> writeFile(String path, String content) async {
    try {
      final file = File(path);
      await file.writeAsString(content);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> importFile(String targetDir, String sourcePath) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) return false;
      final fileName = p.basename(sourcePath);
      final dest = p.join(targetDir, fileName);
      await source.copy(dest);
      return true;
    } catch (e) {
      return false;
    }
  }
}
