typedef Json = Map<String, dynamic>;

List<Json> records(dynamic value) => (value as List? ?? const [])
    .whereType<Map>()
    .map((item) => Map<String, dynamic>.from(item))
    .toList();

String textOf(Json item, String key, [String fallback = '']) =>
    item[key] is String ? item[key] as String : fallback;

class Specialist {
  Specialist.fromJson(this.json);
  final Json json;
  String get id => textOf(json, 'id');
  String get name => textOf(json, 'name');
  String get role => textOf(json, 'role');
  String get instructions => textOf(json, 'instructions');
  bool get research => json['research'] == true;
  bool get memory => json['memory'] == true;
  bool get code => json['code'] == true;
  bool get apps => json['apps'] == true;
  bool get learning => json['learning'] == true;
  List<String> get spaceIds => List<String>.from(json['spaceIds'] ?? []);
}

class CopilotMessage {
  CopilotMessage.fromJson(this.json);
  final Json json;
  String get id => textOf(json, 'id');
  String get role => textOf(json, 'role');
  String get body => textOf(json, 'body');
  String get status => textOf(json, 'status', 'complete');
  List<Json> get sources => records(json['sources']);
  List<Json> get artifacts => records(json['artifacts']);
  List<Json> get activity => records(json['activity']);
  List<Json> get attachments => records(json['attachments']);
  bool get isUser => role == 'user';
}

class CopilotThread {
  CopilotThread.fromJson(this.json);
  final Json json;
  String get id => textOf(json, 'id');
  String get title => textOf(json, 'title', 'New conversation');
  String get specialistId => textOf(json, 'specialistId');
  String? get pageId => json['pageId'] as String?;
  String get status => textOf(json, 'status', 'idle');
  bool get pinned => json['pinned'] == true;
  List<CopilotMessage> get messages =>
      records(json['messages']).map(CopilotMessage.fromJson).toList();
  List<Json> get approvals => records(json['approvals']);
}

class WorkspacePage {
  WorkspacePage.fromJson(this.json);
  final Json json;
  String get id => textOf(json, 'id');
  String get title => textOf(json, 'title', 'Untitled page');
  String get body => textOf(json, 'body');
  String get spaceId => textOf(json, 'spaceId');
  String? get parentId => json['parentId'] as String?;
  int get revision => (json['revision'] as num?)?.toInt() ?? 0;
}

class CopilotWorkspace {
  CopilotWorkspace.fromJson(this.json);
  factory CopilotWorkspace.empty() => CopilotWorkspace.fromJson({});
  final Json json;
  List<Specialist> get specialists =>
      records(json['specialists']).map(Specialist.fromJson).toList();
  List<CopilotThread> get threads =>
      records(json['threads']).map(CopilotThread.fromJson).toList();
  List<WorkspacePage> get pages =>
      records(json['pages']).map(WorkspacePage.fromJson).toList();
  List<Json> get spaces => records(json['spaces']);
  List<Json> get memories => records(json['memories']);
  List<Json> get schedules => records(json['schedules']);
  List<Json> get connections => records(json['connections']);
  List<Json> get skills => records(json['skills']);
  List<Json> get calls => records(json['calls']);
  Json get settings => Map<String, dynamic>.from(json['settings'] ?? {});
  Json get setup => Map<String, dynamic>.from(json['setup'] ?? {});
}

Json initialWorkspace() => {
  'version': 1,
  'spaces': [
    {
      'id': 'research',
      'name': 'Research',
      'description': 'Ideas worth keeping',
    },
    {
      'id': 'playbook',
      'name': 'Trading playbook',
      'description': 'Your edge, refined',
    },
  ],
  'specialists': [
    {
      'id': 'analyst',
      'name': 'Atlas',
      'role': 'Research analyst',
      'instructions':
          'Research markets carefully. Cite current sources, separate facts from interpretation, and explain uncertainty.',
      'spaceIds': ['research', 'playbook'],
      'research': true,
      'memory': true,
      'code': true,
      'apps': false,
      'learning': false,
    },
    {
      'id': 'coach',
      'name': 'Sage',
      'role': 'Trading coach',
      'instructions':
          'Help the trader improve process, discipline, and risk management. Review supplied trades without inventing performance data.',
      'spaceIds': ['playbook'],
      'research': false,
      'memory': true,
      'code': true,
      'apps': false,
      'learning': false,
    },
    {
      'id': 'writer',
      'name': 'Quill',
      'role': 'Writing partner',
      'instructions':
          'Turn research into clear, useful documents. Preserve source links. Offer a draft for review before saving.',
      'spaceIds': ['research', 'playbook'],
      'research': true,
      'memory': true,
      'code': false,
      'apps': false,
      'learning': false,
    },
  ],
  'threads': <Json>[],
  'pages': <Json>[],
  'memories': <Json>[],
  'schedules': <Json>[],
  'connections': <Json>[],
  'skills': <Json>[],
  'calls': <Json>[],
  'settings': {
    'paused': false,
    'research': true,
    'memory': true,
    'apps': false,
  },
};
