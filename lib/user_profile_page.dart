import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'user_profiles.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    required this.user,
    this.repository = const UserProfileRepository(),
    super.key,
  });

  final User user;
  final UserProfileRepository repository;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  AppUserProfile? _profile;
  List<Organization> _organizations = const [];
  String? _selectedOrganizationBin;
  String? _photoUrl;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  bool _isSavingOrganization = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await widget.repository.getCurrentProfile(widget.user);
      var organizations = <Organization>[];
      String? organizationError;
      try {
        organizations = await widget.repository.getOrganizations();
      } catch (error) {
        organizationError =
            'Не удалось загрузить справочник организаций: $error';
      }
      final photoUrl = await widget.repository.createPhotoUrl(profile);
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _organizations = organizations;
        _selectedOrganizationBin = profile.organizationBin;
        _photoUrl = photoUrl;
        _errorMessage = organizationError;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Не удалось загрузить профиль: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectOrganization(String? organizationBin) async {
    if (organizationBin == null ||
        organizationBin == _selectedOrganizationBin) {
      return;
    }

    final organization = _organizations.firstWhere(
      (item) => item.bin == organizationBin,
    );

    setState(() {
      _isSavingOrganization = true;
      _errorMessage = null;
    });

    try {
      final profile = await widget.repository.updateCurrentUserOrganization(
        user: widget.user,
        organization: organization,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _selectedOrganizationBin = organization.bin;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Не удалось сохранить организацию: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSavingOrganization = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
    );

    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        _errorMessage = 'Не удалось прочитать выбранную фотографию.';
      });
      return;
    }

    setState(() {
      _isUploadingPhoto = true;
      _errorMessage = null;
    });

    try {
      final profile = await widget.repository.uploadCurrentUserPhoto(
        user: widget.user,
        photo: PickedUserPhoto(
          fileName: file.name,
          bytes: bytes,
          sizeBytes: file.size,
          mimeType: _mimeTypeFromFileName(file.name),
        ),
      );
      final photoUrl = await widget.repository.createPhotoUrl(profile);

      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _photoUrl = photoUrl;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Не удалось сохранить фотографию: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль пользователя')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadProfile,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: _ProfilePhoto(
                                photoUrl: _photoUrl,
                                fallbackText: _profile?.title ?? '',
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _isUploadingPhoto
                                  ? null
                                  : _pickAndUploadPhoto,
                              icon: _isUploadingPhoto
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.add_a_photo_outlined),
                              label: Text(
                                _profile?.hasPhoto == true
                                    ? 'Заменить фотографию'
                                    : 'Прикрепить фотографию',
                              ),
                            ),
                            const Divider(height: 32),
                            _ProfileField(
                              label: 'Имя пользователя',
                              value: _profile?.title ?? 'Не указано',
                            ),
                            _ProfileField(
                              label: 'Email',
                              value: _profile?.email ?? 'Не указан',
                            ),
                            _ProfileField(
                              label: 'ИИН',
                              value: _profile?.iinText ?? 'Не указан',
                            ),
                            _OrganizationSelector(
                              organizations: _organizations,
                              selectedBin: _selectedOrganizationBin,
                              onChanged: _isSavingOrganization
                                  ? null
                                  : _selectOrganization,
                              isSaving: _isSavingOrganization,
                            ),
                            _ProfileField(
                              label: 'БИН организации',
                              value:
                                  _profile?.organizationBinText ?? 'Не указан',
                            ),
                            _ProfileField(
                              label: 'Наименование организации',
                              value:
                                  _profile?.organizationNameText ??
                                  'Не указана',
                            ),
                            if (_profile?.photoUploadedAt != null)
                              _ProfileField(
                                label: 'Фото обновлено',
                                value: _formatDateTime(
                                  _profile!.photoUploadedAt!,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: colors.onErrorContainer),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _OrganizationSelector extends StatelessWidget {
  const _OrganizationSelector({
    required this.organizations,
    required this.selectedBin,
    required this.onChanged,
    required this.isSaving,
  });

  final List<Organization> organizations;
  final String? selectedBin;
  final ValueChanged<String?>? onChanged;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedValue = organizations.any((item) => item.bin == selectedBin)
        ? selectedBin
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        key: ValueKey(selectedValue),
        initialValue: selectedValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Организация',
          prefixIcon: const Icon(Icons.business_outlined),
          suffixIcon: isSaving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
        ),
        hint: const Text('Выберите организацию'),
        items: organizations
            .map(
              (organization) => DropdownMenuItem<String>(
                value: organization.bin,
                child: _OrganizationOption(organization: organization),
              ),
            )
            .toList(),
        selectedItemBuilder: (context) => organizations
            .map(
              (organization) =>
                  Text(organization.title, overflow: TextOverflow.ellipsis),
            )
            .toList(),
        onChanged: organizations.isEmpty ? null : onChanged,
        disabledHint: Text(
          organizations.isEmpty
              ? 'Справочник организаций пуст'
              : 'Выберите организацию',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _OrganizationOption extends StatelessWidget {
  const _OrganizationOption({required this.organization});

  final Organization organization;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          organization.title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          organization.subtitle,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({required this.photoUrl, required this.fallbackText});

  final String? photoUrl;
  final String fallbackText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = _initialsFromText(fallbackText);

    return Container(
      width: 128,
      height: 128,
      decoration: BoxDecoration(
        color: ToolsupPalette.navy,
        border: Border.all(color: ToolsupPalette.border),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl == null
          ? Center(
              child: Text(
                initials,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    Icons.person_outline,
                    color: colors.primary,
                    size: 48,
                  ),
                );
              },
            ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String _mimeTypeFromFileName(String fileName) {
  final lowerName = fileName.toLowerCase();
  if (lowerName.endsWith('.png')) {
    return 'image/png';
  }
  if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  return 'application/octet-stream';
}

String _initialsFromText(String text) {
  final words = text
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return '?';
  }
  final first = words.first.characters.first.toUpperCase();
  if (words.length == 1) {
    return first;
  }
  return '$first${words[1].characters.first.toUpperCase()}';
}

String _formatDateTime(DateTime dateTime) {
  final day = dateTime.day.toString().padLeft(2, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$day.$month.${dateTime.year} $hour:$minute';
}
