// import 'package:auto_size_text/auto_size_text.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:qrscan/models/perangkat_model.dart';
// import 'package:qrscan/pages/base.dart';
// import 'package:qrscan/pages/riwayat.dart';
// import 'package:qrscan/pages/webview.dart';
// import 'package:qrscan/services/database_service.dart';

// class RincianPerangkat extends StatefulWidget{
//   final idPerangkat ;
//   final bool isEditing;
//   final String? newPerangkatName;
//   final String? scrapedMapUrl;
//   final List<dynamic>? scrapedHistory;
//   final String? originalUrl;
//   const RincianPerangkat({super.key, required this.idPerangkat, required this.isEditing, this.newPerangkatName, this.originalUrl, this.scrapedHistory, this.scrapedMapUrl});

//   @override
//   State<RincianPerangkat> createState() => _RincianPerangkatState();
// }

// class _RincianPerangkatState extends State<RincianPerangkat> {
//   final DatabaseService databaseService = DatabaseService.instance;
//   bool isEdit = false;
//   int indexPerangkat = 0;
//   PerangkatModel? perangkat;
//   late TextEditingController _namaController;
//   late TextEditingController _tanggalController;
//   late TextEditingController _gedungController;
//   late TextEditingController _portController;

//   @override
//   void initState() {
//     super.initState();
//     // Initialize controllers with current values
//     if (widget.idPerangkat == null) {
//       // NEW ENTRY: Initialize with empty or default values
//       _namaController = TextEditingController(text: widget.newPerangkatName);
//       _tanggalController = TextEditingController(text: DateTime.now().toString().split(' ')[0]);
//       _gedungController = TextEditingController();
//       _portController = TextEditingController();
//       isEdit = true; // Start in edit mode for new entries
//     } else {
//       // EXISTING ENTRY: Initialize with current values (will be set in FutureBuilder)
//       _namaController = TextEditingController();
//       _tanggalController = TextEditingController();
//       _gedungController = TextEditingController();
//       _portController = TextEditingController();
//       isEdit = widget.isEditing;
//     }
//     isEdit = widget.isEditing;
//   }
  
//   @override
//   void dispose() {
//     // Clean up controllers
//     _namaController.dispose();
//     _tanggalController.dispose();
//     _gedungController.dispose();
//     _portController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Color.fromARGB(255, 219, 229, 255),
//       body: Stack(
//         children: [
          
//           ListView(
//             children: [
//               Stack(
//                 children: [
//                   gradientBG(context),
//                   perangkatViewer(context),
                  
//                   Padding(
//                     padding: const EdgeInsets.only(top: 90, left: 40, right: 40),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           "Detail Perangkat",
//                           style: TextStyle(
//                             fontSize: 40/2,
//                             fontWeight: FontWeight.bold
//                           ),
//                         ),
//                         SizedBox(height: 10,),
//                         Container(
//                           width: MediaQuery.of(context).size.width,
//                           padding: EdgeInsets.only(left: 5, right: 5),
//                           decoration: BoxDecoration(
//                             color: Color.fromARGB(132, 184, 202, 255),
//                             border: Border.all(
//                               color: Colors.white,
//                               width: 3.0
//                             ),
//                             borderRadius: BorderRadius.circular(17)
//                           ),
//                           child: detailPerangkat(),
//                         ),
//                         SizedBox(height: 10,),
//                         Center(
//                           child: Text(
//                             "Lokasi Perangkat",
//                             style: TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.bold
//                             ),
//                           ),
//                         ),
//                         SizedBox(height: 10,),
//                         // lokasiPerangkat(),
//                         SizedBox(height: 10,),
//                         Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               "Catatan",
//                               style: TextStyle(
//                                 fontSize: 20,
//                                 fontWeight: FontWeight.bold
//                               ),
//                             ),
//                             SizedBox(height: 10,),
//                             Container(
//                               height: 400,
//                               width: 500,
//                               padding: EdgeInsets.all(10),
//                               decoration: BoxDecoration(
//                                 color: Color.fromARGB(113, 122, 151, 255),
//                                 borderRadius: BorderRadius.circular(17)
//                               ),
//                               child: !isEdit?
//                               listDataPerangkat() : Container(
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     TextField(
//                                       controller: _namaController,
//                                       decoration: InputDecoration(
//                                         labelText: "Nama Perangkat"
//                                       ),
//                                     ),
//                                     TextField(
//                                       controller: _tanggalController,
//                                       decoration: InputDecoration(
//                                         labelText: "Tanggal Catatan"
//                                       ),
//                                     ),
//                                     TextField(
//                                       controller: _gedungController,
//                                       decoration: InputDecoration(
//                                         labelText: "Gedung Perangkat"
//                                       ),
//                                     ),
//                                     TextField(
//                                       controller: _portController,
//                                       decoration: InputDecoration(
//                                         labelText: "Port Berfungsi"
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             )
//                           ],
//                         ),
//                         SizedBox(height: 80,),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
              
