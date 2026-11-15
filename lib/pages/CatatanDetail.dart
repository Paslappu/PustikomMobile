import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:qrscan/pages/riwayat.dart';

class Catatandetail extends StatefulWidget{
  Catatandetail({super.key});
  
  @override
  State<Catatandetail> createState() => _CatatanDetail();
}

class _CatatanDetail extends State<Catatandetail>{
  String deviceName = "Lorem";
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Color.fromARGB(255, 219, 229, 255),
        body: Stack(
          children: [
            ListView(
              children: [
                header(context),
                gradientBG(context),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 90),
              child: Column(      
                children: [
                  Text(
                    "Detail Perangkat",
                    style: TextStyle(
                      fontSize: 40/2,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  Container(
                    height: MediaQuery.of(context).size.height/3,
                    alignment: AlignmentGeometry.center,
                    child: Container(
                      alignment: AlignmentGeometry.center,
                      width: MediaQuery.of(context).size.width-40,
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 184, 202, 255),
                        borderRadius: BorderRadius.circular(17)
                      ),
                    ),
                  ),
                ],
              ),
            )
            // backButton(context),
          ],
        )
      ),
    );
  }

  GestureDetector backButton(BuildContext context) {
    return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => Riwayatpage()));
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 30, left: 20),
              child: Container(
                height: 55,
                width: 110,
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 184, 202, 255),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    width: 2
                  )
                ),
              ),
            ),
          );
  }

  Padding header(BuildContext context) {
    return Padding(
                padding: const EdgeInsets.only(top: 20, right: 10),
                child: Container(
                  alignment: AlignmentGeometry.topRight,
                  child: Column(
                  children: [
                    Container(
                      alignment: Alignment.center,
                      width: MediaQuery.of(context).size.width/2,
                      padding: EdgeInsets.only(left: 5,right: 5),
                      height: 50,
                      decoration: BoxDecoration(
                        color: Color.fromARGB(255, 148, 175, 255),
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(17), topRight: Radius.circular(17),)
                      ),
                      child: AutoSizeText(
                        deviceName,
                        minFontSize: 10,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                    
                  ],
                ),
                ),
              );
  }

  Container gradientBG(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height/1.2,
      padding: EdgeInsets.only(top: 0, left: 10, right: 10),
      child: Container(
        
        decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentGeometry.center,
          end: AlignmentGeometry.bottomCenter,
          colors: [
            Color.fromARGB(255, 148, 175, 255),
            Color.fromARGB(255, 219, 229, 255)
          ]),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(17), )
        ),
      ),
    );
  }

}