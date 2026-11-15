import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart';
import 'package:qrscan/models/perangkat_model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'dart:io';

class DatabaseService {
  static Database? db;
  static final DatabaseService instance = DatabaseService.constructor();

  final String tableName = "Perangkat";
  final String idTableName = "Id";
  final String nameTableName = "Nama";
  final String tanggalTableName = "Tanggal";
  final String gedungTableName = "Gedung";
  final String portTableName = "Port";
  final String urlTableName = "Url";
  final String locationTableName = "Location";
  final String coordinateTableName = "Coordinate";

  DatabaseService.constructor();

  Future<Database> get database async {
    if(db != null){
      return db!;
    }
      db = await getDatabase();
      return db!;
  }

  Future<Database> getDatabase() async{
    final databaseDirPath = await getDatabasesPath();
    final databasePath = join(databaseDirPath, "master_db.db");
    final database = await openDatabase(
      databasePath,
      version: 3,
      onCreate: (db,version) {
        db.execute('''
          CREATE TABLE $tableName (
            $idTableName INTEGER PRIMARY KEY,
            $nameTableName TEXT NOT NULL,
            $tanggalTableName TEXT NOT NULL,
            $gedungTableName TEXT NOT NULL,
            $portTableName INTEGER NOT NULL,
            $urlTableName TEXT NOT NULL,
            $locationTableName TEXT NOT NULL,
            $coordinateTableName TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 2) {
          db.execute("ALTER TABLE $tableName ADD COLUMN $urlTableName TEXT NOT NULL DEFAULT ''");
        }
        if (oldVersion < 3) {
          db.execute("ALTER TABLE $tableName ADD COLUMN $locationTableName TEXT NOT NULL DEFAULT ''");
          db.execute("ALTER TABLE $tableName ADD COLUMN $coordinateTableName TEXT NOT NULL DEFAULT ''");
        }
      },
    );
    return database;
  }

  Future<void> addPerangkat(String name, String tanggal, String gedung, String port, String url, String location, String coordinate) async {
    final db = await database;
    await db.insert(tableName, {
      nameTableName: name,
      tanggalTableName: tanggal,
      gedungTableName: gedung,
      portTableName: int.tryParse(port) ?? 0,
      urlTableName: url,
      locationTableName: location,
      coordinateTableName: coordinate,
    });
  }

  Future<PerangkatModel?> getPerangkatById(int id) async {
    final db = await database;
    final result = await db.query(
      tableName,
      where: '$idTableName = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    final e = result.first;
    return PerangkatModel(
      id: e[idTableName] as int,
      nama: e[nameTableName] as String,
      tanggal: e[tanggalTableName] as String,
      gedung: e[gedungTableName] as String,
      port: e[portTableName] as int,
      url: e[urlTableName] as String,
      location: e[locationTableName] as String,
      coordinate: e[coordinateTableName] as String,
    );
  }

  Future<List<PerangkatModel>> getPerangkat() async {
    final db = await database;
    final data = await db.query(tableName);

    return data.map((e) => PerangkatModel(
      id: e[idTableName] as int,
      nama: e[nameTableName] as String,
      tanggal: e[tanggalTableName] as String,
      gedung: e[gedungTableName] as String,
      port: e[portTableName] as int,
      url: e[urlTableName] as String,
      location: e[locationTableName] as String,
      coordinate: e[coordinateTableName] as String,
    )).toList();
  }

  Future <void> deletePerangkat(int id) async{
    final db = await database;
    await db.delete(
      tableName,
      where: "id = ?",
      whereArgs: [id]
    );
  }

  Future<int> updatePerangkat(PerangkatModel perangkat) async {
    final db = await database;
    return db.update(
      tableName,
      {
        nameTableName: perangkat.nama,
        tanggalTableName: perangkat.tanggal,
        gedungTableName: perangkat.gedung,
        portTableName: perangkat.port,
        urlTableName: perangkat.url,
        locationTableName: perangkat.location,
        coordinateTableName: perangkat.coordinate,
      },
      where: '$idTableName = ?',
      whereArgs: [perangkat.id],
    );
  }

  Future<void> exportToExcel() async {
    List<PerangkatModel> data = await getPerangkat();
    var excel = Excel.createExcel();
    Sheet sheet = excel["Data Perangkat"];
    excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Nama'),
      TextCellValue('Tanggal'),
      TextCellValue('Gedung'),
      TextCellValue('Port'),
      TextCellValue('URL Source'), // Added header
    ]);

    for (var item in data) {
      sheet.appendRow([
        IntCellValue(item.id),
        TextCellValue(item.nama),
        TextCellValue(item.tanggal),
        TextCellValue(item.gedung),
        IntCellValue(item.port),
        TextCellValue(item.url), // Added data
      ]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/Laporan_Perangkat.xlsx";
      File(path)..createSync(recursive: true)..writeAsBytesSync(fileBytes);
      await Share.shareXFiles([XFile(path)], text: 'Laporan Data Perangkat');
    }
  }
}