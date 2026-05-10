import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';

class FixedAssetReference {
  const FixedAssetReference({required this.id, required this.name});

  final String id;
  final String name;
}

class InventoryDocumentLine {
  const InventoryDocumentLine({
    required this.id,
    required this.lineNumber,
    required this.fixedAsset,
    required this.inventoryNumber,
    required this.existsInAccounting,
    required this.physicallyAvailable,
    this.scannedAt,
    this.rawBarcodeValue,
  });

  final String id;
  final int lineNumber;
  final FixedAssetReference fixedAsset;
  final String inventoryNumber;
  final bool existsInAccounting;
  final bool physicallyAvailable;
  final DateTime? scannedAt;
  final String? rawBarcodeValue;

  InventoryDocumentLine copyWith({
    bool? physicallyAvailable,
    DateTime? scannedAt,
    String? rawBarcodeValue,
  }) {
    return InventoryDocumentLine(
      id: id,
      lineNumber: lineNumber,
      fixedAsset: fixedAsset,
      inventoryNumber: inventoryNumber,
      existsInAccounting: existsInAccounting,
      physicallyAvailable: physicallyAvailable ?? this.physicallyAvailable,
      scannedAt: scannedAt ?? this.scannedAt,
      rawBarcodeValue: rawBarcodeValue ?? this.rawBarcodeValue,
    );
  }
}

class InventoryDocument {
  const InventoryDocument({
    required this.id,
    required this.date,
    required this.documentNumber,
    required this.inventoryCompleted,
    required this.uploadedTo1c,
    required this.inventoryOfficer,
    required this.inventoryOfficerIin,
    required this.lines,
  });

  final String id;
  final DateTime date;
  final int documentNumber;
  final bool inventoryCompleted;
  final bool uploadedTo1c;
  final String inventoryOfficer;
  final int inventoryOfficerIin;
  final List<InventoryDocumentLine> lines;

  InventoryDocument copyWith({
    bool? inventoryCompleted,
    bool? uploadedTo1c,
    List<InventoryDocumentLine>? lines,
  }) {
    return InventoryDocument(
      id: id,
      date: date,
      documentNumber: documentNumber,
      inventoryCompleted: inventoryCompleted ?? this.inventoryCompleted,
      uploadedTo1c: uploadedTo1c ?? this.uploadedTo1c,
      inventoryOfficer: inventoryOfficer,
      inventoryOfficerIin: inventoryOfficerIin,
      lines: lines ?? this.lines,
    );
  }
}

abstract interface class InventoryDocumentRepository {
  Future<List<InventoryDocument>> getDocuments();

  Future<InventoryDocument> setInventoryCompleted({
    required InventoryDocument document,
    required bool completed,
  });

  Future<InventoryDocumentLine> markLinePhysicallyAvailable({
    required InventoryDocumentLine line,
    required String rawBarcodeValue,
  });
}

class SupabaseInventoryDocumentRepository
    implements InventoryDocumentRepository {
  const SupabaseInventoryDocumentRepository();

  static const _documentsTable = 'inventory_documents';
  static const _linesTable = 'inventory_document_lines';
  static const _documentSelect = '''
id,
date,
document_number,
inventory_completed,
uploaded_to_1c,
inventory_officer,
inventory_officer_iin,
inventory_document_lines (
  id,
  line_number,
  fixed_asset_id,
  fixed_asset_name,
  inventory_number,
  exists_in_accounting,
  physically_available,
  scanned_at,
  raw_barcode_value
)
''';
  static const _lineSelect = '''
id,
line_number,
fixed_asset_id,
fixed_asset_name,
inventory_number,
exists_in_accounting,
physically_available,
scanned_at,
raw_barcode_value
''';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<InventoryDocument>> getDocuments() async {
    final rows = await _client
        .from(_documentsTable)
        .select(_documentSelect)
        .order('date', ascending: false)
        .order('document_number', ascending: false);

    return rows.map(_documentFromRow).toList();
  }

  @override
  Future<InventoryDocument> setInventoryCompleted({
    required InventoryDocument document,
    required bool completed,
  }) async {
    await _client
        .from(_documentsTable)
        .update({'inventory_completed': completed})
        .eq('id', document.id);

    return document.copyWith(inventoryCompleted: completed);
  }

  @override
  Future<InventoryDocumentLine> markLinePhysicallyAvailable({
    required InventoryDocumentLine line,
    required String rawBarcodeValue,
  }) async {
    final scannedAt = DateTime.now().toUtc();
    final row = await _client
        .from(_linesTable)
        .update({
          'physically_available': true,
          'scanned_at': scannedAt.toIso8601String(),
          'raw_barcode_value': rawBarcodeValue,
        })
        .eq('id', line.id)
        .select(_lineSelect)
        .single();

    return _lineFromRow(row);
  }
}

