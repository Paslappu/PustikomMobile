import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:qrscan/models/perangkat_model.dart'; // Pastikan import model ada
import 'package:qrscan/pages/qr_scan.dart';
import 'package:qrscan/pages/riwayat.dart';
import 'package:qrscan/services/database_service.dart'; // Pastikan import database ada

class BaseHome extends StatefulWidget {
  BaseHome({super.key});

  @override
  State<BaseHome> createState() => _BaseHomeState();
}

class _BaseHomeState extends State<BaseHome> {
  // Menggunakan PerangkatModel dan DatabaseService
  final DatabaseService databaseService = DatabaseService.instance;
  List<PerangkatModel> recentPerangkats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Fungsi untuk mengambil data dari Database
  Future<void> _loadData() async {
    try {
      final data = await databaseService.getPerangkat();
      setState(() {
        recentPerangkats = data;
        // Urutkan dari ID terbesar (terbaru) ke terkecil
        recentPerangkats.sort((a, b) => b.id.compareTo(a.id)); 
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      print("Error loading data: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 148, 175, 255),
      body: ListView(
        children: [
          SizedBox(height: 30),
          notesHistory(), // Widget List Catatan Terakhir
          SizedBox(height: 40),
          
          // --- Bagian Tombol Navigasi Bawah ---
          Padding(
            padding: const EdgeInsets.only(left: 40, right: 40),
            child: Container(
              height: 534 / 2,
              width: 10,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: AlignmentGeometry.topLeft,
                      end: AlignmentGeometry.bottomRight,
                      colors: [
                        Color.fromARGB(255, 148, 175, 255),
                        Color.fromARGB(255, 208, 214, 233)
                      ]),
                  borderRadius: BorderRadius.circular(39)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => QrScan()));
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10),
                      child: Container(
                        height: 240 / 2,
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 78, 113, 255),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Stack(
                              children: [
                                Text(
                                  "Scan",
                                  style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w600,
                                      height: 1,
                                      color: Colors.white),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    "QR",
                                    style: TextStyle(
                                        fontSize: 80 - 23,
                                        fontWeight: FontWeight.bold,
                                        height: 0,
                                        color: Colors.white),
                                  ),
                                )
                              ],
                            ),
                            SvgPicture.asset("asset/icons/qr-reader-svgrepo-com.svg"),
                          ],
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => Riwayatpage()));
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
                      child: Container(
                        height: 240 / 2,
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 78, 113, 255),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Stack(
                              children: [
                                Text(
                                  "Riwayat",
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w600,
                                      height: 1,
                                      color: Colors.white),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 15),
                                  child: Text(
                                    "Catatan",
                                    style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                        height: 0,
                                        color: Colors.white),
                                  ),
                                )
                              ],
                            ),
                            SvgPicture.asset("asset/icons/history-svgrepo-com (1).svg", width: 120,),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Container notesHistory() {
    return Container(
      height: 430,
      child: Stack(
        alignment: AlignmentGeometry.topCenter,
        children: [
          // Background Card (Biru Gradasi)
          Container(
            alignment: const Alignment(0, 1.3),
            child: Stack(
              alignment: AlignmentGeometry.center,
              children: [
                Container(
                  height: 400,
                  width: 370,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: AlignmentGeometry.topCenter,
                        end: AlignmentGeometry.bottomRight,
                        colors: [
                          Color.fromARGB(255, 184, 202, 255),
                          Color.fromARGB(255, 110, 121, 153)
                        ]),
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                
                // Foreground Card (Putih) - Tempat List
                Container(
                  height: 400 - 12,
                  width: 370 - 12,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(
                        top: 35, left: 10, right: 10, bottom: 10),
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : recentPerangkats.isEmpty
                            ? Center(child: Text("Belum ada catatan terbaru"))
                            : ListView.separated(
                                itemBuilder: (context, index) {
                                  // --- ITEM LIST (Style Riwayat) ---
                                  return Container(
                                    height: 60,
                                    decoration: BoxDecoration(
                                      // Warna background sesuai RiwayatPage
                                      color: Color.fromARGB(99, 144, 172, 255),
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 10, right: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          // Icon Honey Pancakes
                                          SvgPicture.asset(
                                            "asset/icons/router-5-svgrepo-com.svg",
                                            width: 60, // Sedikit diperkecil agar muat di kotak kecil
                                          ),
                                          SizedBox(width: 15),
                                          
                                          // Kolom Teks
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Nama Perangkat (AutoSizeText)
                                                AutoSizeText(
                                                  recentPerangkats[index].nama,
                                                  maxLines: 1,
                                                  minFontSize: 10,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                
                                                // Detail (Tanggal | Gedung | Port)
                                                Text(
                                                  recentPerangkats[index].tanggal +
                                                      " | " +
                                                      recentPerangkats[index].gedung +
                                                      " | " +
                                                      recentPerangkats[index].port.toString(),
                                                  style: TextStyle(fontSize: 12),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                )
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                separatorBuilder: (context, index) =>
                                    SizedBox(height: 12),
                                itemCount: recentPerangkats.length),
                  ),
                ),
              ],
            ),
          ),
          
          // Header "Catatan Terakhir"
          Container(
            height: 150 / 2,
            width: 304 / 2,
            decoration: BoxDecoration(
                color: Color.fromARGB(255, 184, 202, 255),
                borderRadius: BorderRadius.circular(17)),
            child: Center(
              child: Text(
                "Catatan\nTerakhir",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 52 / 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}