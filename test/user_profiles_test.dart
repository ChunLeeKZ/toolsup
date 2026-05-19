import 'package:flutter_test/flutter_test.dart';
import 'package:toolsup/user_profiles.dart';

void main() {
  test('parses user profile photo fields', () {
    final profile = appUserProfileFromRow({
      'id': 'user-1',
      'email': 'user@example.com',
      'display_name': 'User Name',
      'iin': 123456789012,
      'organization_bin': '123456789012',
      'organization_name': 'ToolsUp ТОО',
      'photo_bucket': 'user-profile-photos',
      'photo_path': 'user-1/avatar.jpg',
      'photo_mime_type': 'image/jpeg',
      'photo_uploaded_at': '2026-05-19T10:00:00Z',
    });

    expect(profile.title, 'User Name');
    expect(profile.iinText, '123456789012');
    expect(profile.organizationBinText, '123456789012');
    expect(profile.organizationNameText, 'ToolsUp ТОО');
    expect(profile.hasPhoto, isTrue);
    expect(profile.photoBucket, 'user-profile-photos');
    expect(profile.photoPath, 'user-1/avatar.jpg');
    expect(profile.photoUploadedAt, isNotNull);
  });

  test('uses email as profile title when display name is empty', () {
    final profile = appUserProfileFromRow({
      'id': 'user-1',
      'email': 'user@example.com',
      'display_name': '',
      'iin': 123456789012,
    });

    expect(profile.title, 'user@example.com');
    expect(profile.organizationBinText, 'Не указан');
    expect(profile.organizationNameText, 'Не указана');
    expect(profile.hasPhoto, isFalse);
  });

  test('parses organization directory row', () {
    final organization = organizationFromRow({
      'bin': '123456789012',
      'short_name': 'ToolsUp',
      'full_name': 'Товарищество с ограниченной ответственностью ToolsUp',
    });

    expect(organization.bin, '123456789012');
    expect(organization.title, 'ToolsUp');
    expect(
      organization.subtitle,
      '123456789012 • Товарищество с ограниченной ответственностью ToolsUp',
    );
  });
}
