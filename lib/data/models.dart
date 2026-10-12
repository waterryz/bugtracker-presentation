const issueStatuses = [
  'Новый',
  'В работе',
  'Исправлен',
  'На проверке',
  'Закрыт',
  'Переоткрыт',
];
const issuePriorities = ['Низкий', 'Средний', 'Высокий', 'Критический'];
const userRoles = ['Тестировщик', 'Разработчик', 'Менеджер'];

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.phone,
  });
  final int id;
  final String name, email, role, phone;
  factory AppUser.fromMap(Map<String, Object?> row) => AppUser(
    id: row['id'] as int,
    name: row['name'] as String,
    email: row['email'] as String,
    role: row['role'] as String,
    phone: row['phone'] as String,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'phone': phone,
  };
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.createdAt,
  });
  final int id;
  final String name, description, color;
  final DateTime createdAt;
  factory Project.fromMap(Map<String, Object?> row) => Project(
    id: row['id'] as int,
    name: row['name'] as String,
    description: row['description'] as String,
    color: row['color'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'color': color,
    'created_at': createdAt.toIso8601String(),
  };
}

class Issue {
  const Issue({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.steps,
    required this.expected,
    required this.actual,
    required this.status,
    required this.priority,
    required this.severity,
    required this.environment,
    this.assigneeId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });
  final int id, projectId, createdBy;
  final int? assigneeId;
  final String title,
      description,
      steps,
      expected,
      actual,
      status,
      priority,
      severity,
      environment;
  final DateTime createdAt, updatedAt;
  factory Issue.fromMap(Map<String, Object?> row) => Issue(
    id: row['id'] as int,
    projectId: row['project_id'] as int,
    title: row['title'] as String,
    description: row['description'] as String,
    steps: row['steps'] as String,
    expected: row['expected'] as String,
    actual: row['actual'] as String,
    status: row['status'] as String,
    priority: row['priority'] as String,
    severity: row['severity'] as String,
    environment: row['environment'] as String,
    assigneeId: row['assignee_id'] as int?,
    createdBy: row['created_by'] as int,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'project_id': projectId,
    'title': title,
    'description': description,
    'steps': steps,
    'expected': expected,
    'actual': actual,
    'status': status,
    'priority': priority,
    'severity': severity,
    'environment': environment,
    'assignee_id': assigneeId,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class IssueComment {
  const IssueComment({
    required this.id,
    required this.issueId,
    required this.userId,
    required this.text,
    required this.createdAt,
  });
  final int id, issueId, userId;
  final String text;
  final DateTime createdAt;
  factory IssueComment.fromMap(Map<String, Object?> row) => IssueComment(
    id: row['id'] as int,
    issueId: row['issue_id'] as int,
    userId: row['user_id'] as int,
    text: row['text'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

class IssueActivity {
  const IssueActivity({
    required this.id,
    required this.issueId,
    required this.text,
    required this.createdAt,
  });
  final int id, issueId;
  final String text;
  final DateTime createdAt;
  factory IssueActivity.fromMap(Map<String, Object?> row) => IssueActivity(
    id: row['id'] as int,
    issueId: row['issue_id'] as int,
    text: row['text'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

class IssueAttachment {
  const IssueAttachment({
    required this.id,
    required this.issueId,
    required this.name,
    required this.path,
  });
  final int id, issueId;
  final String name, path;
  factory IssueAttachment.fromMap(Map<String, Object?> row) => IssueAttachment(
    id: row['id'] as int,
    issueId: row['issue_id'] as int,
    name: row['name'] as String,
    path: row['path'] as String,
  );
}
