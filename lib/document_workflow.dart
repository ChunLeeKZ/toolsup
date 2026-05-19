import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'user_profiles.dart';

enum WorkflowActionType {
  approval('approval', 'Согласование', Icons.rule_folder_outlined),
  signing('signing', 'Подписание', Icons.draw_outlined),
  review('review', 'Рассмотрение', Icons.visibility_outlined),
  familiarization('familiarization', 'Ознакомление', Icons.fact_check_outlined);

  const WorkflowActionType(this.code, this.label, this.icon);

  final String code;
  final String label;
  final IconData icon;

  static WorkflowActionType fromCode(String code) {
    return values.firstWhere(
      (value) => value.code == code,
      orElse: () => WorkflowActionType.review,
    );
  }
}

enum WorkflowStepStatus {
  pending('pending', 'Ожидает'),
  inProgress('in_progress', 'В работе'),
  completed('completed', 'Выполнено'),
  rejected('rejected', 'Отклонено');

  const WorkflowStepStatus(this.code, this.label);

  final String code;
  final String label;

  static WorkflowStepStatus fromCode(String code) {
    return values.firstWhere(
      (value) => value.code == code,
      orElse: () => WorkflowStepStatus.pending,
    );
  }
}

enum WorkflowDocumentStatus {
  draft('draft', 'Черновик'),
  inRoute('in_route', 'На маршруте'),
  completed('completed', 'Завершен'),
  rejected('rejected', 'Отклонен');

  const WorkflowDocumentStatus(this.code, this.label);

  final String code;
  final String label;

  static WorkflowDocumentStatus fromCode(String code) {
    return values.firstWhere(
      (value) => value.code == code,
      orElse: () => WorkflowDocumentStatus.draft,
    );
  }
}

class WorkflowRouteStep {
  const WorkflowRouteStep({
    required this.id,
    required this.stepNumber,
    required this.actionType,
    required this.assigneeName,
    required this.assigneeIin,
    required this.status,
    this.assigneeUserId,
    this.dueDate,
    this.completedAt,
    this.comment,
  });

  final String id;
  final int stepNumber;
  final WorkflowActionType actionType;
  final String? assigneeUserId;
  final String assigneeName;
  final int assigneeIin;
  final WorkflowStepStatus status;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? comment;
}

class WorkflowAttachment {
  const WorkflowAttachment({
    required this.id,
    required this.fileName,
    required this.storageBucket,
    required this.storagePath,
    required this.sizeBytes,
    required this.uploadedAt,
    this.mimeType,
  });

  final String id;
  final String fileName;
  final String storageBucket;
  final String storagePath;
  final int sizeBytes;
  final DateTime uploadedAt;
  final String? mimeType;
}

class WorkflowDocument {
  const WorkflowDocument({
    required this.id,
    required this.registrationNumber,
    required this.title,
    required this.documentType,
    required this.authorName,
    required this.authorIin,
    required this.status,
    required this.createdAt,
    required this.routeSteps,
    this.attachment,
  });

  final String id;
  final String registrationNumber;
  final String title;
  final String documentType;
  final String authorName;
  final int authorIin;
  final WorkflowDocumentStatus status;
  final DateTime createdAt;
  final List<WorkflowRouteStep> routeSteps;
  final WorkflowAttachment? attachment;

  WorkflowRouteStep? get currentStep {
    for (final step in routeSteps) {
      if (step.status == WorkflowStepStatus.inProgress) {
        return step;
      }
    }
    for (final step in routeSteps) {
      if (step.status == WorkflowStepStatus.pending) {
        return step;
      }
    }
    return routeSteps.isEmpty ? null : routeSteps.last;
  }
}

class PickedWorkflowAttachment {
  const PickedWorkflowAttachment({
    required this.fileName,
    required this.bytes,
    required this.sizeBytes,
    this.mimeType,
  });

  final String fileName;
  final Uint8List bytes;
  final int sizeBytes;
  final String? mimeType;
}

class CreateWorkflowRouteStepInput {
  const CreateWorkflowRouteStepInput({
    required this.actionType,
    required this.assignee,
    this.dueDate,
  });

  final WorkflowActionType actionType;
  final AppUserProfile assignee;
  final DateTime? dueDate;
}

class CreateWorkflowDocumentInput {
  const CreateWorkflowDocumentInput({
    required this.registrationNumber,
    required this.title,
    required this.documentType,
    required this.authorName,
    required this.authorIin,
    required this.routeSteps,
    required this.attachment,
  });