class SampleInventoryDocumentRepository implements InventoryDocumentRepository {
  const SampleInventoryDocumentRepository();

  @override
  Future<List<InventoryDocument>> getDocuments() async {
    return [
      InventoryDocument(
        id: 'sample-document-1001',
        date: DateTime(2026, 5, 9),
        documentNumber: 1001,
        inventoryCompleted: false,
        uploadedTo1c: false,
        inventoryOfficer: 'Касымов Ерлан',
        inventoryOfficerIin: 860101300123,
        lines: [
          InventoryDocumentLine(
            id: 'sample-line-1001-1',
            lineNumber: 1,
            fixedAsset: FixedAssetReference(
              id: 'fa-001',
              name: 'Ноутбук Lenovo ThinkPad',
            ),
            inventoryNumber: 'INV-000124',
            existsInAccounting: true,
            physicallyAvailable: true,
          ),
          InventoryDocumentLine(
            id: 'sample-line-1001-2',
            lineNumber: 2,
            fixedAsset: FixedAssetReference(
              id: 'fa-002',
              name: 'Принтер HP LaserJet',
            ),
            inventoryNumber: 'INV-000219',
            existsInAccounting: true,
            physicallyAvailable: false,
          ),
        ],
      ),
      InventoryDocument(
        id: 'sample-document-1002',
        date: DateTime(2026, 5, 7),
        documentNumber: 1002,
        inventoryCompleted: true,
        uploadedTo1c: false,
        inventoryOfficer: 'Ахметова Дина',
        inventoryOfficerIin: 910215450678,
        lines: [
          InventoryDocumentLine(
            id: 'sample-line-1002-1',
            lineNumber: 1,
            fixedAsset: FixedAssetReference(
              id: 'fa-003',
              name: 'Монитор Dell 24',
            ),
            inventoryNumber: 'INV-000301',
            existsInAccounting: true,
            physicallyAvailable: true,
          ),
        ],
      ),
      InventoryDocument(
        id: 'sample-document-1003',
        date: DateTime(2026, 5, 3),
        documentNumber: 1003,
        inventoryCompleted: true,
        uploadedTo1c: true,
        inventoryOfficer: 'Серикбаев Нурлан',
        inventoryOfficerIin: 800930350456,
        lines: [
          InventoryDocumentLine(
            id: 'sample-line-1003-1',
            lineNumber: 1,
            fixedAsset: FixedAssetReference(
              id: 'fa-004',
              name: 'Сервер Dell PowerEdge',
            ),
            inventoryNumber: 'INV-000410',
            existsInAccounting: true,
            physicallyAvailable: true,
          ),
          InventoryDocumentLine(
            id: 'sample-line-1003-2',
            lineNumber: 2,
            fixedAsset: FixedAssetReference(
              id: 'fa-005',
              name: 'Шкаф телекоммуникационный',
            ),
            inventoryNumber: 'INV-000411',
            existsInAccounting: true,
            physicallyAvailable: true,
          ),
        ],
      ),
    ];
  }

  @override
  Future<InventoryDocument> setInventoryCompleted({
    required InventoryDocument document,
    required bool completed,
  }) async {
    return document.copyWith(inventoryCompleted: completed);
  }

  @override
  Future<InventoryDocumentLine> markLinePhysicallyAvailable({
    required InventoryDocumentLine line,
    required String rawBarcodeValue,
  }) async {
    return line.copyWith(
      physicallyAvailable: true,
      scannedAt: DateTime.now(),
      rawBarcodeValue: rawBarcodeValue,
    );
  }
}

