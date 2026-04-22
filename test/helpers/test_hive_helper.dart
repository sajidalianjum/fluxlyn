import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxlyn/src/features/connections/models/connection_model.dart';
import 'package:fluxlyn/src/features/queries/models/query_model.dart';

class TestHiveHelper {
  static bool _initialized = false;
  static Directory? _testDir;

  static Future<void> setup() async {
    if (_initialized) return;

    _testDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(_testDir!.path);

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ConnectionTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ConnectionTagAdapter());
    }
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ConnectionModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(QueryModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(QueryHistoryEntryAdapter());
    }

    _initialized = true;
  }

  static Future<void> tearDown() async {
    await Hive.close();
    if (_testDir != null && _testDir!.existsSync()) {
      await _testDir!.delete(recursive: true);
    }
    _initialized = false;
    _testDir = null;
  }

  static Future<Box<T>> openTestBox<T>(String name) async {
    return await Hive.openBox<T>(name);
  }
}