//             ],
//           ),
//           GestureDetector(
//             onTap: () {
//               Navigator.push(context, MaterialPageRoute(builder: (context) => BaseHome()));
//             },
//             child: Padding(
//               padding: const EdgeInsets.only(top: 30, left: 20),
//               child: Container(
//                 height: 55,
//                 width: 110,
//                 decoration: BoxDecoration(
//                   color: Color.fromARGB(255, 184, 202, 255),
//                   borderRadius: BorderRadius.circular(17),
//                   border: Border.all(
//                     color: const Color.fromARGB(255, 255, 255, 255),
//                     width: 2
//                   )
//                 ),
//                 child: SvgPicture.asset("asset/icons/Arrow - Left 2.svg", width: 60),
                
//               ),
//             ),
//           ),
//           !isEdit?
//           editButton(context):
//           Container(
//             height: MediaQuery.of(context).size.height,
//             alignment: Alignment.bottomRight,
//             child: Padding(
//               padding: const EdgeInsets.only(bottom: 10, right: 20),
//               child: GestureDetector(
//                 onTap: () {
//                   // 1. VALIDATION: Check if fields are empty
//                   if (_namaController.text.isNotEmpty &&
//                       _tanggalController.text.isNotEmpty &&
//                       _gedungController.text.isNotEmpty &&
//                       _portController.text.isNotEmpty) {
                    
//                     // 2. SHOW CONFIRMATION DIALOG
//                     showDialog(
//                       context: context,
//                       builder: (BuildContext context) {
//                         return AlertDialog(
//                           title: Text("Konfirmasi"),
//                           content: Text("Apakah Anda yakin ingin menyimpan data ini?"),
//                           actions: [
//                             // BUTTON: BATAL
//                             TextButton(
//                               onPressed: () {
//                                 Navigator.of(context).pop(); // Close dialog only
//                               },
//                               child: Text("Batal", style: TextStyle(color: Colors.red)),
//                             ),

//                             // BUTTON: YA (SIMPAN)
//                             TextButton(
//                               onPressed: () async {
//                                 // A. Close the dialog first
//                                 Navigator.of(context).pop();

//                                 // B. Check: Update or New Data?
//                                 if (perangkat?.id != null) {
//                                   final updatedPerangkat = PerangkatModel(
//                                     id: perangkat!.id,
//                                     nama: _namaController.text,
//                                     tanggal: _tanggalController.text,
//                                     gedung: _gedungController.text,
//                                     port: int.parse(_portController.text),
//                                   );
//                                   await databaseService.updatePerangkat(updatedPerangkat);
//                                 } else {
//                                   await databaseService.addPerangkat(
//                                     _namaController.text,
//                                     _tanggalController.text,
//                                     _gedungController.text,
//                                     _portController.text,
//                                   );
//                                 }
//                                 setState(() {
//                                   isEdit = false;
//                                 });
//                                 ScaffoldMessenger.of(context).showSnackBar(
//                                   SnackBar(
//                                     content: Text("Data berhasil disimpan!"),
//                                     duration: Duration(seconds: 1),
//                                   ),
//                                 );
//                                 Navigator.push(context, MaterialPageRoute(builder: (context) => BaseHome()));
//                               },
//                               child: Text("Ya, Simpan", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
//                             ),
//                           ],
//                         );
//                       },
//                     );

//                   } else {
//                     showDialog(
//                       context: context,
//                       builder: (context) {
//                         return AlertDialog(
//                           title: Text("Error"),
//                           content: Text("Pastikan Tidak Ada Data Kosong"),
//                           actions: [
//                             TextButton(
//                               onPressed: () => Navigator.pop(context),
//                               child: Text("OK"),
//                             )
//                           ],
//                         );
//                       },
//                     );
//                   }
//                 },
//                 child: SaveButton(context),
//               ),
//             ),
//           )
//         ],
//       )
//     );
//   }

//   Row SaveButton(BuildContext context) {
//     return Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Container(
//                     height: MediaQuery.of(context).size.height,
//                     alignment: Alignment.bottomRight,
//                     child: Padding(
//                       padding: const EdgeInsets.only(bottom: 10, right: 90, left: 20),
//                       child: GestureDetector(
//                         onTap: () {
//                           Navigator.push(context, MaterialPageRoute(builder: (context) => WebView(pageLink: "",id: widget.idPerangkat,status: false,)));
//                         },
//                         child: Container(
//                           height: 60,
                          
