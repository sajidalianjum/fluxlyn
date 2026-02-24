import 'package:flutter_test/flutter_test.dart';
import 'package:fluxlyn/src/core/services/sql_formatter.dart';

void main() {
  group('SQLFormatter', () {
    test('formats simple SELECT query', () {
      const input = "select id, name from users where id = 1";
      final result = SQLFormatter.format(input);

      expect(result.contains('SELECT'), true);
      expect(result.contains('FROM'), true);
      expect(result.contains('WHERE'), true);
      expect(result.contains('\n'), true);
    });

    test('formats query with LEFT JOIN', () {
      const input = """
SELECT u.id, u.name, COUNT(o.id) AS order_count 
FROM users u 
LEFT JOIN orders o ON u.id = o.user_id 
WHERE u.active = TRUE AND u.created_at > '2024-01-01' 
GROUP BY u.id, u.name 
HAVING COUNT(o.id) > 5 
ORDER BY order_count DESC 
LIMIT 10;
""";

      final result = SQLFormatter.format(input);

      expect(result, contains('SELECT'));
      expect(result, contains('LEFT'));
      expect(result, contains('JOIN'));
      expect(result, contains('ON'));
      expect(result, contains('WHERE'));
      expect(result, contains('GROUP'));
      expect(result, contains('BY'));
      expect(result, contains('HAVING'));
      expect(result, contains('ORDER'));
      expect(result, contains('LIMIT'));
      expect(result.contains('\n'), true);
    });

    test('formats INSERT statement', () {
      const input =
          "insert into users (id, name, email) values (1, 'John', 'john@example.com')";
      final result = SQLFormatter.format(input);

      expect(result, contains('INSERT'));
      expect(result, contains('INTO'));
      expect(result, contains('VALUES'));
      expect(result.contains('\n'), true);
    });

    test('formats UPDATE statement', () {
      const input = "update users set name = 'Jane' where id = 1";
      final result = SQLFormatter.format(input);

      expect(result, contains('UPDATE'));
      expect(result, contains('SET'));
      expect(result, contains('WHERE'));
      expect(result.contains('\n'), true);
    });

    test('formats DELETE statement', () {
      const input = "delete from users where id = 1";
      final result = SQLFormatter.format(input);

      expect(result, contains('DELETE'));
      expect(result, contains('FROM'));
      expect(result, contains('WHERE'));
      expect(result.contains('\n'), true);
    });

    test('handles CASE WHEN THEN ELSE END', () {
      const input =
          "select case when age < 18 then 'minor' else 'adult' end as age_group from users";
      final result = SQLFormatter.format(input);

      expect(result, contains('CASE'));
      expect(result, contains('WHEN'));
      expect(result, contains('THEN'));
      expect(result, contains('ELSE'));
      expect(result, contains('END'));
      expect(result.contains('\n'), true);
    });

    test('handles subqueries in parentheses', () {
      const input = "select * from (select id, name from users) as u";
      final result = SQLFormatter.format(input);

      expect(result, contains('SELECT'));
      expect(result, contains('('));
      expect(result, contains(')'));
      expect(result.contains('\n'), true);
    });

    test('handles UNION', () {
      const input = "select id from users union select id from admins";
      final result = SQLFormatter.format(input);

      expect(result, contains('UNION'));
      expect(result.contains('\n'), true);
    });

    test('handles various JOIN types', () {
      const input = """
SELECT * FROM a 
INNER JOIN b ON a.id = b.a_id 
LEFT JOIN c ON b.id = c.b_id 
RIGHT JOIN d ON c.id = d.c_id 
FULL JOIN e ON d.id = e.d_id
""";

      final result = SQLFormatter.format(input);

      expect(result, contains('INNER'));
      expect(result, contains('JOIN'));
      expect(result, contains('LEFT'));
      expect(result, contains('RIGHT'));
      expect(result, contains('FULL'));
      expect(result.contains('\n'), true);
    });

    test('preserves string literals', () {
      const input = "select name from users where email = 'test@example.com'";
      final result = SQLFormatter.format(input);

      expect(result, contains("'test@example.com'"));
    });

    test('preserves backtick identifiers', () {
      const input = "select `user_id`, `user_name` from `users`";
      final result = SQLFormatter.format(input);

      expect(result, contains('`user_id`'));
      expect(result, contains('`user_name`'));
      expect(result, contains('`users`'));
    });

    test('handles AND/OR with proper indentation', () {
      const input =
          "select * from users where id = 1 and name = 'John' or email = 'john@example.com'";
      final result = SQLFormatter.format(input);

      expect(result, contains('AND'));
      expect(result, contains('OR'));
      expect(result.contains('\n'), true);
    });

    test('handles GROUP BY and ORDER BY', () {
      const input =
          "select count(*) from users group by name order by count(*) desc";
      final result = SQLFormatter.format(input);

      expect(result, contains('GROUP'));
      expect(result, contains('ORDER'));
      expect(result.contains('\n'), true);
    });

    test('handles LIMIT and OFFSET', () {
      const input = "select * from users limit 10 offset 20";
      final result = SQLFormatter.format(input);

      expect(result, contains('LIMIT'));
      expect(result, contains('OFFSET'));
      expect(result.contains('\n'), true);
    });

    test('handles semicolon separator', () {
      const input = "select * from users; select * from admins";
      final result = SQLFormatter.format(input);

      expect(result, contains(';'));
      expect(result.contains('\n\n'), true);
    });

    test('supports lowercase option', () {
      const input = "select id from users where id = 1";
      final result = SQLFormatter.format(input, uppercase: false);

      expect(result, contains('select'));
      expect(result, contains('from'));
      expect(result, contains('where'));
    });

    test('supports custom indent option', () {
      const input = "select id from users where id = 1";
      final result1 = SQLFormatter.format(input, indent: 2);
      final result2 = SQLFormatter.format(input, indent: 4);

      expect(result1.contains('\n'), true);
      expect(result2.contains('\n'), true);
    });

    test('handles empty string', () {
      final result = SQLFormatter.format('');
      expect(result, '');
    });

    test('handles NULL values', () {
      const input = "select name from users where email is null";
      final result = SQLFormatter.format(input);

      expect(result, contains('IS NULL'));
    });

    test('handles IN operator', () {
      const input = "select * from users where id in (1, 2, 3)";
      final result = SQLFormatter.format(input);

      expect(result, contains('IN'));
    });

    test('handles NOT operator', () {
      const input = "select * from users where not active";
      final result = SQLFormatter.format(input);

      expect(result, contains('NOT'));
    });

    test('formats complex nested query', () {
      const input = """
select u.id, u.name, (select count(*) from orders o where o.user_id = u.id) as order_count
from users u
where u.active = true
and (select count(*) from orders o where o.user_id = u.id) > 0
order by order_count desc
limit 10
""";

      final result = SQLFormatter.format(input);

      expect(result, contains('SELECT'));
      expect(result, contains('FROM'));
      expect(result, contains('WHERE'));
      expect(result, contains('AND'));
      expect(result, contains('ORDER'));
      expect(result, contains('LIMIT'));
      expect(result.contains('\n'), true);
    });
  });
}
