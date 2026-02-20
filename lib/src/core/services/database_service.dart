import '../../features/connections/models/connection_model.dart';
import 'database_driver.dart';
import 'mysql_driver.dart';
import 'postgres_driver.dart';

class DatabaseService {
  static DatabaseDriver createDriver(ConnectionType type) {
    switch (type) {
      case ConnectionType.mysql:
        return MySQLDriver();
      case ConnectionType.postgresql:
        return PostgreSQLDriver();
    }
  }
}
