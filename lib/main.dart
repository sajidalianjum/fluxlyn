import 'package:flutter/material.dart';
import 'src/app.dart';
import 'src/core/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final storageService = StorageService();
  await storageService.init();
  
  runApp(MyApp(storageService: storageService));
}
