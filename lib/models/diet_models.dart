import 'package:flutter/material.dart';

class DietModels {
  String name;
  String iconPath;
  Color boxColor;
  String level;
  String duration;
  String calories;
  bool viewIsSelected;

  DietModels({
    required this.name,
    required this.iconPath,
    required this.level,
    required this.duration,
    required this.boxColor,
    required this.calories,
    required this.viewIsSelected,
  });

  static List<DietModels> getDiets() {
    List<DietModels> diets = [];
    diets.add(
      DietModels(
        name: 'Honey Pancake',
        iconPath: 'asset/icons/honey-pancakes.svg',
        boxColor: const Color.fromARGB(255, 235, 173, 40),
        level: 'Easy',
        duration: '30 mins',
        calories: '100cal',
        viewIsSelected: true,
      ),
    );
    diets.add(
      DietModels(
        name: 'Canai Bread',
        iconPath: 'asset/icons/canai-bread.svg',
        level: 'Medium',
        duration: '50 mins',
        boxColor: const Color.fromARGB(255, 223, 209, 132),
        calories: '180cal',
        viewIsSelected: true,
      ),
    );
    diets.add(
      DietModels(
        name: 'Salad',
        iconPath: 'asset/icons/plate.svg',
        level: 'Easy',
        duration: '15 mins',
        boxColor: const Color.fromARGB(255, 104, 255, 129),
        calories: '80cal',
        viewIsSelected: true,
      ),
    );
    diets.add(
      DietModels(
        name: 'Pie',
        iconPath: 'asset/icons/pie.svg',
        level: 'Hard',
        duration: '60 mins',
        boxColor: const Color.fromARGB(255, 229, 255, 79),
        calories: '200cal',
        viewIsSelected: true,
      ),
    );

    return diets;
  }
}
