import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../models/ticket_status.dart';

class CachedCitizenReportPage {
  const CachedCitizenReportPage({
    required this.reports,
    required this.currentPage,
    required this.lastPage,
    required this.syncedAt,
  });

  final List<TicketStatus> reports;
  final int currentPage;
  final int lastPage;
  final DateTime syncedAt;
}

class CachedCitizenReportDetail {
  const CachedCitizenReportDetail({
    required this.report,
    required this.syncedAt,
  });

  final TicketStatus report;
  final DateTime syncedAt;
}

class CachedReportAccess {
  const CachedReportAccess({required this.code, required this.accessedAt});

  final String code;
  final DateTime accessedAt;
}

class CitizenReportCache {
  CitizenReportCache({
    DatabaseFactory? databaseFactoryOverride,
    this.databasePath,
    DateTime Function()? clock,
  }) : _databaseFactory = databaseFactoryOverride,
       _clock = clock ?? DateTime.now;

  static final instance = CitizenReportCache();

  static const databaseVersion = 1;
  static const cacheTtl = Duration(days: 30);
  static const accessHistoryTtl = Duration(days: 180);
  static const databaseName = 'citizen_reports.db';

  final DatabaseFactory? _databaseFactory;
  final String? databasePath;
  final DateTime Function() _clock;
  Future<Database>? _opening;

  Future<Database> get _database async {
    final existing = _opening;
    if (existing != null) return existing;

    final opening = _openDatabase();
    _opening = opening;
    try {
      return await opening;
    } on Exception {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final path =
        databasePath ??
        '${await getDatabasesPath()}${Platform.pathSeparator}$databaseName';
    final factory = _databaseFactory ?? databaseFactory;
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion < 1) await _createSchema(database, newVersion);
        },
      ),
    );
  }

  Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE citizen_report_pages (
        account_id TEXT NOT NULL,
        status_filter TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        page INTEGER NOT NULL,
        per_page INTEGER NOT NULL,
        current_page INTEGER NOT NULL,
        last_page INTEGER NOT NULL,
        synced_at TEXT NOT NULL,
        PRIMARY KEY (
          account_id, status_filter, start_date, end_date, page, per_page
        )
      )
    ''');
    await database.execute('''
      CREATE TABLE citizen_report_page_items (
        account_id TEXT NOT NULL,
        status_filter TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        page INTEGER NOT NULL,
        per_page INTEGER NOT NULL,
        position INTEGER NOT NULL,
        report_code TEXT NOT NULL,
        payload TEXT NOT NULL,
        PRIMARY KEY (
          account_id, status_filter, start_date, end_date,
          page, per_page, position
        ),
        FOREIGN KEY (
          account_id, status_filter, start_date, end_date, page, per_page
        ) REFERENCES citizen_report_pages (
          account_id, status_filter, start_date, end_date, page, per_page
        ) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE citizen_report_details (
        account_id TEXT NOT NULL,
        code TEXT NOT NULL,
        payload TEXT NOT NULL,
        fetched_at TEXT NOT NULL,
        PRIMARY KEY (account_id, code)
      )
    ''');
    await database.execute('''
      CREATE TABLE citizen_report_access_history (
        account_id TEXT NOT NULL,
        code TEXT NOT NULL,
        accessed_at TEXT NOT NULL,
        PRIMARY KEY (account_id, code)
      )
    ''');
    await database.execute(
      'CREATE INDEX idx_citizen_report_pages_sync '
      'ON citizen_report_pages (synced_at)',
    );
    await database.execute(
      'CREATE INDEX idx_citizen_report_details_fetch_time '
      'ON citizen_report_details (fetched_at)',
    );
    await database.execute(
      'CREATE INDEX idx_citizen_report_access_time '
      'ON citizen_report_access_history (account_id, accessed_at)',
    );
  }

  Future<CachedCitizenReportPage?> readPage({
    required String accountId,
    required int page,
    required int perPage,
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    _validateAccountId(accountId);
    final database = await _database;
    final filter = _filterValues(
      status: status,
      startDate: startDate,
      endDate: endDate,
    );
    return database.transaction((transaction) async {
      await _pruneExpired(transaction);
      final pageRows = await transaction.query(
        'citizen_report_pages',
        where:
            'account_id = ? AND status_filter = ? AND start_date = ? '
            'AND end_date = ? AND page = ? AND per_page = ?',
        whereArgs: [accountId, ...filter, page, perPage],
        limit: 1,
      );
      if (pageRows.isEmpty) return null;

      final metadata = pageRows.single;
      final itemRows = await transaction.rawQuery(
        '''
        SELECT items.payload
        FROM citizen_report_page_items AS items
        WHERE items.account_id = ?
          AND items.status_filter = ?
          AND items.start_date = ?
          AND items.end_date = ?
          AND items.page = ?
          AND items.per_page = ?
        ORDER BY items.position
        ''',
        [accountId, ...filter, page, perPage],
      );
      try {
        final reports = itemRows
            .map((row) {
              final decoded = jsonDecode(row['payload']! as String);
              if (decoded is! Map) {
                throw const FormatException(
                  'Cached report is not a JSON object.',
                );
              }
              return TicketStatus.fromJson(Map<String, dynamic>.from(decoded));
            })
            .toList(growable: false);
        return CachedCitizenReportPage(
          reports: reports,
          currentPage: metadata['current_page']! as int,
          lastPage: metadata['last_page']! as int,
          syncedAt: DateTime.parse(metadata['synced_at']! as String).toLocal(),
        );
      } on FormatException {
        await transaction.delete(
          'citizen_report_pages',
          where:
              'account_id = ? AND status_filter = ? AND start_date = ? '
              'AND end_date = ? AND page = ? AND per_page = ?',
          whereArgs: [accountId, ...filter, page, perPage],
        );
        return null;
      } on TypeError {
        await transaction.delete(
          'citizen_report_pages',
          where:
              'account_id = ? AND status_filter = ? AND start_date = ? '
              'AND end_date = ? AND page = ? AND per_page = ?',
          whereArgs: [accountId, ...filter, page, perPage],
        );
        return null;
      }
    });
  }

  Future<void> savePage({
    required String accountId,
    required int page,
    required int perPage,
    required int currentPage,
    required int lastPage,
    required List<TicketStatus> reports,
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    _validateAccountId(accountId);
    if (page < 1 || perPage < 1 || currentPage < 1 || lastPage < currentPage) {
      throw ArgumentError('Pagination cache parameters are invalid.');
    }
    final database = await _database;
    final filter = _filterValues(
      status: status,
      startDate: startDate,
      endDate: endDate,
    );
    final syncedAt = _clock().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      final uniqueReports = <String, TicketStatus>{};
      for (final report in reports) {
        final code = report.code.trim();
        if (code.isNotEmpty) uniqueReports.putIfAbsent(code, () => report);
      }

      await transaction.insert('citizen_report_pages', {
        'account_id': accountId,
        'status_filter': filter[0],
        'start_date': filter[1],
        'end_date': filter[2],
        'page': page,
        'per_page': perPage,
        'current_page': currentPage,
        'last_page': lastPage,
        'synced_at': syncedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await transaction.delete(
        'citizen_report_page_items',
        where:
            'account_id = ? AND status_filter = ? AND start_date = ? '
            'AND end_date = ? AND page = ? AND per_page = ?',
        whereArgs: [accountId, ...filter, page, perPage],
      );
      var position = 0;
      for (final entry in uniqueReports.entries) {
        await transaction.insert('citizen_report_page_items', {
          'account_id': accountId,
          'status_filter': filter[0],
          'start_date': filter[1],
          'end_date': filter[2],
          'page': page,
          'per_page': perPage,
          'position': position++,
          'report_code': entry.key,
          'payload': jsonEncode(entry.value.toJson()),
        });
      }
      await _pruneExpired(transaction);
    });
  }

  Future<CachedCitizenReportDetail?> readDetail({
    required String accountId,
    required String code,
  }) async {
    _validateAccountId(accountId);
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) return null;
    final database = await _database;
    return database.transaction((transaction) async {
      await _pruneExpired(transaction);
      final rows = await transaction.query(
        'citizen_report_details',
        columns: ['payload', 'fetched_at'],
        where: 'account_id = ? AND code = ?',
        whereArgs: [accountId, normalizedCode],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      try {
        final decoded = jsonDecode(rows.single['payload']! as String);
        if (decoded is! Map) {
          throw const FormatException('Cached report detail is not an object.');
        }
        await transaction.insert('citizen_report_access_history', {
          'account_id': accountId,
          'code': normalizedCode,
          'accessed_at': _clock().toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        return CachedCitizenReportDetail(
          report: TicketStatus.fromJson(Map<String, dynamic>.from(decoded)),
          syncedAt: DateTime.parse(rows.single['fetched_at']! as String)
              .toLocal(),
        );
      } on FormatException {
        await transaction.delete(
          'citizen_report_details',
          where: 'account_id = ? AND code = ?',
          whereArgs: [accountId, normalizedCode],
        );
        return null;
      } on TypeError {
        await transaction.delete(
          'citizen_report_details',
          where: 'account_id = ? AND code = ?',
          whereArgs: [accountId, normalizedCode],
        );
        return null;
      }
    });
  }

  Future<void> saveDetail({
    required String accountId,
    required TicketStatus report,
  }) async {
    _validateAccountId(accountId);
    final code = report.code.trim();
    if (code.isEmpty) throw ArgumentError.value(report.code, 'report.code');
    final database = await _database;
    final fetchedAt = _clock().toUtc().toIso8601String();
    await database.transaction((transaction) async {
      await transaction.insert('citizen_report_details', {
        'account_id': accountId,
        'code': code,
        'payload': jsonEncode(report.toJson()),
        'fetched_at': fetchedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await transaction.insert('citizen_report_access_history', {
        'account_id': accountId,
        'code': code,
        'accessed_at': fetchedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _pruneExpired(transaction);
    });
  }

  Future<List<CachedReportAccess>> readRecentAccesses({
    required String accountId,
    int limit = 20,
  }) async {
    _validateAccountId(accountId);
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    final database = await _database;
    return database.transaction((transaction) async {
      await _pruneExpired(transaction);
      final rows = await transaction.query(
        'citizen_report_access_history',
        where: 'account_id = ?',
        whereArgs: [accountId],
        orderBy: 'accessed_at DESC',
        limit: limit,
      );
      return rows
          .map(
            (row) => CachedReportAccess(
              code: row['code']! as String,
              accessedAt: DateTime.parse(row['accessed_at']! as String)
                  .toLocal(),
            ),
          )
          .toList(growable: false);
    });
  }

  Future<void> clearAccount(String accountId) async {
    _validateAccountId(accountId);
    final database = await _database;
    await database.transaction((transaction) async {
      await transaction.delete(
        'citizen_report_pages',
        where: 'account_id = ?',
        whereArgs: [accountId],
      );
      await transaction.delete(
        'citizen_report_details',
        where: 'account_id = ?',
        whereArgs: [accountId],
      );
      await transaction.delete(
        'citizen_report_access_history',
        where: 'account_id = ?',
        whereArgs: [accountId],
      );
    });
  }

  Future<void> close() async {
    final database = await _opening;
    _opening = null;
    await database?.close();
  }

  List<String> _filterValues({
    String? status,
    String? startDate,
    String? endDate,
  }) {
    final normalizedStatus = status?.trim() ?? '';
    final normalizedStart = startDate?.trim() ?? '';
    final normalizedEnd = endDate?.trim() ?? '';
    if ((normalizedStart.isEmpty) != (normalizedEnd.isEmpty)) {
      throw ArgumentError(
        'Both report date filters must be provided together.',
      );
    }
    if (normalizedStart.isNotEmpty) {
      final start = DateTime.tryParse(normalizedStart);
      final end = DateTime.tryParse(normalizedEnd);
      if (start == null || end == null || start.isAfter(end)) {
        throw ArgumentError('Report date filter is invalid.');
      }
    }
    return [normalizedStatus, normalizedStart, normalizedEnd];
  }

  Future<void> _pruneExpired(DatabaseExecutor database) async {
    final now = _clock().toUtc();
    final pageCutoff = now.subtract(cacheTtl).toIso8601String();
    final historyCutoff = now.subtract(accessHistoryTtl).toIso8601String();
    await database.delete(
      'citizen_report_pages',
      where: 'synced_at < ?',
      whereArgs: [pageCutoff],
    );
    await database.delete(
      'citizen_report_details',
      where: 'fetched_at < ?',
      whereArgs: [pageCutoff],
    );
    await database.delete(
      'citizen_report_access_history',
      where: 'accessed_at < ?',
      whereArgs: [historyCutoff],
    );
  }

  void _validateAccountId(String accountId) {
    if (accountId.trim().isEmpty) {
      throw ArgumentError.value(accountId, 'accountId');
    }
  }
}
