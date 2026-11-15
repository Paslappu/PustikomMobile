import 'package:flutter/material.dart';

class CategoryModel {
  String name;
  String iconPath;
  Color boxColor;

  CategoryModel({
    required this.name,
    required this.iconPath,
    required this.boxColor
  });

  static List<CategoryModel> getCategories() {
    List<CategoryModel> categories = [];
    categories.add(
      CategoryModel(name: 'salad', iconPath: 'asset/icons/plate.svg', boxColor: const Color.fromARGB(255, 104, 255, 129))
    );
    categories.add(
      CategoryModel(name: 'Canai Bread', iconPath: 'asset/icons/canai-bread.svg', boxColor: const Color.fromARGB(255, 223, 209, 132))
    );
    categories.add(
      CategoryModel(name: 'Honey\nPancake', iconPath: 'asset/icons/honey-pancakes.svg', boxColor: const Color.fromARGB(255, 235, 173, 40))
    );
    categories.add(
      CategoryModel(name: 'Pie', iconPath: 'asset/icons/pie.svg', boxColor: const Color.fromARGB(255, 229, 255, 79))
    );
    return categories;
  }
}