  final String registrationNumber;
  final String title;
  final String documentType;
  final String authorName;
  final int authorIin;
  final List<CreateWorkflowRouteStepInput> routeSteps;
  final PickedWorkflowAttachment attachment;
}

abstract interface class DocumentWorkflowRepository {
  Future<List<WorkflowDocument>> getDocuments();

  Future<List<AppUserProfile>> getUserProfiles();

  Future<WorkflowDocument> createDocument(CreateWorkflowDocumentInput input);
}

class SupabaseDocumentWorkflowRepository implements DocumentWorkflowRepository {
  const SupabaseDocumentWorkflowRepository();

  static const _documentsTable = 'document_workflow_documents';
  static const _routeStepsTable = 'document_workflow_route_steps';
  static const _attachmentsTable = 'document_workflow_attachments';
  static const _profilesTable = 'app_user_profiles';
  static const _attachmentsBucket = 'workflow-documents';
  static const _profileSelect =
      'id,email,display_name,iin,organization_bin,organization_name,photo_bucket,photo_path,photo_mime_type,photo_uploaded_at';
  static const _legacyProfileSelect =
      'id,email,display_name,iin,photo_bucket,photo_path,photo_mime_type,photo_uploaded_at';
  static const _documentSelect = '''
id,
registration_number,
title,
document_type,
author_name,
author_iin,
status,
created_at,
document_workflow_route_steps (
  id,
  step_number,
  action_type,
  assignee_user_id,
  assignee_name,
  assignee_iin,
  status,
  due_date,
  completed_at,
  comment
),
document_workflow_attachments (
  id,
  file_name,
  storage_bucket,
  storage_path,
  mime_type,
  size_bytes,
  uploaded_at
)
''';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<WorkflowDocument>> getDocuments() async {
    final rows = await _client
        .from(_documentsTable)
        .select(_documentSelect)
        .order('created_at', ascending: false);

    return rows.map(_workflowDocumentFromRow).toList();
  }

