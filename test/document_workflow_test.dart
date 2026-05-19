import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:toolsup/document_workflow.dart';
import 'package:toolsup/user_profiles.dart';

void main() {
  test('workflow documents contain headers and route steps', () async {
    const repository = SampleDocumentWorkflowRepository();

    final documents = await repository.getDocuments();

    expect(documents, isNotEmpty);
    expect(documents.first.id, isA<String>());
    expect(documents.first.registrationNumber, isA<String>());
    expect(documents.first.title, isA<String>());
    expect(documents.first.documentType, isA<String>());
    expect(documents.first.authorName, isA<String>());
    expect(documents.first.authorIin, isA<int>());
    expect(documents.first.status, isA<WorkflowDocumentStatus>());
    expect(documents.first.attachment, isNotNull);
    expect(documents.first.attachment!.fileName, isA<String>());
    expect(documents.first.routeSteps, isNotEmpty);
    expect(documents.first.routeSteps.first.assigneeUserId, isA<String>());
    expect(
      documents.first.routeSteps.first.actionType,
      isA<WorkflowActionType>(),
    );
    expect(documents.first.routeSteps.first.status, isA<WorkflowStepStatus>());
  });

  test('workflow document resolves current route step', () async {
    const repository = SampleDocumentWorkflowRepository();

    final document = (await repository.getDocuments()).first;

    expect(document.currentStep, isNotNull);
    expect(document.currentStep!.actionType, WorkflowActionType.approval);
    expect(document.currentStep!.status, WorkflowStepStatus.inProgress);
  });

  test('workflow dictionaries parse database codes', () {
    expect(WorkflowActionType.fromCode('approval').label, 'Согласование');
    expect(WorkflowActionType.fromCode('signing').label, 'Подписание');
    expect(WorkflowActionType.fromCode('review').label, 'Рассмотрение');
    expect(
      WorkflowActionType.fromCode('familiarization').label,
      'Ознакомление',
    );
    expect(WorkflowDocumentStatus.fromCode('in_route').label, 'На маршруте');
    expect(WorkflowStepStatus.fromCode('completed').label, 'Выполнено');
  });

  test('loads workflow user profiles for route executors', () async {
    const repository = SampleDocumentWorkflowRepository();

    final profiles = await repository.getUserProfiles();

    expect(profiles, isNotEmpty);
    expect(profiles.first, isA<AppUserProfile>());
    expect(profiles.first.iinText.length, 12);
  });

  test('creates workflow document with attachment and route', () async {
    const repository = SampleDocumentWorkflowRepository();
    final profiles = await repository.getUserProfiles();

    final document = await repository.createDocument(
      CreateWorkflowDocumentInput(
        registrationNumber: 'DOC-TEST-001',
        title: 'Тестовый документ',
        documentType: 'Акт',
        authorName: 'Тестовый автор',
        authorIin: 123456789012,
        attachment: PickedWorkflowAttachment(
          fileName: 'document.pdf',
          bytes: Uint8List.fromList([1, 2, 3]),
          sizeBytes: 3,
          mimeType: 'application/pdf',
        ),
        routeSteps: const [
          CreateWorkflowRouteStepInput(
            actionType: WorkflowActionType.approval,
            assignee: AppUserProfile(
              id: 'approver',
              email: 'approver@example.com',
              displayName: 'Согласующий',
              iin: 123456789011,
            ),
          ),
          CreateWorkflowRouteStepInput(
            actionType: WorkflowActionType.signing,
            assignee: AppUserProfile(
              id: 'signer',
              email: 'signer@example.com',
              displayName: 'Подписант',
              iin: 123456789010,
            ),
          ),
        ],
      ),
    );

    expect(profiles, isNotEmpty);
    expect(document.registrationNumber, 'DOC-TEST-001');
    expect(document.attachment?.fileName, 'document.pdf');
    expect(document.routeSteps.first.assigneeUserId, 'approver');
    expect(document.routeSteps.first.assigneeIin, 123456789011);
    expect(document.routeSteps.first.status, WorkflowStepStatus.inProgress);
    expect(document.routeSteps.last.status, WorkflowStepStatus.pending);
  });

  test('validates workflow iin', () {
    expect(workflowIinError('123'), 'ИИН должен состоять из 12 цифр');
    expect(workflowIinError('123456789012'), isNull);
  });
}
