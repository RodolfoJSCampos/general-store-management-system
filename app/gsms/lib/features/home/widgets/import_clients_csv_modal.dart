import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gsms/features/home/domain/models/client_base_model.dart';
import 'package:hive/hive.dart';

class ImportClientsCsvModal extends StatefulWidget {
  const ImportClientsCsvModal({super.key});

  @override
  State<ImportClientsCsvModal> createState() => _ImportClientsCsvModalState();
}

class _ImportClientsCsvModalState extends State<ImportClientsCsvModal> {
  bool _isLoading = false;
  String? _fileName;
  Uint8List? _fileBytes;
  List<String> _csvHeaders = [];
  final Map<String, String> _columnMapping = {};
  final Set<String> _confirmedFields = <String>{};

  final List<String> _requiredFields = [
    'Código',
    'Razão Social',
    'Nome Fantasia',
    'Observação',
    'Limite de Crédito',
    'Bloqueio Financeiro',
  ];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _fileName = result.files.single.name;
        _fileBytes = result.files.single.bytes;
      });
      _loadCsvHeaders();
    }
  }

  String _normalizeString(String input) {
    var str = input.toLowerCase();
    var withDia = 'áàâãéèêíìîóòôõúùûç';
    var withoutDia = 'aaaaeeeiiioooouuuc';

    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    str = str.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return str;
  }

  double _calculateJaccardSimilarity(String a, String b) {
    final normA = _normalizeString(a);
    final normB = _normalizeString(b);

    final wordsA = normA.split(' ').where((w) => w.isNotEmpty).toSet();
    final wordsB = normB.split(' ').where((w) => w.isNotEmpty).toSet();

    if (wordsA.isEmpty || wordsB.isEmpty) {
      return 0.0;
    }

    final intersection = wordsA.intersection(wordsB).length;
    final union = wordsA.union(wordsB).length;

    if (union == 0) {
      return 0.0;
    }

    return intersection / union;
  }

  Future<void> _loadCsvHeaders() async {
    if (_fileBytes == null) return;

    final bytes = _fileBytes!;
    String csvString;
    try {
      csvString = utf8.decode(bytes);
    } on FormatException {
      csvString = latin1.decode(bytes);
    }

    final firstLine = csvString.trim().split('\n').first;
    final delimiter =
        (firstLine.split(',').length > firstLine.split(';').length) ? ',' : ';';

    final fields =
        CsvToListConverter(fieldDelimiter: delimiter).convert(csvString).first;

    setState(() {
      _csvHeaders = fields.map((e) => e.toString()).toList();
      _columnMapping.clear();
      _confirmedFields.clear();

      final availableHeaders = List<String>.from(_csvHeaders);

      final List<Map<String, dynamic>> potentialMappings = [];
      for (var field in _requiredFields) {
        for (var header in availableHeaders) {
          potentialMappings.add({
            'field': field,
            'header': header,
            'score': _calculateJaccardSimilarity(field, header),
          });
        }
      }



      potentialMappings.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

      final mappedFields = <String>{};
      final mappedHeaders = <String>{};

      for (final mapping in potentialMappings) {
        final field = mapping['field'];
        final header = mapping['header'];

        if (!mappedFields.contains(field) && !mappedHeaders.contains(header)) {
          _columnMapping[field] = header;
          mappedFields.add(field);
          mappedHeaders.add(header);
        }
      }

      for (var field in _requiredFields) {
        if (!_columnMapping.containsKey(field)) {
          final remainingHeader = availableHeaders.firstWhere((h) => !mappedHeaders.contains(h), orElse: () => '');
          if (remainingHeader.isNotEmpty) {
            _columnMapping[field] = remainingHeader;
            mappedHeaders.add(remainingHeader);
          }
        }
      }
    });
  }

  double _parseDouble(String value) {
    if (value.isEmpty) {
      return 0.0;
    }
    final cleanedString = value
        .replaceAll('R\$', '')
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.');

    return double.tryParse(cleanedString) ?? 0.0;
  }

  bool _parseBool(String value) {
    final lowerValue = value.toLowerCase().trim();
    return lowerValue == 'sim' || lowerValue == 'true';
  }

    Future<void> _importData() async {
      if (_isLoading) return;
  
      setState(() {
        _isLoading = true;
      });
  
      try {
        if (_fileBytes == null) return;
  
        final box = Hive.box<ClientBaseModel>('client_base');
  
        final bytes = _fileBytes!;
        String csvString;
        try {
          csvString = utf8.decode(bytes);
        } on FormatException {
          csvString = latin1.decode(bytes);
        }
  
        final firstLine = csvString.trim().split('\n').first;
        final delimiter =
            (firstLine.split(',').length > firstLine.split(';').length) ? ',' : ';';
  
        final List<List<dynamic>> fields =
            CsvToListConverter(fieldDelimiter: delimiter).convert(csvString);
  
        if (fields.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Arquivo CSV vazio ou inválido.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
  
        final headers = fields.first.map((e) => e.toString()).toList();
        final Map<String, ClientBaseModel> clientsToPut = {};
        for (int i = 1; i < fields.length; i++) {
          final row = fields[i];
          final newClientBase = ClientBaseModel()
            ..code = row[headers.indexOf(_columnMapping['Código']!)].toString()
            ..legalName =
                row[headers.indexOf(_columnMapping['Razão Social']!)].toString()
            ..tradeName =
                row[headers.indexOf(_columnMapping['Nome Fantasia']!)].toString()
            ..notes =
                row[headers.indexOf(_columnMapping['Observação']!)].toString()
            ..creditLimit = _parseDouble(
                row[headers.indexOf(_columnMapping['Limite de Crédito']!)]
                    .toString())
            ..isBlocked = _parseBool(
                row[headers.indexOf(_columnMapping['Bloqueio Financeiro']!)]
                    .toString());
          clientsToPut[newClientBase.code] = newClientBase;
        }
  
        await box.putAll(clientsToPut);
  
        final metadataBox = await Hive.openBox('metadata');
        await metadataBox.put('client_base_last_update', DateTime.now().toIso8601String());
  
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Base de clientes importada com sucesso!'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e, s) {
        debugPrint('Error during import: $e');
        debugPrint(s.toString());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao importar: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  Widget _buildFilePickerView() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.upload_file_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Selecione um arquivo CSV',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'O arquivo deve conter as colunas: Código, Razão Social, Nome Fantasia, etc.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Selecionar Arquivo'),
                onPressed: _pickFile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _getFieldsForHeader(String header) {
    return _columnMapping.entries
        .where((entry) => entry.value == header)
        .map((entry) => entry.key)
        .toList();
  }

  Widget _buildColumnMappingView(String fileName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Arquivo Selecionado:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            ),
          ),
          child: ListTile(
            leading: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary),
            title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remover arquivo',
              onPressed: () {
                setState(() {
                  _fileName = null;
                  _fileBytes = null;
                  _csvHeaders = [];
                  _columnMapping.clear();
                  _confirmedFields.clear();
                });
              },
            ),
          ),
        ),

        if (_csvHeaders.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Confirme o mapeamento para cada campo:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'O sistema fez um mapeamento automático. Revise e confirme cada campo. A importação só será liberada após todas as confirmações e sem mapeamentos duplicados.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _requiredFields.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final field = _requiredFields[index];
              final isConfirmed = _confirmedFields.contains(field);
              final selectedHeader = _columnMapping[field];
              final fieldsForThisHeader = _getFieldsForHeader(selectedHeader!);
              final isDuplicate = fieldsForThisHeader.length > 1;

              return Card(
                elevation: isDuplicate ? 2 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isDuplicate
                        ? Colors.orange.shade300
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                color: isDuplicate ? Colors.orange.withOpacity(0.05) : Colors.transparent,
                child: ListTile(
                  title: Text(field, style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: SizedBox(
                    width: 350,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isDuplicate)
                          Tooltip(
                            message: 'A coluna "${selectedHeader}" está mapeada para:\n- ${fieldsForThisHeader.join('\n- ')}',
                            child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedHeader,
                              isDense: true,
                              items: _csvHeaders.map((header) {
                                return DropdownMenuItem<String>(
                                  value: header,
                                  child: Text(header, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _columnMapping[field] = value;
                                  _confirmedFields.add(field);
                                });
                              },
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Checkbox(
                          value: isConfirmed,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _confirmedFields.add(field);
                              } else {
                                _confirmedFields.remove(field);
                              }
                            });
                          },
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _fileName;
    
    final mappedValues = _columnMapping.values.toList();
    final uniqueMappedValues = mappedValues.toSet();
    final hasDuplicates = mappedValues.length != uniqueMappedValues.length;

    final allConfirmed = _csvHeaders.isEmpty || _confirmedFields.length == _requiredFields.length;
    final canImport = allConfirmed && !hasDuplicates;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Text(
                'Importar Base de Clientes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (fileName == null)
                  _buildFilePickerView()
                else
                  _buildColumnMappingView(fileName),

                if (_csvHeaders.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: _isLoading
                        ? Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(2.0),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_isLoading ? 'Importando...' : 'Confirmar e Importar'),
                    onPressed: canImport && !_isLoading ? _importData : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!canImport) ...[
                    const SizedBox(height: 8),
                    if (!allConfirmed)
                      Text(
                        'Confirme todos os mapeamentos para continuar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                      ),
                    if (hasDuplicates)
                      Text(
                        'Existem colunas do CSV mapeadas para mais de um campo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                  ]
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
