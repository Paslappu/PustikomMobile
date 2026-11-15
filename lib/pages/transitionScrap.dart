import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:qrscan/pages/rincian_perangkat.dart';

class TransitionScrap extends StatefulWidget {
  final String url;
  final int? dbId;
  final int? idPerangkat;
  final bool isEditing;
  final String? newPerangkatName;

  const TransitionScrap({
    super.key,
    required this.url,
    this.idPerangkat,
    this.dbId,
    required this.isEditing,
    this.newPerangkatName,
  });

  @override
  State<TransitionScrap> createState() => _TransitionScrapState();
}

class _TransitionScrapState extends State<TransitionScrap> {
  InAppWebViewController? webViewController;
  String statusText = "Memuat Data...";
  int? _id;
  String? _pageLink;
  bool stats = true;

  @override
  void initState() {
    super.initState();
    if (widget.url != "") {
      _pageLink = widget.url;
    }
    if (widget.idPerangkat != null) {
      _id = widget.idPerangkat;
    }
    stats = widget.isEditing;
  }

  Future<void> _processScraping() async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      // ganti alamat data
      String jsCode = """ (function() {
        var result = {
          deviceId:"",
          deviceName: "",
          status:"",
          mapUrl: "",
          gedung:"",
          history: []
        };
        var idNameEl = document.querySelector('table.table-bordered tr:nth-child(1) td:nth-child(2)'); 
        if (idNameEl) result.deviceId = idNameEl.innerText.trim();

        var nameEl = document.querySelector('table.table-bordered tr:nth-child(2) td:nth-child(2)'); 
        if (nameEl) result.deviceName = nameEl.innerText.trim();

        var statusEl = document.querySelector('table.table-bordered tr:nth-child(4) td:nth-child(2)');
        if (statusEl) {
            result.status = statusEl.innerText.trim();
        }

        var gedungEl = document.querySelector('table.table-bordered tr:nth-child(3) td:nth-child(2)'); 
        if (gedungEl) result.gedung = gedungEl.innerText.trim();

        var modelEl = document.querySelector('model-viewer.product-3d-viewer'); 
        if (modelEl) result.model3dUrl = modelEl.src;

        var imgEl = document.querySelector('div.card-body img'); 
        if (imgEl) result.mapUrl = imgEl.src;

        var rows = document.querySelectorAll('table tbody tr');
        rows.forEach(function(row) {
          var cols = row.querySelectorAll('td');
          if (cols.length >= 3) {
            result.history.push({
              building: cols[0].innerText.trim(),
              location: cols[1].innerText.trim(),
              date: cols[2].innerText.trim()
            });
          }
        });

        return JSON.stringify(result);
      })(); """;

      var response = await webViewController?.evaluateJavascript(
        source: jsCode,
      );

      if (response != null) {
        Map<String, dynamic> data = jsonDecode(response);

        _navigateToDetails(data);
      }
    } catch (e) {
      setState(() => statusText = "Gagal mengambil data: $e");
    }
  }

  void _navigateToDetails(Map<String, dynamic> data) {
    if (!mounted) return;
    String finalName =
        (widget.newPerangkatName != null && widget.newPerangkatName!.isNotEmpty)
        ? widget.newPerangkatName!
        : (data['deviceName'] ?? "");
    print("Status Length: ${data['status'].length} + ${data['status']}");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RincianPerangkat(
          dbId: widget.dbId,
          idPerangkat: data['deviceId'] ?? widget.idPerangkat,
          isEditing: widget.isEditing,
          initialName: finalName,
          scrapedMapUrl: data['mapUrl'],
          scrapedHistory: data['history'],
          scrapedModelUrl: data['model3dUrl'],

          status: data['status'],
          originalUrl: widget.url,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 148, 175, 255),
        body: Stack(
          children: [
            SizedBox(
              height: 1,
              width: 1,
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
                onWebViewCreated: (controller) {
                  webViewController = controller;
                },
                onLoadStop: (controller, url) async {
                  await _processScraping();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 184, 202, 255),
                  borderRadius: BorderRadius.circular(20),
                ),
                height: MediaQuery.of(context).size.height - 50,
                child: Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 30),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            height: 120,
                            width: 250,
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 148, 175, 255),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  color: Color.fromARGB(255, 82, 89, 184),
                                  strokeWidth: 8,
                                ),
                                const SizedBox(height: 20),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: Text(
                                    statusText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
