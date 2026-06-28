import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MaterialApp(
      home: DomainFilterApp(),
      debugShowCheckedModeBanner: false,
    ));

class DomainFilterApp extends StatefulWidget {
  const DomainFilterApp({super.key});

  @override
  State<DomainFilterApp> createState() => _DomainFilterAppState();
}

class _DomainFilterAppState extends State<DomainFilterApp> {
  List<List<dynamic>> _rawData = [];
  List<List<dynamic>> _filteredData = [];
  bool _isLoading = false;

  // ডাইনাডট স্টাইল ফিল্টার স্টেট
  bool _noNumbers = true;
  bool _noDashes = true;
  final TextEditingController _minController = TextEditingController(text: "5");
  final TextEditingController _maxController = TextEditingController(text: "6");
  final Map<String, bool> _tldFilters = {
    '.com': true,
    '.net': false,
    '.org': false,
    '.info': false,
  };

  // ১. CSV ফাইল আপলোড ও রিড করা
  Future<void> _pickAndLoadCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      try {
        final file = File(result.files.single.path!);
        final input = file.openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();

        setState(() {
          _rawData = fields;
          _applyFilters();
        });
      } catch (e) {
        _showSnackBar("ফাইলটি সঠিক CSV ফরম্যাটে নেই!");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // ২. ফিল্টারিং ইঞ্জিন লজিক
  void _applyFilters() {
    if (_rawData.isEmpty) return;

    List<List<dynamic>> tempFiltered = [];
    tempFiltered.add(_rawData[0]); // Header row

    int minLen = int.tryParse(_minController.text) ?? 0;
    int maxLen = int.tryParse(_maxController.text) ?? 99;

    List<String> activeTLDs = _tldFilters.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    for (var i = 1; i < _rawData.length; i++) {
      if (_rawData[i].isEmpty) continue;
      
      String domain = _rawData[i][0].toString().toLowerCase().trim();
      
      if (_noNumbers && RegExp(r'[0-9]').hasMatch(domain)) continue;
      if (_noDashes && domain.contains('-')) continue;

      String domainNameWithoutTLD = domain;
      String detectedTLD = "";
      
      for (var tld in _tldFilters.keys) {
        if (domain.endsWith(tld)) {
          detectedTLD = tld;
          domainNameWithoutTLD = domain.substring(0, domain.length - tld.length);
          break;
        }
      }

      if (domainNameWithoutTLD.length < minLen || domainNameWithoutTLD.length > maxLen) continue;
      if (activeTLDs.isNotEmpty && !activeTLDs.contains(detectedTLD)) continue;

      tempFiltered.add(_rawData[i]);
    }

    setState(() {
      _filteredData = tempFiltered;
    });
  }

  // ৩. ফাইনাল ফাইল এক্সপোর্ট করা
  Future<void> _exportCSV() async {
    if (_filteredData.length <= 1) {
      _showSnackBar("এক্সপোর্ট করার মতো কোনো ডোমেইন ডেটা নেই!");
      return;
    }

    if (await Permission.storage.request().isGranted || await Permission.manageExternalStorage.request().isGranted) {
      String csvData = const ListToCsvConverter().convert(_filteredData);
      
      Directory? directory = await getExternalStorageDirectory();
      String newPath = "${directory!.path}/Filtered_Domains_${DateTime.now().millisecondsSinceEpoch}.csv";
      File file = File(newPath);
      
      await file.writeAsString(csvData);
      _showSnackBar("ফাইল সফলভাবে ডাউনলোড হয়েছে:\n$newPath", isSuccess: true);
    } else {
      _showSnackBar("ফাইল সেভ করার পারমিশন দেওয়া হয়নি!");
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Domain Filter Pro'),
        backgroundColor: Colors.red[800],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickAndLoadCSV,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('র ফাইল (CSV) আপলোড করুন'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  ),
                  const SizedBox(height: 10),
                  Text('মোট ডোমেইন: ${_rawData.isEmpty ? 0 : _rawData.length - 1}'),
                  Text('ফিল্টারড ডোমেইন: ${_filteredData.isEmpty ? 0 : _filteredData.length - 1}', 
                       style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        const Text('Refine By', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        CheckboxListTile(
                          title: const Text('No Numbers'),
                          value: _noNumbers,
                          onChanged: (val) => setState(() { _noNumbers = val!; _applyFilters(); }),
                        ),
                        CheckboxListTile(
                          title: const Text('No Dashes'),
                          value: _noDashes,
                          onChanged: (val) => setState(() { _noDashes = val!; _applyFilters(); }),
                        ),
                        const Divider(),
                        const Text('Character Length', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _minController,
                                decoration: const InputDecoration(labelText: 'Min'),
                                keyboardType: TextInputType.number,
                                onChanged: (value) => _applyFilters(),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: TextField(
                                controller: _maxController,
                                decoration: const InputDecoration(labelText: 'Max'),
                                keyboardType: TextInputType.number,
                                onChanged: (value) => _applyFilters(),
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        const Text('TLD Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ..._tldFilters.keys.map((String key) {
                          return CheckboxListTile(
                            title: Text(key),
                            value: _tldFilters[key],
                            onChanged: (bool? value) {
                              setState(() {
                                _tldFilters[key] = value!;
                                _applyFilters();
                              });
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _exportCSV,
                    icon: const Icon(Icons.download),
                    label: const Text('ফাইনাল ফাইল ডাউনলোড করুন (Export CSV)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
