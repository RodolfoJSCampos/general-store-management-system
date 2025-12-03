import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:gsms/features/home/domain/models/price_base_model.dart';
import 'package:hive/hive.dart';

/// A modal dialog for importing CSV data into the Price Base.
/// It handles file selection, CSV parsing, header mapping, data parsing,
/// and saving the processed data to Hive.
class ImportCsvModal extends StatefulWidget {
  const ImportCsvModal({super.key});

  @override
  State<ImportCsvModal> createState() => _ImportCsvModalState();
}

class _ImportCsvModalState extends State<ImportCsvModal> {
  bool _isLoading = false;
  String? _fileName;
  Uint8List? _fileBytes;
  List<String> _csvHeaders = [];
  final Map<String, String> _columnMapping = {};
  final Set<String> _confirmedFields = <String>{};

  final List<String> _requiredFields = [
    'Código',
    'Descrição',
    'Marca',
    'Preço a Vista',
    'Preço a Prazo',
    'Preço 10X',
    'Preço Mínimo',
  ];

  /// Initiates the file picking process, allowing the user to select a CSV file.
  /// If a file is successfully picked, its name and byte content are stored,
  /// and the CSV headers are loaded for mapping.
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

  /// Normalizes a string by converting it to lowercase, removing common Brazilian
  /// Portuguese diacritics, and replacing non-alphanumeric characters with spaces.
  /// This is used to improve the accuracy of Jaccard similarity for header mapping.
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

  /// Calculates the Jaccard similarity coefficient between two strings.
  /// Used for automated header mapping.
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

  /// Loads and parses CSV headers from the selected file.
  /// It attempts to automatically map required fields to CSV columns based on Jaccard similarity
  /// and predefined aliases.
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
    // Determine delimiter based on which one results in more fields.
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

      // Predefined aliases for required fields to improve mapping accuracy.
      final Map<String, List<String>> requiredFieldAliases = {
        'Preço a Vista': ['preço venda 01'],
        'Preço a Prazo': ['preço venda 02'],
        'Preço 10X': ['preço venda 03'],
        'Preço Mínimo': ['preço venda 04'],
      };

      // Boost scores for alias matches.
      for (final mapping in potentialMappings) {
        final field = mapping['field'];
        if (requiredFieldAliases.containsKey(field)) {
          final normalizedHeader = _normalizeString(mapping['header']);
          if (requiredFieldAliases[field]!.contains(normalizedHeader)) {
            // Give a high score for alias matches to prioritize them.
            if (mapping['score'] < 0.9) {
                mapping['score'] = 0.9;
            }
          }
        }
      }

      // Sort potential mappings by score in descending order to prioritize best matches.
      potentialMappings.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

      final mappedFields = <String>{};
      final mappedHeaders = <String>{};

      // Assign mappings, ensuring no field or header is mapped twice.
      for (final mapping in potentialMappings) {
        final field = mapping['field'];
        final header = mapping['header'];

        if (!mappedFields.contains(field) && !mappedHeaders.contains(header)) {
          _columnMapping[field] = header;
          mappedFields.add(field);
          mappedHeaders.add(header);
        }
      }

      // Fallback for any required fields that are still unmapped.
      // Tries to assign any remaining unused header.
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

  /// Parses a price string into a double, handling currency symbols,
  /// thousand separators, and decimal separators.
  double _parsePrice(String priceString) {
    if (priceString.isEmpty) {
      return 0.0;
    }
    final cleanedString = priceString
        .replaceAll('R\$', '') // Remove currency symbol
        .trim()
        .replaceAll('.', '') // Remove thousand separator
        .replaceAll(',', '.'); // Replace decimal comma with dot

    return double.tryParse(cleanedString) ?? 0.0;
  }

