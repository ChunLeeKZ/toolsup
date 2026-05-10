import 'package:flutter_test/flutter_test.dart';
import 'package:toolsup/inventory_documents.dart';

void main() {
  test('inventory documents contain header and table data', () async {
    const repository = SampleInventoryDocumentRepository();

    final documents = await repository.getDocuments();

    expect(documents, isNotEmpty);
    expect(documents.first.id, isA<String>());
    expect(documents.first.documentNumber, isA<int>());
    expect(documents.first.date, isA<DateTime>());
    expect(documents.first.inventoryCompleted, isA<bool>());
    expect(documents.first.uploadedTo1c, isA<bool>());
    expect(documents.first.inventoryOfficer, isA<String>());
    expect(documents.first.inventoryOfficerIin, isA<int>());
    expect(documents.first.lines, isNotEmpty);
    expect(documents.first.lines.first.id, isA<String>());
    expect(documents.first.lines.first.lineNumber, isA<int>());
    expect(documents.first.lines.first.fixedAsset, isA<FixedAssetReference>());
    expect(documents.first.lines.first.inventoryNumber, isA<String>());
    expect(documents.first.lines.first.existsInAccounting, isA<bool>());
    expect(documents.first.lines.first.physicallyAvailable, isA<bool>());
  });

  test('inventory document can switch completion status', () async {
    const repository = SampleInventoryDocumentRepository();
    final document = (await repository.getDocuments()).first;

    final completedDocument = await repository.setInventoryCompleted(
      document: document,
      completed: true,
    );
    final continuedDocument = await repository.setInventoryCompleted(
      document: completedDocument,
      completed: false,
    );

    expect(completedDocument.inventoryCompleted, isTrue);
    expect(continuedDocument.inventoryCompleted, isFalse);
    expect(completedDocument.documentNumber, document.documentNumber);
  });

  test('inventory document line can be marked physically available', () async {
    const repository = SampleInventoryDocumentRepository();
    final document = (await repository.getDocuments()).first;
    final line = document.lines.last;

    final updatedLine = await repository.markLinePhysicallyAvailable(
      line: line,
      rawBarcodeValue: line.inventoryNumber,
    );

    expect(updatedLine.physicallyAvailable, isTrue);
    expect(updatedLine.scannedAt, isNotNull);
    expect(updatedLine.rawBarcodeValue, line.inventoryNumber);
  });

  test('extracts inventory number from qr payload variants', () {
    expect(extractInventoryNumberFromQr('INV-000219'), 'INV-000219');
    expect(
      extractInventoryNumberFromQr('{"inventoryNumber":"INV-000219"}'),
      'INV-000219',
    );
    expect(
      extractInventoryNumberFromQr('{"inventory_number":"INV-000219"}'),
      'INV-000219',
    );
    expect(
      extractInventoryNumberFromQr(
        'https://example.org/assets?inventory_number=INV-000219',
      ),
      'INV-000219',
    );
    expect(
      extractInventoryNumberFromQr('inventoryNumber=INV-000219'),
      'INV-000219',
    );
    expect(extractInventoryNumberFromQr(''), isNull);
  });
}