//                           width: MediaQuery.of(context).size.width/3,
//                           decoration: BoxDecoration(
//                             color: const Color.fromARGB(255, 7, 226, 255),
//                             borderRadius: BorderRadius.circular(17),
//                             border: Border.all(
//                               color: Colors.white,
//                               width: 2
//                             )
//                           ),
//                           child: Center(
//                             child: Text(
//                               "Lihat Web",
//                               style: TextStyle(
//                                 fontSize: 20,
                                
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                   Container(
//                     height: 60,
//                     width: MediaQuery.of(context).size.width / 3,
//                     decoration: BoxDecoration(
//                       color: const Color.fromARGB(255, 7, 255, 61),
//                       borderRadius: BorderRadius.circular(17),
//                       border: Border.all(
//                         color: Colors.white,
//                         width: 2,
//                       ),
//                     ),
//                     child: Center(
//                       child: Text(
//                         "Simpan",
//                         style: TextStyle(
//                           fontSize: 20,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               );
//   }

//   Row editButton(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Container(
//               height: MediaQuery.of(context).size.height,
//               alignment: Alignment.bottomRight,
//               child: Padding(
//                 padding: const EdgeInsets.only(bottom: 10, right: 90, left: 20),
//                 child: GestureDetector(
//                   onTap: () {
//                     Navigator.push(context, MaterialPageRoute(builder: (context) => WebView(pageLink: "",id: widget.idPerangkat,status: false,)));
//                   },
//                   child: Container(
//                     height: 60,
                    
//                     width: MediaQuery.of(context).size.width/3,
//                     decoration: BoxDecoration(
//                       color: const Color.fromARGB(255, 7, 226, 255),
//                       borderRadius: BorderRadius.circular(17),
//                       border: Border.all(
//                         color: Colors.white,
//                         width: 2
//                       )
//                     ),
//                     child: Center(
//                       child: Text(
//                         "Lihat Web",
//                         style: TextStyle(
//                           fontSize: 20,
                          
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             Container(
//               height: MediaQuery.of(context).size.height,
//               alignment: Alignment.bottomRight,
//               child: Padding(
//                 padding: const EdgeInsets.only(bottom: 10, right: 20),
//                 child: GestureDetector(
//                   onTap: () {
//                     isEdit = true;
//                     setState(() {
                      
//                     });
//                   },
//                   child: Container(
//                     height: 60,
                    
//                     width: MediaQuery.of(context).size.width/3,
//                     decoration: BoxDecoration(
//                       color: Colors.amber,
//                       borderRadius: BorderRadius.circular(17),
//                       border: Border.all(
//                         color: Colors.white,
//                         width: 2
//                       )
//                     ),
//                     child: Center(
//                       child: Text(
//                         "Edit",
//                         style: TextStyle(
//                           fontSize: 20,
                          
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//       ],
//     );
//   }

//   FutureBuilder<List<PerangkatModel>> listDataPerangkat(){
//     return FutureBuilder(
//       future: databaseService.getPerangkat(), 
      
//       builder: (context, snapshot){
        
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Center(child: CircularProgressIndicator());
//         }
        
//         if (snapshot.hasError) {
//           return Center(child: Text('Error: ${snapshot.error}'));
//         }
        
//         if (widget.idPerangkat == null) {
//           return Container(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text("Nama : \n" + (_namaController.text.isEmpty ? "New Device" : _namaController.text)),
//                 SizedBox(height: 5,),
//                 Text("Tanggal Catatan : \n" + _tanggalController.text),
//                 SizedBox(height: 5,),
//                 Text("Gedung : \n" + _gedungController.text),
//                 SizedBox(height: 5,),
//                 Text("Jumlah Port Berfungsi : \n" + _portController.text),
//               ],
//             ),
//           );
//         }

//         if (!snapshot.hasData || snapshot.data!.isEmpty) {
//           return Center(child: Text('No devices found'));
//         }
//         for(int i= 0; i < snapshot.data!.length; i++){
//           if(snapshot.data![i].id == widget.idPerangkat){
//             indexPerangkat = i;
//             perangkat = snapshot.data![i];
//             _namaController = TextEditingController(text: perangkat!.nama);
//             _tanggalController = TextEditingController(text: perangkat!.tanggal);
//             _gedungController = TextEditingController(text: perangkat!.gedung);
//             _portController = TextEditingController(text: perangkat!.port.toString());
//             i = snapshot.data!.length;
//           }
//         }
//         return Container(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text("Nama : \n" + snapshot.data![indexPerangkat].nama),
//               SizedBox(height: 5,),
//               Text("Tanggal Catatan : \n" + snapshot.data![indexPerangkat].tanggal),
//               SizedBox(height: 5,),
//               Text("Gedung : \n" + snapshot.data![indexPerangkat].gedung),
//               SizedBox(height: 5,),
//               Text("Jumlah Port Berfungsi : \n" + snapshot.data![indexPerangkat].port.toString()),
//             ],
//               ),
//         );
//       }
//     );
//   }

//   Container lokasiPerangkat() {
//     return Container(
//               height: 200,
//               decoration: BoxDecoration(
//                 color: Colors.amber
//               ),
//             );
//   }

//   Column detailPerangkat() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           "Serial\t: ",
//           style: TextStyle(
//             fontSize: 34/2,
//           ),
//         ),
//         SizedBox(height: 5,),
//         Text(
//           "Model\t: ",
//           style: TextStyle(
//             fontSize: 34/2,
//           ),
//         ),
//         SizedBox(height: 5,),
//         Text(
//           "IP\t: ",
//           style: TextStyle(
//             fontSize: 34/2,
//           ),
//         ),
//         SizedBox(height: 5,),
//         Text(
//           "Version\t: ",
//           style: TextStyle(
//             fontSize: 34/2,
//           ),
//         ),
//         SizedBox(height: 5,),
//         Text(
//           "Gedung\t: ",
//           style: TextStyle(
//             fontSize: 34/2,
//           ),
//         ),
//         SizedBox(height: 5,),
//         Text(
//           "Status\t: ",
//           style: TextStyle(
//             fontSize: 34/2,
//           ),
//         ),
//         SizedBox(height: 5,),
//         Text(
//           "Lokasi\t: ",
//           style: TextStyle(
//             fontSize: 34/2,
//           ),
//         ),
//         SizedBox(height: 5,),
//       ],
//     );
//   }

//   Container gradientBG(BuildContext context) {
//     return Container(
//           height: MediaQuery.of(context).size.height/1.2,
//           padding: EdgeInsets.only(top: 80, left: 10, right: 10),
//           child: Container(
            
//             decoration: BoxDecoration(
//             gradient: LinearGradient(
//               begin: AlignmentGeometry.center,
//               end: AlignmentGeometry.bottomCenter,
//               colors: [
//                 Color.fromARGB(255, 148, 175, 255),
//                 Color.fromARGB(255, 219, 229, 255)
//               ]),
//             borderRadius: BorderRadius.only(topLeft: Radius.circular(17), )
//             ),
//           ),
//         );
//   }

//   Padding perangkatViewer(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(top: 30, right: 10),
//       child: Container(
//         height: MediaQuery.of(context).size.height / 2,
//         alignment: AlignmentGeometry.topRight,
//         child: Column(
//           children: [
//             Container(
//               alignment: Alignment.center,
//               width: MediaQuery.of(context).size.width / 2,
//               padding: EdgeInsets.only(left: 5, right: 5),
//               height: 50,
//               decoration: BoxDecoration(
//                 color: Color.fromARGB(255, 184, 202, 255),
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(17),
//                   topRight: Radius.circular(17),
//                 ),
//               ),
//               // --- PERBAIKAN DI SINI ---
//               child: widget.idPerangkat == null
//                   ? AutoSizeText(
//                       _namaController.text.isEmpty
//                           ? (widget.newPerangkatName ?? "Perangkat Baru")
//                           : _namaController.text,
//                       minFontSize: 10,
//                       maxLines: 1,
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontSize: 30,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     )
//                   // KASUS 2: Data Lama (Ambil dari Database berdasarkan ID)
//                   : FutureBuilder<List<PerangkatModel>>(
//                       future: databaseService.getPerangkat(),
//                       builder: (context, snapshot) {
//                         if (snapshot.connectionState == ConnectionState.waiting) {
//                           return Text("Loading...", style: TextStyle(fontSize: 15));
//                         }
                        
//                         String displayName = "Unknown Device";
                        
//                         if (snapshot.hasData) {
//                           // Cari perangkat yang ID-nya cocok dengan widget.idPerangkat
//                           var matches = snapshot.data!.where((p) => p.id == widget.idPerangkat);
//                           if (matches.isNotEmpty) {
//                             displayName = matches.first.nama;
//                           }
//                         }

//                         return AutoSizeText(
//                           displayName,
//                           minFontSize: 10,
//                           maxLines: 1, // Agar tidak tumpuk ke bawah
//                           overflow: TextOverflow.ellipsis,
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             fontSize: 30,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         );
//                       },
//                     ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }