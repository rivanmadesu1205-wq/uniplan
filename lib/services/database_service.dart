import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catatan.dart';
import '../models/jadwal.dart';
import 'supabase_config.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init(
    'studyplan_v6.db',
  );

  Database? _database;
  final String _databaseName;

  DatabaseService._init(this._databaseName);

  factory DatabaseService.forTesting(String databaseName) {
    return DatabaseService._init(databaseName);
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_databaseName);
    return _database!;
  }

  String get _currentUserId =>
      SupabaseConfig.client?.auth.currentUser?.id ?? 'guest_user';

  Future<void> closeForTesting() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE jadwal (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        docId TEXT,
        userId TEXT,
        mataKuliah TEXT NOT NULL,
        jamMulai TEXT NOT NULL,
        jamSelesai TEXT NOT NULL,
        ruangan TEXT NOT NULL,
        dosen TEXT NOT NULL,
        hari TEXT NOT NULL,
        tanggal TEXT NOT NULL,
        isAlarmActive INTEGER DEFAULT 1,
        alarmMinutesBefore INTEGER DEFAULT 10,
        alarmMinutesList TEXT DEFAULT '10'
      )
    ''');

    await db.execute('''
      CREATE TABLE catatan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        docId TEXT,
        userId TEXT,
        jadwalId TEXT,
        mataKuliah TEXT NOT NULL,
        mingguKe INTEGER DEFAULT 1,
        judul TEXT NOT NULL,
        isi TEXT NOT NULL,
        tanggal TEXT NOT NULL,
        waktu TEXT NOT NULL,
        tipe TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE jadwal ADD COLUMN isAlarmActive INTEGER DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE jadwal ADD COLUMN alarmMinutesBefore INTEGER DEFAULT 10',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS catatan (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          docId TEXT,
          userId TEXT,
          jadwalId TEXT,
          mataKuliah TEXT NOT NULL,
          mingguKe INTEGER DEFAULT 1,
          judul TEXT NOT NULL,
          isi TEXT NOT NULL,
          tanggal TEXT NOT NULL,
          waktu TEXT NOT NULL,
          tipe TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE catatan ADD COLUMN mingguKe INTEGER DEFAULT 1',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE jadwal ADD COLUMN alarmMinutesList TEXT DEFAULT '10'",
      );
    }
  }

  Future<void> _syncJadwal() async {
    final client = SupabaseConfig.client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await _pushLocalJadwal(client, userId);
      final remoteRows = await client
          .from('jadwal')
          .select()
          .eq('user_id', userId)
          .order('jam_mulai');
      final db = await database;

      for (final row in remoteRows) {
        final item = _jadwalFromRemote(Map<String, dynamic>.from(row));
        final existing = await db.query(
          'jadwal',
          columns: ['id'],
          where: 'userId = ? AND docId = ?',
          whereArgs: [userId, item.docId],
          limit: 1,
        );
        if (existing.isEmpty) {
          await db.insert('jadwal', item.toMap());
        } else {
          await db.update(
            'jadwal',
            item.copyWith(id: existing.first['id'] as int).toMap(),
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        }
      }
    } on PostgrestException catch (error) {
      debugPrint('Supabase jadwal sync failed: ${error.message}');
    } on Exception catch (error) {
      debugPrint('Supabase jadwal sync failed: $error');
    }
  }

  Future<void> _pushLocalJadwal(
    SupabaseClient client,
    String userId,
  ) async {
    final db = await database;
    final rows = await db.query('jadwal', where: 'userId = ?', whereArgs: [
      userId,
    ]);

    for (final row in rows) {
      final item = Jadwal.fromMap(row);
      final payload = <String, dynamic>{
        if (item.docId != null) 'id': item.docId,
        'user_id': userId,
        'mata_kuliah': item.mataKuliah,
        'jam_mulai': item.jamMulai,
        'jam_selesai': item.jamSelesai,
        'ruangan': item.ruangan,
        'dosen': item.dosen,
        'hari': item.hari,
        'tanggal': item.tanggal,
        'is_alarm_active': item.isAlarmActive,
        'alarm_minutes_before': item.alarmMinutesBefore,
        'alarm_minutes_list': item.alarmMinutesList,
      };
      final saved = await client
          .from('jadwal')
          .upsert(payload)
          .select('id')
          .single();
      final docId = saved['id'].toString();
      if (docId != item.docId) {
        await db.update(
          'jadwal',
          {'docId': docId},
          where: 'id = ? AND userId = ?',
          whereArgs: [item.id, userId],
        );
      }
    }
  }

  Jadwal _jadwalFromRemote(Map<String, dynamic> row) => Jadwal.fromMap({
    'docId': row['id']?.toString(),
    'userId': row['user_id']?.toString(),
    'mataKuliah': row['mata_kuliah'],
    'jamMulai': row['jam_mulai'],
    'jamSelesai': row['jam_selesai'],
    'ruangan': row['ruangan'],
    'dosen': row['dosen'],
    'hari': row['hari'],
    'tanggal': row['tanggal'],
    'isAlarmActive': row['is_alarm_active'],
    'alarmMinutesBefore': row['alarm_minutes_before'],
    'alarmMinutesList': row['alarm_minutes_list'],
  });

  Future<void> _syncCatatan() async {
    final client = SupabaseConfig.client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;

    try {
      await _pushLocalCatatan(client, userId);
      final remoteRows = await client
          .from('catatan')
          .select()
          .eq('user_id', userId)
          .order('minggu_ke')
          .order('created_at', ascending: false);
      final db = await database;

      for (final row in remoteRows) {
        final item = _catatanFromRemote(Map<String, dynamic>.from(row));
        final existing = await db.query(
          'catatan',
          columns: ['id'],
          where: 'userId = ? AND docId = ?',
          whereArgs: [userId, item.docId],
          limit: 1,
        );
        if (existing.isEmpty) {
          await db.insert('catatan', item.toMap());
        } else {
          await db.update(
            'catatan',
            item.copyWith(id: existing.first['id'] as int).toMap(),
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        }
      }
    } on PostgrestException catch (error) {
      debugPrint('Supabase catatan sync failed: ${error.message}');
    } on Exception catch (error) {
      debugPrint('Supabase catatan sync failed: $error');
    }
  }

  Future<void> _pushLocalCatatan(
    SupabaseClient client,
    String userId,
  ) async {
    final db = await database;
    final rows = await db.query('catatan', where: 'userId = ?', whereArgs: [
      userId,
    ]);

    for (final row in rows) {
      final item = Catatan.fromMap(row);
      final payload = <String, dynamic>{
        if (item.docId != null) 'id': item.docId,
        'user_id': userId,
        'jadwal_id': item.jadwalId,
        'mata_kuliah': item.mataKuliah,
        'minggu_ke': item.mingguKe,
        'judul': item.judul,
        'isi': item.isi,
        'tanggal': item.tanggal,
        'waktu': item.waktu,
        'tipe': item.tipe,
        'created_at': item.createdAt,
      };
      final saved = await client
          .from('catatan')
          .upsert(payload)
          .select('id')
          .single();
      final docId = saved['id'].toString();
      if (docId != item.docId) {
        await db.update(
          'catatan',
          {'docId': docId},
          where: 'id = ? AND userId = ?',
          whereArgs: [item.id, userId],
        );
      }
    }
  }

  Catatan _catatanFromRemote(Map<String, dynamic> row) => Catatan.fromMap({
    'docId': row['id']?.toString(),
    'userId': row['user_id']?.toString(),
    'jadwalId': row['jadwal_id']?.toString(),
    'mataKuliah': row['mata_kuliah'],
    'mingguKe': row['minggu_ke'],
    'judul': row['judul'],
    'isi': row['isi'],
    'tanggal': row['tanggal'],
    'waktu': row['waktu'],
    'tipe': row['tipe'],
    'createdAt': row['created_at'],
  });

  Future<List<Jadwal>> getAllJadwal() async {
    await _syncJadwal();
    final db = await database;
    final result = await db.query(
      'jadwal',
      where: 'userId = ?',
      whereArgs: [_currentUserId],
      orderBy: 'jamMulai ASC',
    );
    return result.map(Jadwal.fromMap).toList();
  }

  Future<List<Jadwal>> getJadwalByTanggal(String tanggal) async {
    final jadwal = await getAllJadwal();
    return jadwal.where((item) => item.tanggal == tanggal).toList();
  }

  Future<List<Jadwal>> getJadwalForDate({
    required String tanggal,
    required String hari,
  }) async {
    final schedulesForDate = await getJadwalByTanggal(tanggal);
    if (schedulesForDate.isNotEmpty) return schedulesForDate;
    return getJadwalByHari(hari);
  }

  Future<List<Jadwal>> getJadwalByHari(String hari) async {
    final jadwal = await getAllJadwal();
    return jadwal.where((item) => item.hari == hari).toList();
  }

  Future<List<String>> getDatesWithJadwal() async {
    final jadwal = await getAllJadwal();
    return jadwal.map((item) => item.tanggal).toSet().toList();
  }

  Future<int> insertJadwal(Jadwal jadwal) async {
    final item = jadwal.copyWith(userId: _currentUserId);
    final db = await database;
    final id = await db.insert('jadwal', item.toMap());
    await _syncJadwal();
    return id;
  }

  Future<int> updateJadwal(Jadwal jadwal) async {
    final item = jadwal.copyWith(userId: _currentUserId);
    final db = await database;
    final updated = await db.update(
      'jadwal',
      item.toMap(),
      where: 'id = ? AND userId = ?',
      whereArgs: [item.id, _currentUserId],
    );
    await _syncJadwal();
    return updated;
  }

  Future<int> deleteJadwal(int id, {String? docId}) async {
    final client = SupabaseConfig.client;
    if (client != null && docId != null) {
      try {
        await client
            .from('jadwal')
            .delete()
            .eq('id', docId)
            .eq('user_id', _currentUserId);
      } on PostgrestException catch (error) {
        debugPrint('Supabase jadwal delete failed: ${error.message}');
      } on Exception catch (error) {
        debugPrint('Supabase jadwal delete failed: $error');
      }
    }

    final db = await database;
    return db.delete(
      'jadwal',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, _currentUserId],
    );
  }

  Future<List<Catatan>> getAllCatatan() async {
    await _syncCatatan();
    final db = await database;
    final result = await db.query(
      'catatan',
      where: 'userId = ?',
      whereArgs: [_currentUserId],
      orderBy: 'mingguKe ASC, createdAt DESC',
    );
    return result.map(Catatan.fromMap).toList();
  }

  Future<List<Catatan>> getCatatanByMataKuliah(String mataKuliah) async {
    final catatan = await getAllCatatan();
    return catatan.where((item) => item.mataKuliah == mataKuliah).toList();
  }

  Future<int> insertCatatan(Catatan catatan) async {
    final item = catatan.copyWith(userId: _currentUserId);
    final db = await database;
    final id = await db.insert('catatan', item.toMap());
    await _syncCatatan();
    return id;
  }

  Future<int> updateCatatan(Catatan catatan) async {
    final item = catatan.copyWith(userId: _currentUserId);
    final db = await database;
    final updated = await db.update(
      'catatan',
      item.toMap(),
      where: 'id = ? AND userId = ?',
      whereArgs: [item.id, _currentUserId],
    );
    await _syncCatatan();
    return updated;
  }

  Future<int> deleteCatatan(int id, {String? docId}) async {
    final client = SupabaseConfig.client;
    if (client != null && docId != null) {
      try {
        await client
            .from('catatan')
            .delete()
            .eq('id', docId)
            .eq('user_id', _currentUserId);
      } on PostgrestException catch (error) {
        debugPrint('Supabase catatan delete failed: ${error.message}');
      } on Exception catch (error) {
        debugPrint('Supabase catatan delete failed: $error');
      }
    }

    final db = await database;
    return db.delete(
      'catatan',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, _currentUserId],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