InventoryDocument _documentFromRow(Map<String, dynamic> row) {
  final rawLines = row['inventory_document_lines'];
  final lines = rawLines is List
      ? rawLines
            .map((rawLine) => _lineFromRow(Map<String, dynamic>.from(rawLine)))
            .toList()
      : <InventoryDocumentLine>[];

  lines.sort((a, b) => a.lineNumber.compareTo(b.lineNumber));

  return InventoryDocument(
    id: _asString(row['id']),
    date: _asDate(row['date']),
    documentNumber: _asInt(row['document_number']),
    inventoryCompleted: _asBool(row['inventory_completed']),
    uploadedTo1c: _asBool(row['uploaded_to_1c']),
    inventoryOfficer: _asString(row['inventory_officer']),
    inventoryOfficerIin: _asInt(row['inventory_officer_iin']),
    lines: lines,
  );
}

InventoryDocumentLine _lineFromRow(Map<String, dynamic> row) {
  return InventoryDocumentLine(
    id: _asString(row['id']),
    lineNumber: _asInt(row['line_number']),
    fixedAsset: FixedAssetReference(
      id: _asString(row['fixed_asset_id']),
      name: _asString(row['fixed_asset_name']),
    ),
    inventoryNumber: _asString(row['inventory_number']),
    existsInAccounting: _asBool(row['exists_in_accounting']),
    physicallyAvailable: _asBool(row['physically_available']),
    scannedAt: _asNullableDateTime(row['scanned_at']),
    rawBarcodeValue: row['raw_barcode_value']?.toString(),
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

bool _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  return value.toString().toLowerCase() == 'true';
}

DateTime _asDate(Object? value) {
  return DateTime.parse(value.toString());
}

DateTime? _asNullableDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  final rawValue = value.toString();
  if (rawValue.isEmpty) {
    return null;
  }
  return DateTime.parse(rawValue).toLocal();
}

class InventoryDocumentsPage extends StatefulWidget {
  const InventoryDocumentsPage({
    this.repository = const SupabaseInventoryDocumentRepository(),
    super.key,
  });

  final InventoryDocumentRepository repository;

  @override
  State<InventoryDocumentsPage> createState() => _InventoryDocumentsPageState();
}

class _InventoryDocumentsPageState extends State<InventoryDocumentsPage> {
  var _documents = <InventoryDocument>[];
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

  Future<void> _openDocument(int index) async {
    final updatedDocument = await Navigator.of(context).push<InventoryDocument>(
      MaterialPageRoute<InventoryDocument>(
        builder: (context) => InventoryDocumentDetailsPage(
          document: _documents[index],
          repository: widget.repository,
        ),
      ),
    );

    if (updatedDocument == null || !mounted) {
      return;
    }

    setState(() {
      final documentIndex = _documents.indexWhere(
        (document) => document.id == updatedDocument.id,
      );
      if (documentIndex == -1) {
        return;
      }
      _documents[documentIndex] = updatedDocument;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Инвентаризации основных средств')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return _InventoryLoadError(message: _loadError!, onRetry: _loadDocuments);
    }

    if (_documents.isEmpty) {
      return const Center(child: Text('Документы инвентаризации не найдены'));
    }

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _documents.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final document = _documents[index];
          return _InventoryDocumentCard(
            document: document,
            onTap: () => _openDocument(index),
          );
        },
      ),
    );
  }
}

class _InventoryLoadError extends StatelessWidget {
  const _InventoryLoadError({required this.message, required this.onRetry});

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

class _InventoryDocumentCard extends StatelessWidget {
  const _InventoryDocumentCard({required this.document, required this.onTap});

