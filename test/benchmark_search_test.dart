// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kirtan_finder/core/database/database_migrator.dart';
import 'package:kirtan_finder/core/database/database_service.dart';
import 'package:kirtan_finder/core/models/part.dart';
import 'package:kirtan_finder/core/repositories/kirtan_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late DatabaseService dbService;
  late KirtanRepository kirtanRepo;
  late String testDbPath;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final sourcePath = 'assets/db/kirtan_finder.db';
    testDbPath = '${Directory.current.path}/test_benchmark_kirtan_finder.db';
    final src = File(sourcePath);
    if (await src.exists()) {
      await src.copy(testDbPath);
    } else {
      final fallback = File('../database/kirtan_finder.db');
      await fallback.copy(testDbPath);
    }

    db = await databaseFactoryFfi.openDatabase(testDbPath);
    await DatabaseMigrator.migrate(db);
    dbService = DatabaseService.withDatabase(db);
    kirtanRepo = KirtanRepository(dbService);
  });

  tearDownAll(() async {
    await db.close();
    final f = File(testDbPath);
    if (await f.exists()) {
      await f.delete();
    }
  });

  test('Performance Benchmark Suite for n-IDs and Search 1 / 2', () async {
    final benchmarks = <String, double>{};

    // Warm-up queries
    await kirtanRepo.searchTitle(query: 'राधा');
    await kirtanRepo.searchTitle(query: 'n1541');
    await kirtanRepo.searchTitle(query: '25');

    const iterations = 50;

    Future<double> benchmark(Future<void> Function() action) async {
      final sw = Stopwatch()..start();
      for (int i = 0; i < iterations; i++) {
        await action();
      }
      sw.stop();
      return sw.elapsedMicroseconds / (iterations * 1000.0);
    }

    // 1. Benchmark public n-IDs: n1, n123, n1541, n6584 across all parts and filtered parts
    final testIds = ['n1', 'n123', 'n1541', 'n6584'];
    final filters = [
      ('All Parts', PartFilter.all),
      ('Part 1', PartFilter.part1),
      ('Part 2', PartFilter.part2),
      ('Part 3', PartFilter.part3),
      ('Part 4', PartFilter.part4),
    ];

    for (final id in testIds) {
      for (final (label, filter) in filters) {
        benchmarks['Exact $id ($label)'] = await benchmark(() async {
          await kirtanRepo.searchTitle(query: id, partFilter: filter);
        });
      }
    }

    // 2. Page lookup
    benchmarks['Page lookup ("25")'] = await benchmark(() async {
      await kirtanRepo.searchTitle(query: '25');
    });

    benchmarks['Page with Part 2 filter ("25")'] = await benchmark(() async {
      await kirtanRepo.searchTitle(query: '25', partFilter: PartFilter.part2);
    });

    // 3. Hindi substring search
    benchmarks['Hindi substring ("राधा")'] = await benchmark(() async {
      await kirtanRepo.searchTitle(query: 'राधा');
    });

    benchmarks['Hindi substring with Part 1 filter ("राधा")'] = await benchmark(() async {
      await kirtanRepo.searchTitle(query: 'राधा', partFilter: PartFilter.part1);
    });

    // 4. English substring search
    benchmarks['English substring ("Radha")'] = await benchmark(() async {
      await kirtanRepo.searchTitle(query: 'Radha');
    });

    benchmarks['English substring with Part 2 filter ("Radha")'] = await benchmark(() async {
      await kirtanRepo.searchTitle(query: 'Radha', partFilter: PartFilter.part2);
    });

    // 5. raw_first_line match
    benchmarks['Raw first line query ("सघन कुंज")'] = await benchmark(() async {
      await kirtanRepo.searchTitle(query: 'सघन कुंज');
    });

    // 6. Search 2 lines search
    benchmarks['Search 2 lines ("श्री कृष्ण")'] = await benchmark(() async {
      await kirtanRepo.searchLines(query: 'श्री कृष्ण');
    });

    print('\n================ SEARCH BENCHMARK RESULTS ================');
    benchmarks.forEach((name, avgMs) {
      print('${name.padRight(48)} : ${avgMs.toStringAsFixed(2)} ms');
    });
    print('==========================================================\n');

    expect(benchmarks['Exact n1541 (All Parts)'], lessThan(10.0));
    expect(benchmarks['Page lookup ("25")'], lessThan(10.0));
    expect(benchmarks['Hindi substring ("राधा")'], lessThan(25.0));
  });
}
