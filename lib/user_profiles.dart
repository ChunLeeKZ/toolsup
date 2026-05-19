import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class AppUserProfile {
  const AppUserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.iin,
    this.organizationBin,
    this.organizationName,
    this.photoBucket,
    this.photoPath,
    this.photoMimeType,
    this.photoUploadedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final int iin;
  final String? organizationBin;
  final String? organizationName;
  final String? photoBucket;
  final String? photoPath;
  final String? photoMimeType;
  final DateTime? photoUploadedAt;

  AppUserProfile copyWith({String? organizationBin, String? organizationName}) {
    return AppUserProfile(
      id: id,
      email: email,
      displayName: displayName,
      iin: iin,
      organizationBin: organizationBin ?? this.organizationBin,
      organizationName: organizationName ?? this.organizationName,
      photoBucket: photoBucket,
      photoPath: photoPath,
      photoMimeType: photoMimeType,
      photoUploadedAt: photoUploadedAt,
    );
  }

  String get title {
    return displayName.isEmpty ? email : displayName;
  }

  String get iinText {
    return iin.toString().padLeft(12, '0');
  }

  String get organizationBinText {
    final value = organizationBin?.trim();
    return value == null || value.isEmpty ? 'Не указан' : value;
  }

  String get organizationNameText {
    final value = organizationName?.trim();
    return value == null || value.isEmpty ? 'Не указана' : value;
  }

  bool get hasPhoto {
    return photoBucket != null &&
        photoBucket!.isNotEmpty &&
        photoPath != null &&
        photoPath!.isNotEmpty;
  }
}

class Organization {
  const Organization({
    required this.bin,
    required this.shortName,
    required this.fullName,
  });

  final String bin;
  final String shortName;
  final String fullName;

  String get title {
    return shortName.isEmpty ? fullName : shortName;
  }

  String get subtitle {
    return fullName.isEmpty || fullName == title ? bin : '$bin • $fullName';
  }
}

Organization organizationFromRow(Map<String, dynamic> row) {
  return Organization(
    bin: row['bin']?.toString() ?? '',
    shortName: row['short_name']?.toString() ?? '',
    fullName: row['full_name']?.toString() ?? '',
  );
}

AppUserProfile appUserProfileFromRow(Map<String, dynamic> row) {
  return AppUserProfile(
    id: row['id']?.toString() ?? '',
    email: row['email']?.toString() ?? '',
    displayName: row['display_name']?.toString() ?? '',
    iin: _asInt(row['iin']),
    organizationBin: row['organization_bin']?.toString(),
    organizationName: row['organization_name']?.toString(),
    photoBucket: row['photo_bucket']?.toString(),
    photoPath: row['photo_path']?.toString(),
    photoMimeType: row['photo_mime_type']?.toString(),
    photoUploadedAt: _asNullableDateTime(row['photo_uploaded_at']),
  );
}

class PickedUserPhoto {
  const PickedUserPhoto({
    required this.fileName,
    required this.bytes,
    required this.sizeBytes,
    required this.mimeType,
  });

  final String fileName;
  final Uint8List bytes;
  final int sizeBytes;
  final String mimeType;
}

class UserProfileRepository {
  const UserProfileRepository();

  static const _profilesTable = 'app_user_profiles';
  static const _organizationsTable = 'organizations';
  static const _photosBucket = 'user-profile-photos';
  static const _profileSelect = '''
id,
email,
display_name,
iin,
organization_bin,
organization_name,
photo_bucket,
photo_path,
photo_mime_type,
photo_uploaded_at
''';
  static const _legacyProfileSelect = '''
id,
email,
display_name,
iin,
photo_bucket,
photo_path,
photo_mime_type,
photo_uploaded_at
''';

  SupabaseClient get _client => Supabase.instance.client;

  Future<AppUserProfile> getCurrentProfile(User user) async {
    await syncCurrentUserProfile(_client, user);

    final rows = await _selectCurrentUserRows(user.id);

    if (rows.isNotEmpty) {
      final profile = appUserProfileFromRow(
        Map<String, dynamic>.from(rows.first),
      );
      return _withOrganizationFromDirectory(profile);
    }

    return profileFromAuthUser(user);
  }

