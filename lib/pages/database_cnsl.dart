import 'package:flutter/material.dart';
import 'package:qrscan/models/perangkat_model.dart';
import 'package:qrscan/services/database_service.dart';

class Catatan extends StatefulWidget {
  @override
  State<Catatan> createState() => _CatatanState();
}

class _CatatanState extends State<Catatan> {
  final DatabaseService databaseService = DatabaseService.instance;
  String? nama = null;
  String? tanggal = null;
  String? gedung = null;
  String? port = null;
  int idRemove = 0;
  int _refreshKey = 0;
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _gedungController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Clear text fields when widget initializes
    _namaController.clear();
    _tanggalController.clear();
    _gedungController.clear();
    _portController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color.fromARGB(255, 86, 253, 231),
        padding: EdgeInsets.only(top: 30, left: 10, right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nama"),
            TextField(
              controller: _namaController, // Use controller
              onChanged: (value) {
                setState(() {
                  nama = value;
                });
              },
            ),
            SizedBox(height: 20),
            Text("Tanggal"),
            TextField(
              controller: _tanggalController, // Use controller
              onChanged: (value) {
                setState(() {
                  tanggal = value;
                });
              },
            ),
            SizedBox(height: 20),
            Text("Gedung"),
            TextField(
              controller: _gedungController, // Use controller
              onChanged: (value) {
                setState(() {
                  gedung = value;
                });
              },
            ),
            SizedBox(height: 20),
            Text("Port"),
            TextField(
              controller: _portController, // Use controller
              onChanged: (value) {
                setState(() {
                  port = value;
                });
              },
            ),
            SizedBox(height: 20),
            Container(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        if ((nama == null ||
                                tanggal == null ||
                                gedung == null ||
                                port == null) ||
                            (nama == "" ||
                                tanggal == "" ||
                                gedung == "" ||
                                port == "")) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text("Requirement not met"),
                              content: Text("Fill all field"),
                            ),
                          );
                          return;
                        }

                        // databaseService.addPerangkat(nama!, tanggal!, gedung!, port!);

                        // Clear text fields
                        _namaController.clear();
                        _tanggalController.clear();
                        _gedungController.clear();
                        _portController.clear();

                        // Refresh the UI
                        setState(() {
                          _refreshKey++;
                          nama = null;
                          tanggal = null;
                          gedung = null;
                          port = null;
                        });
                      },
                      child: Container(
                        height: 50,
                        width: MediaQuery.of(context).size.width / 3,
                        color: Colors.amber,
                        child: Center(child: Text("Add Device")),
                      ),
                    ),
                    SizedBox(width: 10),
                    GestureDetector(
                      onTap: () async {
                        databaseService.deletePerangkat(idRemove);
                        setState(() {});
                      },
                      child: Container(
                        height: 50,
                        width: MediaQuery.of(context).size.width / 3,
                        color: const Color.fromARGB(255, 7, 238, 255),
                        child: Center(child: Text("Remove Device")),
                      ),
                    ),
                    Container(
                      width: 20,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          idRemove = int.tryParse(value) ?? 0;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              // Wrap with Expanded
              child: databaseList(),
            ),
          ],
        ),
      ),
    );
  }

  FutureBuilder<List<PerangkatModel>> databaseList() {
    return FutureBuilder(
      key: ValueKey(_refreshKey),
      future: databaseService.getPerangkat(),
      builder: (context, snapshot) {
        // Handle different states
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No devices found'));
        }

        return Container(
          color: const Color.fromARGB(28, 33, 149, 243),
          child: ListView.separated(
            shrinkWrap: true,
            physics: ClampingScrollPhysics(),
            itemCount: snapshot.data!.length,
            padding: EdgeInsets.all(0.8),
            itemBuilder: (context, index) {
              PerangkatModel perangkat = snapshot.data![index];
              return GestureDetector(
                onTap: () {},
                child: Container(
                  height: 40,
                  padding: EdgeInsets.only(left: 10, right: 10),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 0, 170, 255),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Row(
                    children: [
                      Text(perangkat.nama + " | "),
                      Text(perangkat.gedung + " | "),
                      Text(perangkat.tanggal + " | "),
                      Text(perangkat.port.toString()),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (context, index) => SizedBox(height: 20),
          ),
        );
      },
    );
  }
}
