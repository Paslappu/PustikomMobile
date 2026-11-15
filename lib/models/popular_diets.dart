import 'package:flutter/material.dart';

class PopularDiets {
  String name;
  String iconPath;
  Color boxColor;
  String level;
  String duration;
  String calories;
  bool boxIsSelected;

  PopularDiets({
    required this.name,
    required this.iconPath,
    required this.level,
    required this.duration,
    required this.boxColor,
    required this.calories,
    required this.boxIsSelected
  });

  static List <PopularDiets> getPopularDiets(){
    List<PopularDiets> popDiets = [];
    popDiets.add(
      PopularDiets(
        name: 'Honey Pancake',
        iconPath: 'asset/icons/honey-pancakes.svg', 
        boxColor: const Color.fromARGB(255, 235, 173, 40),
        level: 'Easy', 
        duration: '30 mins', 
        calories: '100cal', 
        boxIsSelected: false)
    );
    popDiets.add(
      PopularDiets(
        name: 'Canai Bread',
        iconPath: 'asset/icons/canai-bread.svg', 
        level: 'Medium', 
        duration: '50 mins',
        boxColor: const Color.fromARGB(255, 223, 209, 132), 
        calories: '180cal', 
        boxIsSelected: false)
    );
    popDiets.add(
      PopularDiets(
        name: 'Salad',
        iconPath: 'asset/icons/plate.svg', 
        level: 'Easy', 
        duration: '15 mins', 
        boxColor: const Color.fromARGB(255, 104, 255, 129),
        calories: '80cal', 
        boxIsSelected: false)
    );
    popDiets.add(
      PopularDiets(
        name: 'Pie',
        iconPath: 'asset/icons/pie.svg', 
        level: 'Hard', 
        duration: '60 mins', 
        boxColor: const Color.fromARGB(255, 229, 255, 79),
        calories: '200cal', 
        boxIsSelected: false)
    );
    popDiets.add(
      PopularDiets(
        name: 'Honey Pancake',
        iconPath: 'asset/icons/honey-pancakes.svg', 
        boxColor: const Color.fromARGB(255, 235, 173, 40),
        level: 'Easy', 
        duration: '30 mins', 
        calories: '100cal', 
        boxIsSelected: false)
    );
    popDiets.add(
      PopularDiets(
        name: 'Honey Pancake',
        iconPath: 'asset/icons/honey-pancakes.svg', 
        boxColor: const Color.fromARGB(255, 40, 229, 235),
        level: 'Easy', 
        duration: '30 mins', 
        calories: '100cal', 
        boxIsSelected: false)
    );
    popDiets.add(
      PopularDiets(
        name: 'Honey Pancake',
        iconPath: 'asset/icons/honey-pancakes.svg', 
        boxColor: const Color.fromARGB(255, 235, 40, 40),
        level: 'Easy', 
        duration: '30 mins', 
        calories: '100cal', 
        boxIsSelected: false)
    );
    popDiets.add(
      PopularDiets(
        name: 'Honey Pancake',
        iconPath: 'asset/icons/honey-pancakes.svg', 
        boxColor: const Color.fromARGB(255, 40, 235, 40),
        level: 'Easy', 
        duration: '30 mins', 
        calories: '100cal', 
        boxIsSelected: false)
    );
    popDiets.add(
      PopularDiets(
        name: 'Honey Pancake',
        iconPath: 'asset/icons/honey-pancakes.svg', 
        boxColor: const Color.fromARGB(255, 180, 126, 9),
        level: 'Easy', 
        duration: '30 mins', 
        calories: '100cal', 
        boxIsSelected: false)
    );
    popDiets.add(
      PopularDiets(
        name: 'Honey Pancake',
        iconPath: 'asset/icons/honey-pancakes.svg', 
        boxColor: const Color.fromARGB(255, 255, 1, 255),
        level: 'Easy', 
        duration: '30 mins', 
        calories: '100cal', 
        boxIsSelected: false)
    );
    popDiets.add(
      PopularDiets(
        name: 'Honey Pancake',
        iconPath: 'asset/icons/honey-pancakes.svg', 
        boxColor: const Color.fromARGB(255, 9, 224, 124),
        level: 'Easy', 
        duration: '30 mins', 
        calories: '100cal', 
        boxIsSelected: false)
    );
    popDiets.add(
      PopularDiets(
        name: 'Honey Pancake',
        iconPath: 'asset/icons/honey-pancakes.svg', 
        boxColor: const Color.fromARGB(255, 180, 9, 157),
        level: 'Easy', 
        duration: '30 mins', 
        calories: '100cal', 
        boxIsSelected: false)
    );
    popDiets.add(
      PopularDiets(
        name: 'Honey Pancake',
        iconPath: 'asset/icons/honey-pancakes.svg', 
        boxColor: const Color.fromARGB(255, 26, 9, 180),
        level: 'Easy', 
        duration: '30 mins', 
        calories: '100cal', 
        boxIsSelected: false)
    );
    popDiets.add(
      PopularDiets(
        name: 'Honey Pancake',
        iconPath: 'asset/icons/honey-pancakes.svg', 
        boxColor: const Color.fromARGB(255, 230, 255, 2),
        level: 'Easy', 
        duration: '30 mins', 
        calories: '100cal', 
        boxIsSelected: false)
    );

    return popDiets;
  }
}