  Future<List<Organization>> getOrganizations() async {
    final rows = await _client
        .from(_organizationsTable)
        .select('bin,short_name,full_name')
        .order('short_name', ascending: true)
        .order('bin', ascending: true);

    return rows
        .map((row) => organizationFromRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<AppUserProfile> updateCurrentUserOrganization({
    required User user,
    required Organization organization,
  }) async {
    await syncCurrentUserProfile(_client, user);

    final row = await _client
        .from(_profilesTable)
        .update({
          'organization_bin': organization.bin,
          'organization_name': organization.title,
        })
        .eq('id', user.id)
        .select(_profileSelect)
        .single();

    return appUserProfileFromRow(row).copyWith(
      organizationBin: organization.bin,
      organizationName: organization.title,
    );
  }

  Future<AppUserProfile> uploadCurrentUserPhoto({
    required User user,
    required PickedUserPhoto photo,
  }) async {
    await syncCurrentUserProfile(_client, user);

    final fileName = _sanitizeStorageFileName(photo.fileName);
    final photoPath =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage
        .from(_photosBucket)
        .uploadBinary(
          photoPath,
          photo.bytes,
          fileOptions: FileOptions(contentType: photo.mimeType, upsert: false),
        );

    final photoFields = {
      'photo_bucket': _photosBucket,
      'photo_path': photoPath,
      'photo_mime_type': photo.mimeType,
      'photo_uploaded_at': DateTime.now().toUtc().toIso8601String(),
    };
    final row = await _updatePhotoFields(user.id, photoFields);

    return appUserProfileFromRow(row);
  }

  Future<String?> createPhotoUrl(AppUserProfile profile) async {
    if (!profile.hasPhoto) {
      return null;
    }

    return _client.storage
        .from(profile.photoBucket!)
        .createSignedUrl(profile.photoPath!, 60 * 60);
  }

  Future<AppUserProfile> _withOrganizationFromDirectory(
    AppUserProfile profile,
  ) async {
    final organizationBin = profile.organizationBin?.trim();
    if (organizationBin == null || organizationBin.isEmpty) {
      return profile;
    }

    try {
      final rows = await _client
          .from(_organizationsTable)
          .select('bin,short_name,full_name')
          .eq('bin', organizationBin)
          .limit(1);
      if (rows.isEmpty) {
        return profile;
      }
      final organization = organizationFromRow(
        Map<String, dynamic>.from(rows.first),
      );
      return profile.copyWith(
        organizationBin: organization.bin,
        organizationName: organization.title,
      );
    } catch (_) {
      return profile;
    }
  }

  Future<List<dynamic>> _selectCurrentUserRows(String userId) async {
    try {
      return await _client
          .from(_profilesTable)
          .select(_profileSelect)
          .eq('id', userId)
          .limit(1);
    } catch (error) {
      if (!_isMissingColumnError(error)) {
        rethrow;
      }
      return _client
          .from(_profilesTable)
          .select(_legacyProfileSelect)
          .eq('id', userId)
          .limit(1);
    }
  }

  Future<Map<String, dynamic>> _updatePhotoFields(
    String userId,
    Map<String, Object?> photoFields,
  ) async {
    try {
      return await _client
          .from(_profilesTable)
          .update(photoFields)
          .eq('id', userId)
          .select(_profileSelect)
          .single();
    } catch (error) {
      if (!_isMissingColumnError(error)) {
        rethrow;
      }
      return _client
          .from(_profilesTable)
          .update(photoFields)
          .eq('id', userId)
          .select(_legacyProfileSelect)
          .single();
    }
  }
}

AppUserProfile profileFromAuthUser(User user) {
  final email = user.email ?? '';
  final rawIin = user.userMetadata?['iin']?.toString() ?? '0';
  final displayName = user.userMetadata?['display_name']?.toString();
  final organizationBin = user.userMetadata?['organization_bin']?.toString();
  final organizationName = user.userMetadata?['organization_name']?.toString();

  return AppUserProfile(
    id: user.id,
    email: email,
    displayName: displayName == null || displayName.isEmpty
        ? email
        : displayName,
    iin: int.tryParse(rawIin) ?? 0,
    organizationBin: organizationBin,
    organizationName: organizationName,
  );
}

Future<void> syncCurrentUserProfile(SupabaseClient client, User user) async {
  final email = user.email;
  final rawIin = user.userMetadata?['iin']?.toString();
  if (email == null ||
      rawIin == null ||
      !RegExp(r'^\d{12}$').hasMatch(rawIin)) {
    return;
  }

  final displayName = user.userMetadata?['display_name']?.toString();

  try {
    await client.from('app_user_profiles').upsert({
      'id': user.id,
      'email': email,
      'display_name': displayName == null || displayName.isEmpty
          ? email
          : displayName,
      'iin': int.parse(rawIin),
    }, onConflict: 'id');
  } catch (_) {
    // The profile table is created by a Supabase migration. Authentication
    // should keep working even if that migration has not been applied yet.
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.parse(value.toString());
}

DateTime? _asNullableDateTime(Object? value) {
  if (value == null || value.toString().isEmpty) {
    return null;
  }
  return DateTime.parse(value.toString()).toLocal();
}

bool _isMissingColumnError(Object error) {
  return error is PostgrestException && error.code == '42703';
}

String _sanitizeStorageFileName(String fileName) {
  final sanitized = fileName
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s+'), '_');
  return sanitized.isEmpty ? 'profile_photo' : sanitized;
}