  /// Imports the parsed CSV data into the Hive 'price_base' box.
  /// It also updates the 'price_base_last_update' timestamp in the 'metadata' box.
  Future<void> _importData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_fileBytes == null) return;

      final box = Hive.box<PriceBaseModel>('price_base');

      final bytes = _fileBytes!;
      String csvString;
      try {
        csvString = utf8.decode(bytes);
      } on FormatException {
        csvString = latin1.decode(bytes);
      }

      final firstLine = csvString.trim().split('\n').first;
      // Determine delimiter based on which one results in more fields.
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
      final Map<String, PriceBaseModel> pricesToPut = {};
      for (int i = 1; i < fields.length; i++) {
        final row = fields[i];
        // Create a new PriceBaseModel from the CSV row using the column mapping.
        final newPriceBase = PriceBaseModel()
          ..code = _getValueFromRow(row, headers, 'Código')
          ..description = _getValueFromRow(row, headers, 'Descrição')
          ..brand = _getValueFromRow(row, headers, 'Marca')
          ..cashPrice = _parsePrice(_getValueFromRow(row, headers, 'Preço a Vista'))
          ..installmentPrice = _parsePrice(_getValueFromRow(row, headers, 'Preço a Prazo'))
          ..tenTimesPrice = _parsePrice(_getValueFromRow(row, headers, 'Preço 10X'))
          ..minimumPrice = _parsePrice(_getValueFromRow(row, headers, 'Preço Mínimo'));
        pricesToPut[newPriceBase.code] = newPriceBase;
      }

      await box.putAll(pricesToPut);

      // Update the last update timestamp in the metadata box.
      final metadataBox = Hive.box('metadata'); // Access directly
      await metadataBox.put('price_base_last_update', DateTime.now().toIso8601String());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Base de preços importada com sucesso!'),
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

  /// Helper method to safely get a value from a CSV row based on a mapped field name.
  /// Returns an empty string if the field is not mapped or the index is out of bounds.
  String _getValueFromRow(List<dynamic> row, List<String> headers, String fieldName) {
    final headerName = _columnMapping[fieldName];
    if (headerName == null) {
      debugPrint('Warning: Field "$fieldName" is not mapped.');
      return '';
    }
    final index = headers.indexOf(headerName);
    if (index == -1 || index >= row.length) {
      debugPrint('Warning: Header "$headerName" for field "$fieldName" not found in CSV row or index out of bounds. Row length: ${row.length}');
      return '';
    }
    return row[index].toString();
  }

  /// Builds the view for picking a CSV file.
  Widget _buildFilePickerView() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer.withAlpha(51),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(102),
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
                'O arquivo deve conter as colunas: Código, Descrição, Marca, e os preços.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
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

  /// Returns a list of required fields that are mapped to the given CSV header.
  List<String> _getFieldsForHeader(String header) {
    return _columnMapping.entries
        .where((entry) => entry.value == header)
        .map((entry) => entry.key)
        .toList();
  }

  /// Builds the view that displays the selected file and allows column mapping confirmation.
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
          color: Theme.of(context).colorScheme.secondaryContainer.withAlpha(51),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(51),
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
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final field = _requiredFields[index];
              final isConfirmed = _confirmedFields.contains(field);
              final selectedHeader = _columnMapping[field];

              if (selectedHeader == null) {
                // If a required field is not mapped, display a placeholder or specific message.
                // This scenario should ideally be prevented by the mapping logic,
                // or flagged more clearly to the user.
                return Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.errorContainer.withAlpha(51),
                  child: ListTile(
                    title: Text(
                      'Campo obrigatório "$field" não mapeado.',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    trailing: const Icon(Icons.error, color: Colors.red),
                  ),
                );
              }
              final fieldsForThisHeader = _getFieldsForHeader(selectedHeader);
              final isDuplicate = fieldsForThisHeader.length > 1;

              return Card(
                elevation: isDuplicate ? 2 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isDuplicate
                        ? Colors.orange.shade300
                        : Theme.of(context).colorScheme.onSurface.withAlpha(26),
                    width: 1,
                  ),
                ),
                color: isDuplicate ? Colors.orange.withAlpha(13) : Colors.transparent,
                child: ListTile(
                  title: Text(
                    field,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1, // Ensure text stays on a single line
                    softWrap: false, // Prevent wrapping
                    overflow: TextOverflow.fade, // Apply fade effect on overflow
                  ),
                  trailing: SizedBox(
                    width: 350,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isDuplicate)
                          Tooltip(
                            message: 'A coluna "$selectedHeader" está mapeada para:\n- ${fieldsForThisHeader.join('\n- ')}',
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
                                  child: Text(
                                    header,
                                    overflow: TextOverflow.fade, // Apply fade effect on overflow
                                    softWrap: false, // Ensure text does not wrap
                                  ),
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

    // Check if all required fields are mapped and confirmed.
    final allConfirmed = _csvHeaders.isEmpty || _confirmedFields.length == _requiredFields.length;
    // The import button is enabled only if all fields are confirmed and there are no duplicate mappings.
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
                'Importar Base de Preços',
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
                  _buildFilePickerView() // Display file picker if no file is selected.
                else
                  _buildColumnMappingView(fileName), // Display column mapping if a file is selected.

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
                    // Display warnings if not all fields are confirmed or if there are duplicate mappings.
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