  final InventoryDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
                  Icon(Icons.description_outlined, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Документ N ${document.documentNumber}',
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
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    label: document.inventoryCompleted
                        ? 'Инвентаризация завершена'
                        : 'Инвентаризация не завершена',
                    active: document.inventoryCompleted,
                  ),
                  _StatusChip(
                    label: document.uploadedTo1c
                        ? 'Выгружено в 1С'
                        : 'Не выгружено в 1С',
                    active: document.uploadedTo1c,
                  ),
                ],
              ),
              const Divider(height: 24),
              _DocumentField(label: 'Дата', value: _formatDate(document.date)),
              _DocumentField(
                label: 'Инвентаризирующий',
                value: document.inventoryOfficer,
              ),
              _DocumentField(
                label: 'ИИН инвентаризирующего',
                value: document.inventoryOfficerIin.toString(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InventoryDocumentDetailsPage extends StatefulWidget {
  const InventoryDocumentDetailsPage({
    required this.document,
    required this.repository,
    super.key,
  });

  final InventoryDocument document;
  final InventoryDocumentRepository repository;

  @override
  State<InventoryDocumentDetailsPage> createState() =>
      _InventoryDocumentDetailsPageState();
}

class _InventoryDocumentDetailsPageState
    extends State<InventoryDocumentDetailsPage> {
  String? _scanMessage;
  bool _scanSucceeded = false;
  bool _isSavingScan = false;
  bool _isUpdatingDocument = false;
  late InventoryDocument _document = widget.document;

  void _closeDocument() {
    Navigator.of(context).pop(_document);
  }

  Future<void> _setInventoryCompleted(bool completed) async {
    setState(() {
      _isUpdatingDocument = true;
      _scanMessage = null;
      _scanSucceeded = false;
    });

    try {
      final updatedDocument = await widget.repository.setInventoryCompleted(
        document: _document,
        completed: completed,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _document = updatedDocument;
        _scanMessage = completed
            ? 'Инвентаризация завершена.'
            : 'Инвентаризация снова открыта для продолжения работы.';
        _scanSucceeded = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scanMessage = 'Не удалось обновить документ: $error';
        _scanSucceeded = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingDocument = false;
        });
      }
    }
  }

  Future<void> _scanAssetPresence() async {
    setState(() {
      _scanMessage = null;
      _scanSucceeded = false;
    });

    final rawQrValue = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (context) => const QrScannerPage()),
    );

    if (rawQrValue == null || rawQrValue.trim().isEmpty || !mounted) {
      return;
    }

    final inventoryNumber = extractInventoryNumberFromQr(rawQrValue);
    if (inventoryNumber == null) {
      setState(() {
        _scanMessage = 'Штрихкод не содержит инвентарный номер.';
        _scanSucceeded = false;
      });
      return;
    }

    InventoryDocumentLine? matchedLine;
    for (final line in _document.lines) {
      if (line.inventoryNumber.toLowerCase() == inventoryNumber.toLowerCase()) {
        matchedLine = line;
        break;
      }
    }

    if (matchedLine == null) {
      setState(() {
        _scanMessage =
            'Инвентарный номер $inventoryNumber не найден в текущем документе.';
        _scanSucceeded = false;
      });
      return;
    }

    setState(() {
      _isSavingScan = true;
    });

    try {
      final updatedLine = await widget.repository.markLinePhysicallyAvailable(
        line: matchedLine,
        rawBarcodeValue: rawQrValue,
      );
      if (!mounted) {
        return;
      }
      final updatedLines = _document.lines
          .map((line) => line.id == updatedLine.id ? updatedLine : line)
          .toList();
      setState(() {
        _document = _document.copyWith(lines: updatedLines);
        _scanMessage =
            'Основное средство "${matchedLine!.fixedAsset.name}" отмечено как фактически имеющееся.';
        _scanSucceeded = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scanMessage = 'Не удалось сохранить отметку наличия: $error';
        _scanSucceeded = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSavingScan = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final document = _document;
    final busy = _isSavingScan || _isUpdatingDocument;

    return Scaffold(
      appBar: AppBar(
        title: Text('Документ N ${document.documentNumber}'),
        leading: BackButton(onPressed: _closeDocument),
      ),
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
                      'Реквизиты документа',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DocumentField(
                      label: 'Дата',
                      value: _formatDate(document.date),
                    ),
                    _DocumentField(
                      label: 'Номер документа',
                      value: document.documentNumber.toString(),
                    ),
                    _DocumentField(
                      label: 'Инвентаризация завершена',
                      value: _formatBool(document.inventoryCompleted),
                    ),
                    _DocumentField(
                      label: 'Данные выгружены в 1С',
                      value: _formatBool(document.uploadedTo1c),
                    ),
                    _DocumentField(
                      label: 'Инвентаризирующий',
                      value: document.inventoryOfficer,
                    ),
                    _DocumentField(
                      label: 'ИИН инвентаризирующего',
                      value: document.inventoryOfficerIin.toString(),
                    ),
                    const SizedBox(height: 8),
                    if (!document.inventoryCompleted) ...[
                      FilledButton.icon(
                        onPressed: busy ? null : _scanAssetPresence,
                        icon: const Icon(Icons.qr_code_scanner_outlined),
                        label: const Text('Отметить наличие через камеру'),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => _setInventoryCompleted(true),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Завершить инвентаризацию'),
                      ),
                    ] else
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _setInventoryCompleted(false),
                        icon: const Icon(Icons.edit_note_outlined),
                        label: const Text('Продолжить инвентаризацию'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Основные средства',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (_scanMessage != null) ...[
              _ScanMessageBox(message: _scanMessage!, success: _scanSucceeded),
              const SizedBox(height: 12),
            ],
            ...document.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _InventoryDocumentLineCard(line: line),
              ),
            ),
            if (document.lines.isEmpty)
              Text(
                'Табличная часть не заполнена',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _InventoryDocumentLineCard extends StatelessWidget {
  const _InventoryDocumentLineCard({required this.line});

  final InventoryDocumentLine line;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${line.lineNumber}. ${line.fixedAsset.name}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _DocumentField(
              label: 'Инвентарный номер',
              value: line.inventoryNumber,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  label: line.existsInAccounting
                      ? 'Есть в бухучете'
                      : 'Нет в бухучете',
                  active: line.existsInAccounting,
                ),
                _StatusChip(
                  label: line.physicallyAvailable
                      ? 'Фактически есть'
                      : 'Фактически отсутствует',
                  active: line.physicallyAvailable,
                ),
                if (line.scannedAt != null)
                  const _StatusChip(label: 'Код отсканирован', active: true),
              ],
            ),
            if (line.scannedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Отмечено сканированием кода: ${_formatDateTime(line.scannedAt!)}',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanMessageBox extends StatelessWidget {
  const _ScanMessageBox({required this.message, required this.success});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: success ? colors.secondaryContainer : colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(
            color: success
                ? colors.onSecondaryContainer
                : colors.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.all],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  var _completed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_completed) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();
      if (rawValue == null || rawValue.isEmpty) {
        continue;
      }

      _completed = true;
      _controller.stop();
      Navigator.of(context).pop(rawValue);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Сканирование кода')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Не удалось открыть камеру: ${error.errorCode}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: ToolsupPalette.ink.withValues(alpha: 0.82),
              child: Text(
                'Наведите камеру на штрихкод или QR-код основного средства',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: colors.primary, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentField extends StatelessWidget {
  const _DocumentField({required this.label, required this.value});

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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});

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

String _formatBool(bool value) {
  return value ? 'Да' : 'Нет';
}

String? extractInventoryNumberFromQr(String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) {
    return null;
  }

  final jsonInventoryNumber = _extractInventoryNumberFromJson(value);
  if (jsonInventoryNumber != null) {
    return jsonInventoryNumber;
  }

  final uriInventoryNumber = _extractInventoryNumberFromUri(value);
  if (uriInventoryNumber != null) {
    return uriInventoryNumber;
  }

  final keyValueMatch = RegExp(
    r'(inventoryNumber|inventory_number|inventoryNo|inv|инвентарный номер)\s*[:=]\s*([A-Za-zА-Яа-я0-9._/\-]+)',
    caseSensitive: false,
  ).firstMatch(value);
  if (keyValueMatch != null) {
    return keyValueMatch.group(2);
  }

  return value;
}

String? _extractInventoryNumberFromJson(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is String) {
      return extractInventoryNumberFromQr(decoded);
    }
    if (decoded is Map<String, dynamic>) {
      for (final key in const [
        'inventoryNumber',
        'inventory_number',
        'inventoryNo',
        'inv',
        'number',
      ]) {
        final rawInventoryNumber = decoded[key]?.toString().trim();
        if (rawInventoryNumber != null && rawInventoryNumber.isNotEmpty) {
          return rawInventoryNumber;
        }
      }
    }
  } catch (_) {
    return null;
  }

  return null;
}

String? _extractInventoryNumberFromUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) {
    return null;
  }

  for (final key in const [
    'inventoryNumber',
    'inventory_number',
    'inventoryNo',
    'inv',
    'number',
  ]) {
    final rawInventoryNumber = uri.queryParameters[key]?.trim();
    if (rawInventoryNumber != null && rawInventoryNumber.isNotEmpty) {
      return rawInventoryNumber;
    }
  }

  if (uri.pathSegments.isNotEmpty) {
    final lastSegment = uri.pathSegments.last.trim();
    if (lastSegment.isNotEmpty) {
      return lastSegment;
    }
  }

  return null;
}
