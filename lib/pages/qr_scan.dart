import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qrscan/pages/transitionScrap.dart';
import 'package:qrscan/pages/webview.dart';

class QrScan extends StatefulWidget {
  @override
  State<QrScan> createState() => _QrScanState();
}

class _QrScanState extends State<QrScan> {
  bool _isScanned = false;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      returnImage: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 219, 229, 255),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              height: MediaQuery.of(context).size.height - 100,
              width: MediaQuery.of(context).size.width - 20,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 24, 23, 23),
              ),
              child: MobileScanner(
                controller: _scannerController,
                onDetect: (capture) {
                  if (_isScanned) return;
                  final List<Barcode> barcodes = capture.barcodes;
                  final Uint8List? image = capture.image;
                  if (image != null && barcodes.isNotEmpty) {
                    setState(() {
                      _isScanned = true;
                    });
                    _scannerController?.stop();
                  }
                  if (image != null) {
                    showDialog(
                      context: context,
                      builder: (context) {
                        String url = barcodes.first.rawValue ?? "";
                        String currentLaptopIp = "https://sipp.tik.ung.ac.id";
                        if (url.contains("127.0.0.1")) {
                          url = url.replaceAll("127.0.0.1", currentLaptopIp);
                        } else if (url.contains("localhost")) {
                          url = url.replaceAll("localhost", currentLaptopIp);
                        }
                        String title = "Unknown";

                        if (url.isNotEmpty) {
                          List<String> parts = url.split("/");
                          for (int i = parts.length - 1; i >= 0; i--) {
                            if (parts[i].isNotEmpty) {
                              title = parts[i].toUpperCase();
                              break;
                            }
                          }
                        }
                        return AlertDialog(
                          constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.of(context).size.height / 2 + 133,
                          ),
                          title: Text(title),
                          content: Column(
                            children: [
                              Image(image: MemoryImage(image)),
                              SizedBox(height: 20),
                              GestureDetector(
                                onTap: () {
                                  // Navigator.push(context, MaterialPageRoute(builder: (context) => WebView(pageLink: url,id: null, status: true,)));
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TransitionScrap(
                                        url: url,
                                        idPerangkat: null,
                                        isEditing: true,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: MediaQuery.of(context).size.width / 3,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Color.fromARGB(255, 57, 84, 219),
                                    borderRadius: BorderRadius.circular(17),
                                  ),
                                  child: Center(child: Text("Rincian")),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ).then((_) {
                      _scannerController?.start();
                      setState(() {
                        _isScanned = false;
                      });
                      // _scannerController?.stop().then((_){
                      //   _scannerController?.start();
                      // });
                    });
                  }
                },
              ),
            ),
          ),
          SizedBox(height: 10),
          Container(
            height: 80,
            child: Row(
              children: [
                Container(
                  width: MediaQuery.of(context).size.width / 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 47, 68, 153),
                        Color.fromARGB(255, 78, 113, 255),
                      ],
                      begin: AlignmentGeometry.topCenter,
                      end: AlignmentGeometry.bottomCenter,
                    ),
                    border: Border(
                      right: BorderSide(
                        color: Color.fromARGB(255, 14, 27, 122),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: MediaQuery.of(context).size.width / 3,
                    height: MediaQuery.of(context).size.height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.fromARGB(255, 57, 81, 180),
                          Color.fromARGB(255, 78, 113, 255),
                          Color.fromARGB(255, 62, 90, 204),
                        ],
                        begin: AlignmentGeometry.topCenter,
                        end: AlignmentGeometry.bottomCenter,
                      ),
                    ),
                    child: SvgPicture.asset("asset/icons/Filter.svg"),
                  ),
                ),
                Container(
                  width: MediaQuery.of(context).size.width / 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 47, 68, 153),
                        Color.fromARGB(255, 78, 113, 255),
                      ],
                      begin: AlignmentGeometry.topCenter,

                      end: AlignmentGeometry.bottomCenter,
                    ),
                    border: Border(
                      left: BorderSide(
                        color: Color.fromARGB(255, 14, 27, 122),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _scannerController?.dispose();
    super.dispose();
  }
}