  @override
  Future<List<AppUserProfile>> getUserProfiles() async {
    final rows = await _selectUserProfiles();

    return rows
        .map((row) => appUserProfileFromRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<dynamic>> _selectUserProfiles() async {
    try {
      return await _client
          .from(_profilesTable)
          .select(_profileSelect)
          .order('display_name', ascending: true)
          .order('email', ascending: true);
    } catch (error) {
      if (!_isMissingColumnError(error)) {
        rethrow;
      }
      return _client
          .from(_profilesTable)
          .select(_legacyProfileSelect)
          .order('display_name', ascending: true)
          .order('email', ascending: true);
    }
  }

  @override
  Future<WorkflowDocument> createDocument(
    CreateWorkflowDocumentInput input,
  ) async {
    final documentRow = await _client
        .from(_documentsTable)
        .insert({
          'registration_number': input.registrationNumber,
          'title': input.title,
          'document_type': input.documentType,
          'author_name': input.authorName,
          'author_iin': input.authorIin,
          'status': WorkflowDocumentStatus.inRoute.code,
        })
        .select('id')
        .single();

    final documentId = _asString(documentRow['id']);
    await _insertRouteSteps(documentId, input.routeSteps);
    await _uploadAttachment(documentId, input.attachment);

    return _getDocumentById(documentId);
  }

  Future<WorkflowDocument> _getDocumentById(String documentId) async {
    final row = await _client
        .from(_documentsTable)
        .select(_documentSelect)
        .eq('id', documentId)
        .single();

    return _workflowDocumentFromRow(row);
  }

  Future<void> _insertRouteSteps(
    String documentId,
    List<CreateWorkflowRouteStepInput> routeSteps,
  ) async {
    final rows = <Map<String, Object?>>[];
    for (var index = 0; index < routeSteps.length; index += 1) {
      final step = routeSteps[index];
      rows.add({
        'document_id': documentId,
        'step_number': index + 1,
        'action_type': step.actionType.code,
        'assignee_user_id': step.assignee.id,
        'assignee_name': step.assignee.title,
        'assignee_iin': step.assignee.iin,
        'status': index == 0
            ? WorkflowStepStatus.inProgress.code
            : WorkflowStepStatus.pending.code,
        'due_date': step.dueDate == null
            ? null
            : _dateForDatabase(step.dueDate!),
      });
    }

    await _client.from(_routeStepsTable).insert(rows);
  }

  Future<void> _uploadAttachment(
    String documentId,
    PickedWorkflowAttachment attachment,
  ) async {
    final fileName = _sanitizeStorageFileName(attachment.fileName);
    final storagePath =
        '$documentId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage
        .from(_attachmentsBucket)
        .uploadBinary(
          storagePath,
          attachment.bytes,
          fileOptions: FileOptions(
            contentType: attachment.mimeType ?? 'application/octet-stream',
            upsert: false,
          ),
        );

    await _client.from(_attachmentsTable).insert({
      'document_id': documentId,
      'file_name': attachment.fileName,
      'storage_bucket': _attachmentsBucket,
      'storage_path': storagePath,
      'mime_type': attachment.mimeType,
      'size_bytes': attachment.sizeBytes,
    });
  }
}

class SampleDocumentWorkflowRepository implements DocumentWorkflowRepository {
  const SampleDocumentWorkflowRepository();

  static const _sampleProfiles = [
    AppUserProfile(
      id: 'user-kasymov',
      email: 'kasymov@example.com',
      displayName: 'Касымов Ерлан',
      iin: 860101300123,
    ),
    AppUserProfile(
      id: 'user-akhmetova',
      email: 'akhmetova@example.com',
      displayName: 'Ахметова Дина',
      iin: 910215450678,
    ),
    AppUserProfile(
      id: 'user-serikbayev',
      email: 'serikbayev@example.com',
      displayName: 'Серикбаев Нурлан',
      iin: 800930350456,
    ),
    AppUserProfile(
      id: 'user-director',
      email: 'director@example.com',
      displayName: 'Директор организации',
      iin: 770101300789,
    ),
    AppUserProfile(
      id: 'user-material',
      email: 'material@example.com',
      displayName: 'Материально ответственное лицо',
      iin: 850315301111,
    ),
  ];

  @override
  Future<List<WorkflowDocument>> getDocuments() async {
    return [
      WorkflowDocument(
        id: 'workflow-sample-1',
        registrationNumber: 'DOC-2026-001',
        title: 'Акт инвентаризации основных средств',
        documentType: 'Акт',
        authorName: 'Касымов Ерлан',
        authorIin: 860101300123,
        status: WorkflowDocumentStatus.inRoute,
        createdAt: DateTime(2026, 5, 18, 9, 30),
        attachment: WorkflowAttachment(
          id: 'workflow-sample-1-attachment',
          fileName: 'Акт инвентаризации.pdf',
          storageBucket: 'workflow-documents',
          storagePath: 'workflow-sample-1/act.pdf',
          sizeBytes: 258000,
          uploadedAt: DateTime(2026, 5, 18, 9, 35),
          mimeType: 'application/pdf',
        ),
        routeSteps: [
          WorkflowRouteStep(
            id: 'workflow-sample-1-step-1',
            stepNumber: 1,
            actionType: WorkflowActionType.review,
            assigneeUserId: 'user-akhmetova',
            assigneeName: 'Ахметова Дина',
            assigneeIin: 910215450678,
            status: WorkflowStepStatus.completed,
            dueDate: DateTime(2026, 5, 18),
            completedAt: DateTime(2026, 5, 18, 10, 15),
            comment: 'Рассмотрено без замечаний',
          ),
          WorkflowRouteStep(
            id: 'workflow-sample-1-step-2',
            stepNumber: 2,
            actionType: WorkflowActionType.approval,
            assigneeUserId: 'user-serikbayev',
            assigneeName: 'Серикбаев Нурлан',
            assigneeIin: 800930350456,
            status: WorkflowStepStatus.inProgress,
            dueDate: DateTime(2026, 5, 19),
          ),
          WorkflowRouteStep(
            id: 'workflow-sample-1-step-3',
            stepNumber: 3,
            actionType: WorkflowActionType.signing,
            assigneeUserId: 'user-director',
            assigneeName: 'Директор организации',
            assigneeIin: 770101300789,
            status: WorkflowStepStatus.pending,
            dueDate: DateTime(2026, 5, 20),
          ),
        ],
      ),
      WorkflowDocument(
        id: 'workflow-sample-2',
        registrationNumber: 'DOC-2026-002',
        title: 'Приказ о проведении инвентаризации',
        documentType: 'Приказ',
        authorName: 'Ахметова Дина',
        authorIin: 910215450678,
        status: WorkflowDocumentStatus.completed,
        createdAt: DateTime(2026, 5, 17, 15),
        attachment: WorkflowAttachment(
          id: 'workflow-sample-2-attachment',
          fileName: 'Приказ.pdf',
          storageBucket: 'workflow-documents',
          storagePath: 'workflow-sample-2/order.pdf',
          sizeBytes: 184000,
          uploadedAt: DateTime(2026, 5, 17, 15, 5),
          mimeType: 'application/pdf',
        ),
        routeSteps: [
          WorkflowRouteStep(
            id: 'workflow-sample-2-step-1',
            stepNumber: 1,
            actionType: WorkflowActionType.approval,
            assigneeUserId: 'user-kasymov',
            assigneeName: 'Касымов Ерлан',
            assigneeIin: 860101300123,
            status: WorkflowStepStatus.completed,
            completedAt: DateTime(2026, 5, 17, 16),
          ),
          WorkflowRouteStep(
            id: 'workflow-sample-2-step-2',
            stepNumber: 2,
            actionType: WorkflowActionType.familiarization,
            assigneeUserId: 'user-material',
            assigneeName: 'Материально ответственное лицо',
            assigneeIin: 850315301111,
            status: WorkflowStepStatus.completed,
            completedAt: DateTime(2026, 5, 17, 17),
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<AppUserProfile>> getUserProfiles() async {
    return _sampleProfiles;
  }

  @override
  Future<WorkflowDocument> createDocument(
    CreateWorkflowDocumentInput input,
  ) async {
    return WorkflowDocument(
      id: 'workflow-sample-created',
      registrationNumber: input.registrationNumber,
      title: input.title,
      documentType: input.documentType,
      authorName: input.authorName,
      authorIin: input.authorIin,
      status: WorkflowDocumentStatus.inRoute,
      createdAt: DateTime.now(),
      attachment: WorkflowAttachment(
        id: 'workflow-sample-created-attachment',
        fileName: input.attachment.fileName,
        storageBucket: 'workflow-documents',
        storagePath: 'sample/${input.attachment.fileName}',
        sizeBytes: input.attachment.sizeBytes,
        uploadedAt: DateTime.now(),
        mimeType: input.attachment.mimeType,
      ),
      routeSteps: [
        for (var index = 0; index < input.routeSteps.length; index += 1)
          WorkflowRouteStep(
            id: 'workflow-sample-created-step-${index + 1}',
            stepNumber: index + 1,
            actionType: input.routeSteps[index].actionType,
            assigneeUserId: input.routeSteps[index].assignee.id,
            assigneeName: input.routeSteps[index].assignee.title,
            assigneeIin: input.routeSteps[index].assignee.iin,
            status: index == 0
                ? WorkflowStepStatus.inProgress
                : WorkflowStepStatus.pending,
            dueDate: input.routeSteps[index].dueDate,
          ),
      ],
    );
  }
}

WorkflowDocument _workflowDocumentFromRow(Map<String, dynamic> row) {
  final rawSteps = row['document_workflow_route_steps'];
  final routeSteps = rawSteps is List
      ? rawSteps
            .map(
              (rawStep) =>
                  _workflowRouteStepFromRow(Map<String, dynamic>.from(rawStep)),
            )
            .toList()
      : <WorkflowRouteStep>[];

  routeSteps.sort((a, b) => a.stepNumber.compareTo(b.stepNumber));

  final rawAttachments = row['document_workflow_attachments'];
  final attachments = rawAttachments is List
      ? rawAttachments
            .map(
              (rawAttachment) => _workflowAttachmentFromRow(
                Map<String, dynamic>.from(rawAttachment),
              ),
            )
            .toList()
      : <WorkflowAttachment>[];

  attachments.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

  return WorkflowDocument(
    id: _asString(row['id']),
    registrationNumber: _asString(row['registration_number']),
    title: _asString(row['title']),
    documentType: _asString(row['document_type']),
    authorName: _asString(row['author_name']),
    authorIin: _asInt(row['author_iin']),
    status: WorkflowDocumentStatus.fromCode(_asString(row['status'])),
    createdAt: _asDateTime(row['created_at']),
    routeSteps: routeSteps,
    attachment: attachments.isEmpty ? null : attachments.first,
  );
}

WorkflowRouteStep _workflowRouteStepFromRow(Map<String, dynamic> row) {
  return WorkflowRouteStep(
    id: _asString(row['id']),
    stepNumber: _asInt(row['step_number']),
    actionType: WorkflowActionType.fromCode(_asString(row['action_type'])),
    assigneeUserId: row['assignee_user_id']?.toString(),
    assigneeName: _asString(row['assignee_name']),
    assigneeIin: _asInt(row['assignee_iin']),
    status: WorkflowStepStatus.fromCode(_asString(row['status'])),
    dueDate: _asNullableDate(row['due_date']),
    completedAt: _asNullableDateTime(row['completed_at']),
    comment: row['comment']?.toString(),
  );
}

WorkflowAttachment _workflowAttachmentFromRow(Map<String, dynamic> row) {
  return WorkflowAttachment(
    id: _asString(row['id']),
    fileName: _asString(row['file_name']),
    storageBucket: _asString(row['storage_bucket']),
    storagePath: _asString(row['storage_path']),
    sizeBytes: _asInt(row['size_bytes']),
    uploadedAt: _asDateTime(row['uploaded_at']),
    mimeType: row['mime_type']?.toString(),
  );
}

String _asString(Object? value) {
  return value?.toString() ?? '';
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.parse(value.toString());
}

DateTime _asDateTime(Object? value) {
  return DateTime.parse(value.toString()).toLocal();
}

DateTime? _asNullableDate(Object? value) {
  if (value == null || value.toString().isEmpty) {
    return null;
  }
  return DateTime.parse(value.toString());
}

DateTime? _asNullableDateTime(Object? value) {
  if (value == null || value.toString().isEmpty) {
    return null;
  }
  return DateTime.parse(value.toString()).toLocal();
}

String _dateForDatabase(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _sanitizeStorageFileName(String fileName) {
  final sanitized = fileName
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s+'), '_');
  return sanitized.isEmpty ? 'document' : sanitized;
}

String? workflowRequiredTextError(String value) {
  return value.trim().isEmpty ? 'Заполните поле' : null;
}

String? workflowIinError(String value) {
  final trimmed = value.trim();
  if (!RegExp(r'^\d{12}$').hasMatch(trimmed)) {
    return 'ИИН должен состоять из 12 цифр';
  }
  return null;
}

class DocumentWorkflowPage extends StatefulWidget {
  const DocumentWorkflowPage({
    this.repository = const SupabaseDocumentWorkflowRepository(),
    super.key,
  });

  final DocumentWorkflowRepository repository;

  @override
  State<DocumentWorkflowPage> createState() => _DocumentWorkflowPageState();
}

class _DocumentWorkflowPageState extends State<DocumentWorkflowPage> {
  var _documents = <WorkflowDocument>[];
  var _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final documents = await widget.repository.getDocuments();
      if (!mounted) {
        return;
      }
      setState(() {
        _documents = documents;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  void _openDocument(WorkflowDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => DocumentWorkflowDetailsPage(document: document),
      ),
    );
  }

  Future<void> _openCreateDocument() async {
    final createdDocument = await Navigator.of(context).push<WorkflowDocument>(
      MaterialPageRoute<WorkflowDocument>(
        builder: (context) =>
            CreateWorkflowDocumentPage(repository: widget.repository),
      ),
    );

    if (createdDocument == null || !mounted) {
      return;
    }

    setState(() {
      _documents = [createdDocument, ..._documents];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Документооборот')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDocument,
        icon: const Icon(Icons.add),
        label: const Text('Создать'),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return _WorkflowLoadError(message: _loadError!, onRetry: _loadDocuments);
    }

    if (_documents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.note_add_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                'Документы не найдены',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Создайте документ и отправьте его по маршруту бизнес-процесса.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _documents.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final document = _documents[index];
          return _WorkflowDocumentCard(
            document: document,
            onTap: () => _openDocument(document),
          );
        },
      ),
    );
  }
}

class CreateWorkflowDocumentPage extends StatefulWidget {
  const CreateWorkflowDocumentPage({required this.repository, super.key});

  final DocumentWorkflowRepository repository;

  @override
  State<CreateWorkflowDocumentPage> createState() =>
      _CreateWorkflowDocumentPageState();
}

class _CreateWorkflowDocumentPageState
    extends State<CreateWorkflowDocumentPage> {
  final _formKey = GlobalKey<FormState>();
  final _registrationNumberController = TextEditingController(
    text: 'DOC-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch}',
  );
  final _titleController = TextEditingController();
  final _authorNameController = TextEditingController();
  final _authorIinController = TextEditingController();
  final _documentTypes = const [
    'Акт',
    'Приказ',
    'Служебная записка',
    'Договор',
    'Письмо',
    'Другое',
  ];
  late String _documentType = _documentTypes.first;
  final _routeSteps = <_RouteStepDraft>[
    _RouteStepDraft(actionType: WorkflowActionType.approval),
  ];
  var _profiles = <AppUserProfile>[];
  var _isLoadingProfiles = true;
  String? _profilesError;
  PickedWorkflowAttachment? _attachment;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfiles();
  }

  @override
  void dispose() {
    _registrationNumberController.dispose();
    _titleController.dispose();
    _authorNameController.dispose();
    _authorIinController.dispose();
    for (final step in _routeSteps) {
      step.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserProfiles() async {
    try {
      final profiles = await widget.repository.getUserProfiles();
      if (!mounted) {
        return;
      }
      setState(() {
        _profiles = profiles;
        _isLoadingProfiles = false;
        _profilesError = null;
        if (profiles.length == 1) {
          _routeSteps.first.assignee = profiles.first;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profilesError = error.toString();
        _isLoadingProfiles = false;
      });
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'png',
        'jpg',
        'jpeg',
      ],
    );

    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        _errorMessage = 'Не удалось прочитать выбранный файл.';
      });
      return;
    }

    setState(() {
      _attachment = PickedWorkflowAttachment(
        fileName: file.name,
        bytes: bytes,
        sizeBytes: file.size,
        mimeType: _mimeTypeFromFileName(file.name),
      );
      _errorMessage = null;
    });
  }

  Future<void> _selectDueDate(_RouteStepDraft step) async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: step.dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      step.dueDate = selectedDate;
    });
  }

  void _addRouteStep() {
    setState(() {
      _routeSteps.add(_RouteStepDraft(actionType: WorkflowActionType.review));
    });
  }

  void _removeRouteStep(int index) {
    if (_routeSteps.length == 1) {
      return;
    }

    setState(() {
      final removedStep = _routeSteps.removeAt(index);
      removedStep.dispose();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_attachment == null) {
      setState(() {
        _errorMessage = 'Прикрепите документ для отправки по маршруту.';
      });
      return;
    }

    if (_routeSteps.any((step) => step.assignee == null)) {
      setState(() {
        _errorMessage = 'Выберите исполнителя на каждом этапе маршрута.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final createdDocument = await widget.repository.createDocument(
        CreateWorkflowDocumentInput(
          registrationNumber: _registrationNumberController.text.trim(),
          title: _titleController.text.trim(),
          documentType: _documentType,
          authorName: _authorNameController.text.trim(),
          authorIin: int.parse(_authorIinController.text.trim()),
          attachment: _attachment!,
          routeSteps: [
            for (final step in _routeSteps)
              CreateWorkflowRouteStepInput(
                actionType: step.actionType,
                assignee: step.assignee!,
                dueDate: step.dueDate,
              ),
          ],
        ),
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(createdDocument);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Не удалось создать документ: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Новый документ')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Реквизиты документа',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _registrationNumberController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Номер документа',
                          prefixIcon: Icon(Icons.tag_outlined),
                        ),
                        validator: (value) =>
                            workflowRequiredTextError(value ?? ''),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Наименование документа',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        validator: (value) =>
                            workflowRequiredTextError(value ?? ''),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _documentType,
                        decoration: const InputDecoration(
                          labelText: 'Тип документа',
                          prefixIcon: Icon(Icons.article_outlined),
                        ),
                        items: [
                          for (final type in _documentTypes)
                            DropdownMenuItem(value: type, child: Text(type)),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _documentType = value;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _authorNameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Автор документа',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            workflowRequiredTextError(value ?? ''),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _authorIinController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        maxLength: 12,
                        decoration: const InputDecoration(
                          labelText: 'ИИН автора',
                          counterText: '',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (value) => workflowIinError(value ?? ''),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Вложение',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_attachment == null)
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _pickAttachment,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Прикрепить документ'),
                        )
                      else
                        _PickedAttachmentTile(
                          attachment: _attachment!,
                          onRemove: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    _attachment = null;
                                  });
                                },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Маршрут бизнес-процесса',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Добавить этап',
                            onPressed: _isSaving ? null : _addRouteStep,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingProfiles)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(),
                        ),
                      if (_profilesError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _InlineErrorBox(
                            message:
                                'Не удалось загрузить пользователей: $_profilesError',
                          ),
                        ),
                      if (!_isLoadingProfiles && _profiles.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _InlineErrorBox(
                            message:
                                'Список пользователей пуст. Создайте таблицу app_user_profiles и войдите пользователями в приложение.',
                          ),
                        ),
                      for (
                        var index = 0;
                        index < _routeSteps.length;
                        index += 1
                      )
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RouteStepEditor(
                            index: index,
                            step: _routeSteps[index],
                            canRemove: _routeSteps.length > 1,
                            onRemove: () => _removeRouteStep(index),
                            onSelectDueDate: () =>
                                _selectDueDate(_routeSteps[index]),
                            onChanged: () => setState(() {}),
                            profiles: _profiles,
                            enabled: !_isSaving,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Отправить по маршруту'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteStepDraft {
  _RouteStepDraft({required this.actionType});

  WorkflowActionType actionType;
  AppUserProfile? assignee;
  DateTime? dueDate;

  void dispose() {}
}

class _RouteStepEditor extends StatelessWidget {
  const _RouteStepEditor({
    required this.index,
    required this.step,
    required this.canRemove,
    required this.onRemove,
    required this.onSelectDueDate,
    required this.onChanged,
    required this.profiles,
    required this.enabled,
  });

  final int index;
  final _RouteStepDraft step;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onSelectDueDate;
  final VoidCallback onChanged;
  final List<AppUserProfile> profiles;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ToolsupPalette.navy,
        border: Border.all(color: ToolsupPalette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Этап ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Удалить этап',
                  onPressed: enabled && canRemove ? onRemove : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<WorkflowActionType>(
              initialValue: step.actionType,
              decoration: const InputDecoration(
                labelText: 'Действие',
                prefixIcon: Icon(Icons.route_outlined),
              ),
              items: [
                for (final actionType in WorkflowActionType.values)
                  DropdownMenuItem(
                    value: actionType,
                    child: Text(actionType.label),
                  ),
              ],
              onChanged: enabled
                  ? (value) {
                      if (value == null) {
                        return;
                      }
                      step.actionType = value;
                      onChanged();
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AppUserProfile>(
              key: ValueKey(
                'assignee-$index-${step.assignee?.id ?? 'none'}-${profiles.length}',
              ),
              initialValue: step.assignee,
              decoration: const InputDecoration(
                labelText: 'Исполнитель',
                prefixIcon: Icon(Icons.person_search_outlined),
              ),
              items: [
                for (final profile in profiles)
                  DropdownMenuItem(value: profile, child: Text(profile.title)),
              ],
              onChanged: enabled && profiles.isNotEmpty
                  ? (value) {
                      step.assignee = value;
                      onChanged();
                    }
                  : null,
              validator: (value) =>
                  value == null ? 'Выберите пользователя' : null,
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'ИИН исполнителя',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              child: Text(
                step.assignee?.iinText ?? 'Заполнится из карточки пользователя',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: step.assignee == null
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: enabled ? onSelectDueDate : null,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                step.dueDate == null
                    ? 'Выбрать срок этапа'
                    : 'Срок: ${_formatDate(step.dueDate!)}',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickedAttachmentTile extends StatelessWidget {
  const _PickedAttachmentTile({
    required this.attachment,
    required this.onRemove,
  });

  final PickedWorkflowAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ToolsupPalette.navy,
        border: Border.all(color: ToolsupPalette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.insert_drive_file_outlined, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    attachment.fileName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatFileSize(attachment.sizeBytes),
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Удалить файл',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineErrorBox extends StatelessWidget {
  const _InlineErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
      ),
    );
  }
}

class DocumentWorkflowDetailsPage extends StatelessWidget {
  const DocumentWorkflowDetailsPage({required this.document, super.key});

  final WorkflowDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(document.registrationNumber)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      document.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _WorkflowField(
                      label: 'Номер документа',
                      value: document.registrationNumber,
                    ),
                    _WorkflowField(
                      label: 'Тип документа',
                      value: document.documentType,
                    ),
                    _WorkflowField(
                      label: 'Статус',
                      value: document.status.label,
                    ),
                    _WorkflowField(label: 'Автор', value: document.authorName),
                    _WorkflowField(
                      label: 'ИИН автора',
                      value: document.authorIin.toString(),
                    ),
                    _WorkflowField(
                      label: 'Создан',
                      value: _formatDateTime(document.createdAt),
                    ),
                    if (document.attachment != null) ...[
                      const SizedBox(height: 4),
                      _WorkflowAttachmentView(attachment: document.attachment!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Маршрут бизнес-процесса',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...document.routeSteps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WorkflowStepCard(step: step),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowDocumentCard extends StatelessWidget {
  const _WorkflowDocumentCard({required this.document, required this.onTap});

  final WorkflowDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentStep = document.currentStep;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.account_tree_outlined, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      document.registrationNumber,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: colors.secondary,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                document.title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _WorkflowChip(
                    label: document.status.label,
                    active: document.status == WorkflowDocumentStatus.completed,
                  ),
                  _WorkflowChip(
                    label: '${document.routeSteps.length} этапа',
                    active: false,
                  ),
                  if (document.attachment != null)
                    const _WorkflowChip(label: 'Файл прикреплен', active: true),
                ],
              ),
              const Divider(height: 24),
              _WorkflowField(label: 'Тип', value: document.documentType),
              _WorkflowField(label: 'Автор', value: document.authorName),
              if (currentStep != null)
                _WorkflowField(
                  label: 'Текущий этап',
                  value:
                      '${currentStep.actionType.label}: ${currentStep.assigneeName}',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowStepCard extends StatelessWidget {
  const _WorkflowStepCard({required this.step});

  final WorkflowRouteStep step;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(step.actionType.icon, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${step.stepNumber}. ${step.actionType.label}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _WorkflowChip(
                  label: step.status.label,
                  active: step.status == WorkflowStepStatus.completed,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _WorkflowField(label: 'Исполнитель', value: step.assigneeName),
            _WorkflowField(
              label: 'ИИН исполнителя',
              value: step.assigneeIin.toString(),
            ),
            if (step.dueDate != null)
              _WorkflowField(label: 'Срок', value: _formatDate(step.dueDate!)),
            if (step.completedAt != null)
              _WorkflowField(
                label: 'Выполнено',
                value: _formatDateTime(step.completedAt!),
              ),
            if (step.comment != null && step.comment!.isNotEmpty)
              _WorkflowField(label: 'Комментарий', value: step.comment!),
          ],
        ),
      ),
    );
  }
}

class _WorkflowAttachmentView extends StatelessWidget {
  const _WorkflowAttachmentView({required this.attachment});

  final WorkflowAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ToolsupPalette.navy,
        border: Border.all(color: ToolsupPalette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.attach_file, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    attachment.fileName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatFileSize(attachment.sizeBytes)} • ${_formatDateTime(attachment.uploadedAt)}',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowLoadError extends StatelessWidget {
  const _WorkflowLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: colors.error, size: 42),
            const SizedBox(height: 12),
            Text(
              'Не удалось загрузить документы из Supabase',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowField extends StatelessWidget {
  const _WorkflowField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _WorkflowChip extends StatelessWidget {
  const _WorkflowChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? colors.primaryContainer : ToolsupPalette.navy,
        border: Border.all(
          color: active ? colors.primary : ToolsupPalette.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: active ? colors.onPrimaryContainer : colors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String _formatDateTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '${_formatDate(dateTime)} $hour:$minute';
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes Б';
  }
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) {
    return '${kilobytes.toStringAsFixed(1)} КБ';
  }
  final megabytes = kilobytes / 1024;
  return '${megabytes.toStringAsFixed(1)} МБ';
}

bool _isMissingColumnError(Object error) {
  return error is PostgrestException && error.code == '42703';
}

String _mimeTypeFromFileName(String fileName) {
  final lowerName = fileName.toLowerCase();
  if (lowerName.endsWith('.pdf')) {
    return 'application/pdf';
  }
  if (lowerName.endsWith('.doc')) {
    return 'application/msword';
  }
  if (lowerName.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lowerName.endsWith('.xls')) {
    return 'application/vnd.ms-excel';
  }
  if (lowerName.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  if (lowerName.endsWith('.png')) {
    return 'image/png';
  }
  if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  return 'application/octet-stream';
}
