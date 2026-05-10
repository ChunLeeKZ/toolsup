import 'package:flutter_test/flutter_test.dart';
import 'package:toolsup/login_page.dart';

void main() {
  group('auth validators', () {
    test('validates email', () {
      expect(emailError(''), 'Введите email');
      expect(emailError('wrong'), 'Введите корректный email');
      expect(emailError('user@example.com'), isNull);
      expect(emailError(' user@example.com '), isNull);
      expect(emailError('USER@EXAMPLE.COM'), isNull);
      expect(emailError('user@example'), 'Введите корректный email');
    });

    test('normalizes hidden email characters', () {
      expect(normalizeEmail(' USER@Example.COM '), 'user@example.com');
      expect(normalizeEmail('user\u200B@example.com'), 'user@example.com');
    });

    test('validates password', () {
      expect(passwordError(''), 'Введите пароль');
      expect(passwordError('12345'), 'Минимум 6 символов');
      expect(passwordError('123456'), isNull);
    });

    test('validates iin', () {
      expect(iinError(''), 'Введите ИИН');
      expect(iinError('123'), 'ИИН должен состоять из 12 цифр');
      expect(iinError('12345678901a'), 'ИИН должен состоять из 12 цифр');
      expect(iinError('123456789012'), isNull);
    });
  });
}
