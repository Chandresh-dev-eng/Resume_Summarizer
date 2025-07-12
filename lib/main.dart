import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const ResumeSummariserApp());
}

class ResumeSummariserApp extends StatelessWidget {
  const ResumeSummariserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Resume Summariser',
      home: ResumeUploader(),
    );
  }
}

class ResumeUploader extends StatefulWidget {
  const ResumeUploader({super.key});

  @override
  State<ResumeUploader> createState() => _ResumeUploaderState();
}

class _ResumeUploaderState extends State<ResumeUploader> {
  String summary = '';
  bool isLoading = false;

  Future<void> uploadResume() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      var uri = Uri.parse("http://192.168.29.148:5000/summarize");

      setState(() => isLoading = true);

      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      var response = await request.send();

      if (response.statusCode == 200) {
        var body = await response.stream.bytesToString();
        var data = jsonDecode(body);
        setState(() {
          summary = data['summary'];
          isLoading = false;
        });
      } else {
        setState(() {
          summary = "Failed to summarize resume.";
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Center(child: const Text('Resume Summariser'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 100),
            Center(
              child: ElevatedButton(
                onPressed: uploadResume,
                child: const Text('Upload Resume PDF'),
              ),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : Expanded(
              child: SingleChildScrollView(
                child: Text(
                  summary,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
