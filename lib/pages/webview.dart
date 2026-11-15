import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:qrscan/pages/rincian_perangkat.dart';
// Hapus import http dan html karena tidak dipakai lagi

class WebView extends StatefulWidget {
  final String pageLink;
  final id;
  final bool status; // Sebaiknya pakai tipe data: final String? id;

  const WebView({
    super.key,
    required this.pageLink,
    required this.id,
    required this.status,
  });

  @override
  State<WebView> createState() => _WebViewState();
}

class _WebViewState extends State<WebView> {
  int? _id;
  String _nama = ""; // Variabel ini akan terisi otomatis dari web
  double _progress = 0;
  String _pageLink =
      "https://www.ruckusnetworks.com/products/wireless-access-points/r750/";
  bool stats = true;
  late InAppWebViewController inAppWebViewController;

  @override
  void initState() {
    super.initState();
    if (widget.pageLink != "") {
      _pageLink = widget.pageLink;
    }
    if (widget.id != null) {
      _id = widget.id;
    }
    stats = widget.status;
  }

  Future<void> _scrapeData() async {
    String jsCode = """
      (function() {
        var element = document.querySelector('table.table-bordered tr:nth-child(2) td:nth-child(2)');
        return element ? element.innerText.trim() : null;
      })();
    """;

    try {
      var result = await inAppWebViewController.evaluateJavascript(
        source: jsCode,
      );

      if (result != null) {
        setState(() {
          _nama = result.toString(); // "14" akan masuk ke sini
        });
        print("Scraping Berhasil: $_nama");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("ID Perangkat ditemukan: $_nama"),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print("Gagal scraping: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Color.fromARGB(255, 148, 175, 255),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 184, 202, 255),
                  borderRadius: BorderRadius.circular(20),
                ),
                height: MediaQuery.of(context).size.height - 80,
                child: Padding(
                  padding: const EdgeInsets.only(top: 30, bottom: 30),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        InAppWebView(
                          initialUrlRequest: URLRequest(url: WebUri(_pageLink)),
                          initialSettings: InAppWebViewSettings(
                            javaScriptEnabled: true,
                          ),
                          onWebViewCreated:
                              (InAppWebViewController controller) {
                                inAppWebViewController = controller;
                              },
                          onLoadStop: (controller, url) async {
                            // Saat loading stop, otomatis ambil data
                            await _scrapeData();
                          },
                          onProgressChanged:
                              (
                                InAppWebViewController controller,
                                int progress,
                              ) {
                                setState(() {
                                  _progress = progress / 100;
                                });
                              },
                        ),
                        // Loading Bar
                        _progress < 1
                            ? Container(
                                alignment: Alignment.bottomCenter,
                                child: LinearProgressIndicator(
                                  value: _progress,
                                  color: Colors.amber,
                                ),
                              )
                            : SizedBox(),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // TOMBOL KUNING (Button)
            stats == true
                ? GestureDetector(
                    onTap: () {
                      // Saat diklik, kirim _nama yang sudah terisi otomatis
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RincianPerangkat(
                            idPerangkat: _id,
                            isEditing: true,
                            initialName:
                                _nama, // Data hasil scrape dikirim ke sini
                          ),
                        ),
                      );
                    },
                    child: Align(
                      // Pakai Align biar lebih rapi di bawah tengah
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: 20,
                        ), // Naikkan sedikit
                        child: Container(
                          height: 50,
                          width: 200,
                          decoration: BoxDecoration(
                            color: Color.fromARGB(255, 255, 193, 58),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              // Sedikit bayangan biar tombol 'pop'
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            // Saya tambahkan Text agar user tahu tombol ini untuk apa
                            child: Text(
                              _nama.isEmpty
                                  ? "Loading Data..."
                                  : "Buat Catatan",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      // Saat diklik, kirim _nama yang sudah terisi otomatis
                      Navigator.pop(context);
                    },
                    child: Align(
                      // Pakai Align biar lebih rapi di bawah tengah
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: 20,
                        ), // Naikkan sedikit
                        child: Container(
                          height: 50,
                          width: 200,
                          decoration: BoxDecoration(
                            color: Color.fromARGB(255, 58, 255, 91),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              // Sedikit bayangan biar tombol 'pop'
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            // Saya tambahkan Text agar user tahu tombol ini untuk apa
                            child: Text(
                              _nama.isEmpty ? "Loading Data..." : "Kembali",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
