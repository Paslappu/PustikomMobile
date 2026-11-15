import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart';
import 'package:qrscan/models/outbox_item.dart';
import 'package:qrscan/models/perangkat_model.dart';
import 'package:qrscan/services/outbox_store.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite/sqlite_api.dart';
import 'dart:io';

class DatabaseService implements OutboxStore {
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

  final String outboxTable = "report_outbox";
  final String outboxImageTable = "report_outbox_image";

  DatabaseService.constructor();

  Future<Database>? _opening;

  Future<Database> get database async {
    if (db != null) {
      return db!;
    }
    // Single-flight so concurrent first callers do not open twice.
    _opening ??= getDatabase();
    try {
      db = await _opening;
    } finally {
      _opening = null;
    }
    return db!;
  }

  Future<Database> getDatabase() async {
    final databaseDirPath = await getDatabasesPath();
    final databasePath = join(databaseDirPath, "master_db.db");
    final database = await openDatabase(
      databasePath,
      version: 4,
      onCreate: (db, version) async {
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
        await _createOutboxTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          db.execute(
            "ALTER TABLE $tableName ADD COLUMN $urlTableName TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 3) {
          db.execute(
            "ALTER TABLE $tableName ADD COLUMN $locationTableName TEXT NOT NULL DEFAULT ''",
          );
          db.execute(
            "ALTER TABLE $tableName ADD COLUMN $coordinateTableName TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 4) {
          await _createOutboxTables(db);
        }
      },
    );
    return database;
  }

  /// Offline report queue (schema version 4).
  Future<void> _createOutboxTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE $outboxTable (
        uuid TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL DEFAULT 0,
        device_id INTEGER NOT NULL DEFAULT 0,
        device_code TEXT NOT NULL DEFAULT '',
        device_label TEXT NOT NULL DEFAULT '',
        gedung_id INTEGER,
        gedung_label TEXT,
        captured_at TEXT NOT NULL DEFAULT '',
        latitude REAL,
        longitude REAL,
        notes TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'draft',
        attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt_at INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        last_error_code INTEGER,
        field_errors TEXT,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        sent_report_id INTEGER,
        sent_at INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_report_outbox_user_status '
      'ON $outboxTable(user_id, status)',
    );
    await db.execute('''
      CREATE TABLE $outboxImageTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        outbox_uuid TEXT NOT NULL DEFAULT '',
        position INTEGER NOT NULL DEFAULT 0,
        rel_path TEXT NOT NULL DEFAULT '',
        size_bytes INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_report_outbox_image_uuid '
      'ON $outboxImageTable(outbox_uuid)',
    );
  }

  Future<void> addPerangkat(
    String name,
    String tanggal,
    String gedung,
    String port,
    String url,
    String location,
    String coordinate,
  ) async {
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

    return data
        .map(
          (e) => PerangkatModel(
            id: e[idTableName] as int,
            nama: e[nameTableName] as String,
            tanggal: e[tanggalTableName] as String,
            gedung: e[gedungTableName] as String,
            port: e[portTableName] as int,
            url: e[urlTableName] as String,
            location: e[locationTableName] as String,
            coordinate: e[coordinateTableName] as String,
          ),
        )
        .toList();
  }

  Future<void> deletePerangkat(int id) async {
    final db = await database;
    await db.delete(tableName, where: "id = ?", whereArgs: [id]);
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

  // ---- Offline report queue (OutboxStore) ----

  @override
  Future<void> insert(OutboxItem item) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        outboxTable,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _writeImages(txn, item.uuid, item.images);
    });
  }

  @override
  Future<void> update(OutboxItem item) async {
    final db = await database;
    final values = item.toMap()..remove('uuid');
    await db.update(
      outboxTable,
      values,
      where: 'uuid = ?',
      whereArgs: [item.uuid],
    );
  }

  @override
  Future<void> replaceImages(String uuid, List<OutboxImage> images) async {
    final db = await database;
    await db.transaction((txn) => _writeImages(txn, uuid, images));
  }

  Future<void> _writeImages(
    DatabaseExecutor txn,
    String uuid,
    List<OutboxImage> images,
  ) async {
    await txn.delete(
      outboxImageTable,
      where: 'outbox_uuid = ?',
      whereArgs: [uuid],
    );
    for (final image in images) {
      await txn.insert(outboxImageTable, image.toMap(uuid));
    }
  }

  Future<List<OutboxImage>> _imagesFor(DatabaseExecutor db, String uuid) async {
    final rows = await db.query(
      outboxImageTable,
      where: 'outbox_uuid = ?',
      whereArgs: [uuid],
      orderBy: 'position ASC, id ASC',
    );
    return rows.map(OutboxImage.fromMap).toList();
  }

  @override
  Future<OutboxItem?> get(String uuid) async {
    final db = await database;
    final rows = await db.query(
      outboxTable,
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OutboxItem.fromMap(rows.first, images: await _imagesFor(db, uuid));
  }

  @override
  Future<List<OutboxItem>> listForUser(int userId) async {
    final db = await database;
    final rows = await db.query(
      outboxTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    final items = <OutboxItem>[];
    for (final row in rows) {
      final uuid = row['uuid'] as String;
      items.add(OutboxItem.fromMap(row, images: await _imagesFor(db, uuid)));
    }
    return items;
  }

  @override
  Future<void> delete(String uuid) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        outboxImageTable,
        where: 'outbox_uuid = ?',
        whereArgs: [uuid],
      );
      await txn.delete(outboxTable, where: 'uuid = ?', whereArgs: [uuid]);
    });
  }

  @override
  Future<int> resetUploadingToPending() async {
    final db = await database;
    return db.update(
      outboxTable,
      {'status': OutboxStatus.pending.name},
      where: 'status = ?',
      whereArgs: [OutboxStatus.uploading.name],
    );
  }

  @override
  Future<Set<String>> allUuids() async {
    final db = await database;
    final rows = await db.query(outboxTable, columns: ['uuid']);
    return rows.map((r) => r['uuid'] as String).toSet();
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
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
      await Share.shareXFiles([XFile(path)], text: 'Laporan Data Perangkat');
    }
  }
}
