import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qrscan/models/perangkat_model.dart';
import 'package:qrscan/pages/base.dart';
import 'package:qrscan/pages/rincian_perangkat.dart';
import 'package:qrscan/pages/transitionScrap.dart';
import 'package:qrscan/services/database_service.dart';

class Riwayatpage extends StatefulWidget {
  Riwayatpage({super.key});

  @override
  State<Riwayatpage> createState() => _RiwayatpageState();
}

class _RiwayatpageState extends State<Riwayatpage> {
  final DatabaseService databaseService = DatabaseService.instance;
  List<PerangkatModel> perangkats = [];
  List<PerangkatModel> tempLists = [];
  bool filterNama = true;
  bool filterTanggal = false;
  bool filterGedung = false;
  bool filterPort = false;
  bool _isLoading = true;

  void runFilter(String keyword) {
    if (keyword.isEmpty) {
      setState(() {
        tempLists = List.from(perangkats); // Create a copy
      });
      return;
    }

    final filtered = perangkats.where((perangkat) {
      return (filterNama &&
              perangkat.nama.toLowerCase().contains(keyword.toLowerCase())) ||
          (filterTanggal &&
              perangkat.tanggal.toLowerCase().contains(
                keyword.toLowerCase(),
              )) ||
          (filterGedung &&
              perangkat.gedung.toLowerCase().contains(keyword.toLowerCase())) ||
          (filterPort && perangkat.port.toString().contains(keyword));
    }).toList();

    filtered.sort((a, b) => b.id.compareTo(a.id));

    setState(() {
      tempLists = filtered;
    });
  }

  Future<void> _loadData() async {
    try {
      final data = await databaseService.getPerangkat();
      setState(() {
        perangkats = data;
        tempLists = List.from(data);
        tempLists.sort((a, b) => b.id.compareTo(a.id)); // Create a copy
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      // Handle error
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    filterNama = true;
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 148, 175, 255),
      body: Stack(
        children: [
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : listPerangkat(),
          topButton(context),
          saveButton(context),
        ],
      ),
    );
  }

  Widget listPerangkat() {
    return Container(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10, top: 50),
        child: Container(
          height: MediaQuery.of(context).size.height - 70,
          decoration: BoxDecoration(
            color: Color.fromARGB(255, 219, 229, 255),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              top: 130,
              left: 5,
              right: 5,
              bottom: 80,
            ),
            child: tempLists.isEmpty
                ? Center(child: Text('No devices found'))
                : ListView.separated(
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransitionScrap(
                                dbId: tempLists[index].id,
                                idPerangkat: tempLists[index].id,
                                isEditing: false,
                                url: tempLists[index].url,
                                newPerangkatName: tempLists[index].nama,
                              ),
                            ),
                          );
                          // Navigator.push(context, MaterialPageRoute(builder: (context) => WebView(pageLink: "",)));
                        },
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: Color.fromARGB(
                              255,
                              184,
                              202,
                              255,
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SvgPicture.asset(
                                  "asset/icons/router-5-svgrepo-com.svg",
                                  width: 80,
                                ),
                                SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AutoSizeText(
                                        tempLists[index].nama,
                                        minFontSize: 10,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        tempLists[index].tanggal +
                                            " | " +
                                            tempLists[index].gedung +
                                            " | " +
                                            tempLists[index].port.toString(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (context, index) => SizedBox(height: 10),
                    itemCount: tempLists.length,
                  ),
          ),
        ),
      ),
    );
  }

  GestureDetector saveButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sedang export ke Excel..."),
            duration: Duration(seconds: 1),
          ),
        );

        // Panggil fungsi database
        await databaseService.exportToExcel();
      },
      child: Container(
        alignment: AlignmentGeometry.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(left: 0, bottom: 20),
          child: Container(
            height: 60,
            width: (MediaQuery.of(context).size.width / 1.5),
            decoration: BoxDecoration(
              color: Color.fromARGB(255, 109, 185, 23),
              borderRadius: BorderRadius.circular(222),
            ),
            child: Center(
              child: Text("Simpan Riwayat", style: TextStyle(fontSize: 20)),
            ),
          ),
        ),
      ),
    );
  }

  Padding topButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10, top: 40),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BaseHome()),
                  );
                },
                child: Container(
                  height: 50,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 184, 202, 255),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: SvgPicture.asset(
                    "asset/icons/Arrow - Left 2.svg",
                    width: 60,
                  ),
                ),
              ),
              SizedBox(width: 20),
              Container(
                height: 50,
                width: 290 - 19,
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 184, 202, 255),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: Text(
                    "Riwayat",
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          //searchField
          searchField(),
          SizedBox(height: 5),
          filter(context),
        ],
      ),
    );
  }

  Padding searchField() {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 250, 233, 183),
          borderRadius: BorderRadius.circular(222),
        ),
        child: TextField(
          onChanged: (value) => runFilter(value),
          decoration: InputDecoration(
            filled: true,
            hintText: "Cari Perangkat....",
            hintStyle: TextStyle(color: const Color.fromARGB(174, 17, 17, 17)),
            border: InputBorder.none,
            fillColor: Colors.transparent,
          ),
        ),
      ),
    );
  }

  Row filter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              filterNama = !filterNama;
              filterPort = false;
              filterGedung = false;
              filterTanggal = false;
            });
          },
          child: Container(
            height: 30,
            width: MediaQuery.of(context).size.width / 4 - 30,
            decoration: BoxDecoration(
              color: filterNama ? Colors.blueAccent : Colors.amberAccent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Center(child: Text("Nama")),
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              filterTanggal = !filterTanggal;
              filterNama = false;
              filterGedung = false;
              filterPort = false;
            });
          },
          child: Container(
            height: 30,
            width: MediaQuery.of(context).size.width / 4 - 30,
            decoration: BoxDecoration(
              color: filterTanggal ? Colors.blueAccent : Colors.amberAccent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Center(child: Text("Tanggal")),
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              filterGedung = !filterGedung;
              filterNama = false;
              filterPort = false;
              filterTanggal = false;
            });
          },
          child: Container(
            height: 30,
            width: MediaQuery.of(context).size.width / 4 - 30,
            decoration: BoxDecoration(
              color: filterGedung ? Colors.blueAccent : Colors.amberAccent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Center(child: Text("Gedung")),
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              filterPort = !filterPort;
              filterNama = false;
              filterGedung = false;
              filterTanggal = false;
            });
          },
          child: Container(
            height: 30,
            width: MediaQuery.of(context).size.width / 4 - 30,
            decoration: BoxDecoration(
              color: filterPort ? Colors.blueAccent : Colors.amberAccent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Center(child: Text("Port")),
          ),
        ),
      ],
    );
  }
}
