import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qrscan/models/category_model.dart';
import 'package:qrscan/models/diet_models.dart';
import 'package:qrscan/models/popular_diets.dart';
import 'package:qrscan/pages/base.dart';

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<CategoryModel> categories = [];

  List<DietModels> diets = [];

  List<PopularDiets> popDiets = [];

  void getLists() {
    categories = CategoryModel.getCategories();
    diets = DietModels.getDiets();
    popDiets = PopularDiets.getPopularDiets();
  }

  @override
  void initState() {
    // TODO: implement initS  tate
    getLists();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: topBar(),
      backgroundColor: Colors.white,
      body: ListView(
        children: [
          searchField(),
          const SizedBox(height: 40),
          categoriesSection(),
          const SizedBox(height: 40),
          dietSection(),
          const SizedBox(height: 40),
          popularDietSection(),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Column popularDietSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            'Popular Diets',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: 20,
            ),
          ),
        ),
        SizedBox(height: 20),
        ListView.separated(
          padding: EdgeInsets.only(left: 20, right: 20),
          itemBuilder: (context, index) {
            return Container(
              height: 115,
              padding: EdgeInsets.only(left: 20, right: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  SvgPicture.asset(
                    popDiets[index].iconPath,
                    width: 60,
                    height: 60,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        popDiets[index].name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        popDiets[index].level +
                            " | " +
                            popDiets[index].calories +
                            " | " +
                            popDiets[index].duration,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: const Color.fromARGB(255, 48, 48, 48),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTapDown: (_) {
                      setState(() {
                        popDiets[index].boxIsSelected =
                            true; // Instant change when pressed
                      });
                    },
                    onTapUp: (_) {
                      setState(() {
                        popDiets[index].boxIsSelected =
                            false; // Instant revert when released
                      });
                    },
                    onTapCancel: () {
                      setState(() {
                        popDiets[index].boxIsSelected =
                            false; // Instant revert if cancelled
                      });
                    },
                    child: SvgPicture.asset(
                      'asset/icons/button.svg',
                      height: 30,
                      width: 30,
                    ),
                  ),
                ],
              ),
              decoration: BoxDecoration(
                color: popDiets[index].boxIsSelected
                    ? Colors.amberAccent
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: popDiets[index].boxIsSelected
                    ? [
                        BoxShadow(
                          blurRadius: 40,
                          color: Colors.black.withOpacity(0.3),
                          offset: Offset(0, 10),
                          spreadRadius: 0,
                        ),
                      ]
                    : [
                        BoxShadow(
                          blurRadius: 40,
                          color: Colors.transparent,
                          offset: Offset(0, 10),
                          spreadRadius: 0,
                        ),
                      ],
              ),
            );
          },
          separatorBuilder: (context, index) => SizedBox(height: 20),
          itemCount: popDiets.length,
          shrinkWrap: true,
        ),
      ],
    );
  }

  Column dietSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            'Recomendation\nFor Diet',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w500,
              fontSize: 20,
            ),
          ),
        ),
        SizedBox(height: 20),
        Container(
          height: 240,
          color: const Color.fromARGB(33, 33, 149, 243),
          child: ListView.separated(
            padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
            itemBuilder: (context, index) {
              return Container(
                width: 210,
                decoration: BoxDecoration(
                  color: diets[index].boxColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SvgPicture.asset(
                      diets[index].iconPath,
                      width: 65,
                      height: 65,
                    ),
                    Column(
                      children: [
                        Text(
                          diets[index].name,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          diets[index].level +
                              ' | ' +
                              diets[index].calories +
                              ' | ' +
                              diets[index].duration,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: const Color.fromARGB(255, 63, 63, 63),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),

                    GestureDetector(
                      onTapDown: (_) {
                        setState(() {
                          diets[index].viewIsSelected =
                              true; // Instant change when pressed
                        });
                      },
                      onTapUp: (_) {
                        setState(() {
                          diets[index].viewIsSelected =
                              false; // Instant revert when released
                        });
                      },
                      onTapCancel: () {
                        setState(() {
                          diets[index].viewIsSelected =
                              false; // Instant revert if cancelled
                        });
                      },
                      child: Container(
                        height: 30,
                        width: 100,
                        child: Center(
                          child: Text(
                            "Lihat",
                            style: TextStyle(
                              color: diets[index].viewIsSelected
                                  ? const Color.fromARGB(255, 0, 0, 0)
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),

                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: [
                              diets[index].viewIsSelected
                                  ? Colors.transparent
                                  : Color.fromARGB(255, 59, 240, 113),
                              diets[index].viewIsSelected
                                  ? Colors.transparent
                                  : Colors.amber,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (context, index) => SizedBox(width: 25),
            itemCount: diets.length,
            scrollDirection: Axis.horizontal,
          ),
        ),
      ],
    );
  }

  Column categoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            'Kategori',
            style: TextStyle(
              color: const Color.fromARGB(255, 16, 22, 27),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 20),
        Container(
          height: 120,
          color: const Color.fromARGB(31, 24, 255, 255),
          child: ListView.separated(
            padding: EdgeInsets.only(left: 20, right: 20),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (context, index) => SizedBox(width: 10),
            itemBuilder: (context, index) {
              return Container(
                width: 100,
                decoration: BoxDecoration(
                  color: categories[index].boxColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SvgPicture.asset(categories[index].iconPath),
                      ),
                    ),
                    Text(
                      categories[index].name,
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Container searchField() {
    return Container(
      margin: EdgeInsets.only(top: 40, left: 20, right: 20),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(40, 0, 0, 0),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          filled: true,
          hintText: 'Ketik Disini...',
          hintStyle: TextStyle(
            color: const Color.fromARGB(122, 112, 112, 112),
            fontSize: 14,
          ),
          fillColor: Colors.white10,
          contentPadding: EdgeInsets.all(15),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: SvgPicture.asset('asset/icons/Search.svg'),
          ),
          suffixIcon: Container(
            width: 100,
            child: IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  VerticalDivider(
                    color: const Color.fromARGB(75, 0, 0, 0),
                    thickness: 1,
                    endIndent: 10,
                    indent: 10,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SvgPicture.asset('asset/icons/Filter.svg'),
                  ),
                ],
              ),
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  AppBar topBar() {
    return AppBar(
      title: Text(
        'HISTORY',
        style: TextStyle(
          color: const Color.fromARGB(255, 16, 22, 27),
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      centerTitle: true,
      elevation: 0,
      backgroundColor: const Color.fromARGB(255, 224, 250, 255),

      leading: Container(
        margin: EdgeInsets.all(10),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BaseHome()),
            );
          },
          child: SvgPicture.asset(
            'asset/icons/Arrow - Left 2.svg',
            width: 20,
            height: 20,
          ),
        ),
        decoration: BoxDecoration(
          color: Color.fromARGB(0, 145, 35, 20),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      actions: [
        GestureDetector(
          child: Container(
            margin: EdgeInsets.all(10),
            width: 37,
            alignment: Alignment.center,
            child: SvgPicture.asset(
              'asset/icons/dots.svg',
              width: 5,
              height: 5,
            ),
            decoration: BoxDecoration(
              color: Color.fromARGB(0, 145, 35, 20),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}
