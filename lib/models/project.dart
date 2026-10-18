enum ProjectType { website, application }

class Project {
  final String name;
  final ProjectType type;
  final String path; // Full path to the project folder
  final DateTime createdAt;

  Project({
    required this.name,
    required this.type,
    required this.path,
    required this.createdAt,
  });

  String get typeLabel => type == ProjectType.website ? 'Website' : 'Application';

  String get folderName => '$name-${type == ProjectType.website ? 'website' : 'app'}';

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.name,
        'path': path,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      name: json['name'] as String,
      type: json['type'] == 'website' ? ProjectType.website : ProjectType.application,
      path: json['path'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
