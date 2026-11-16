import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tradex/core/ads/ad_scope.dart';
import 'package:tradex/core/ads/promotion_preview.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_limitations.dart';
import 'package:tradex/core/data/app_session.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/markdown_kit/markdown_kit.dart';
import 'package:tradex/core/utils/attachment_compression_service.dart';

import '../data/copilot_controller.dart';
import '../data/copilot_feature_connector.dart';
import '../models/workspace.dart';
import 'copilot_composer.dart';
import 'copilot_feature_modals.dart';
import 'review_card.dart';
import 'research_format_picker.dart';
import 'research_welcome.dart';
import 'research_freshness.dart';
import 'save_page_dialog.dart';
import 'trader_skill_picker.dart';

class CopilotChatPane extends StatefulWidget {
  const CopilotChatPane({
    super.key,
    required this.controller,
    this.initialPrompt,
    this.onPage,
    this.onVoice,
    this.onSpeakMessage,
    this.onOpenRef,
    this.voiceActive = false,
  });
  final CopilotController controller;
  final String? initialPrompt;
  final ValueChanged<WorkspacePage>? onPage;
  final VoidCallback? onVoice;
  final ValueChanged<String>? onSpeakMessage;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final bool voiceActive;
  @override
  State<CopilotChatPane> createState() => _CopilotChatPaneState();
}

class _DraftAttachment {
  const _DraftAttachment({
    required this.name,
    required this.input,
    required this.ui,
  });

  final String name;
  final Json input;
  final AppAiAttachment ui;
}

class _CopilotChatPaneState extends State<CopilotChatPane> {
  static const int _maxAttachments = 4;
  static const int _maxFileBytes = 6000000;
  static const int _maxCombinedPayloadBytes = 11000000;
  static const List<String> _imageExtensions = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'bmp',
    'heic',
    'heif',
  ];
  static const List<String> _dataExtensions = [
    'csv',
    'tsv',
    'json',
    'yaml',
    'yml',
    'xml',
    'toml',
  ];
  static const List<String> _codeExtensions = [
    'py',
    'dart',
    'js',
    'ts',
    'tsx',
    'jsx',
    'sql',
    'sh',
    'html',
    'css',
    'pine',
  ];
  static const List<String> _supportedExtensions = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'bmp',
    'heic',
    'heif',
    'pdf',
    'txt',
    'md',
    'markdown',
    'rtf',
    'log',
    'svg',
    'csv',
    'tsv',
    'json',
    'yaml',
    'yml',
    'xml',
    'toml',
    'py',
    'dart',
    'js',
    'ts',
    'tsx',
    'jsx',
    'sql',
    'sh',
    'html',
    'css',
    'pine',
  ];

  final _composer = TextEditingController();
  final List<_DraftAttachment> _attachments = [];
  bool _attaching = false;
  String? _optimisticPrompt;
  List<AppAiAttachment> _optimisticAttachments = const [];
  CopilotPromptMode _mode = CopilotPromptMode.auto;
  CopilotSearchFocus _focus = CopilotSearchFocus.all;
  CopilotController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _composer.text = widget.initialPrompt ?? '';
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  static String? _extensionOf(String filename, [String? explicitExtension]) {
    final cleaned = (explicitExtension ?? '').trim().toLowerCase();
    if (cleaned.isNotEmpty) return cleaned;
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot >= filename.length - 1) return null;
    return filename.substring(dot + 1).toLowerCase();
  }

  static AppAiAttachmentKind _kindForExtension(String? extension) {
    if (extension == null) return AppAiAttachmentKind.text;
    if (_imageExtensions.contains(extension)) return AppAiAttachmentKind.image;
    if (extension == 'pdf') return AppAiAttachmentKind.pdf;
    if (_dataExtensions.contains(extension)) return AppAiAttachmentKind.data;
    if (_codeExtensions.contains(extension)) return AppAiAttachmentKind.code;
    return AppAiAttachmentKind.text;
  }

  static Json _uiMetaJson(AppAiAttachment ui) => {
    'name': ui.name,
    'kind': ui.kind.name,
    if (ui.mimeType != null) 'mimeType': ui.mimeType,
    if (ui.previewUrl != null) 'previewUrl': ui.previewUrl,
    if (ui.subtitle != null) 'subtitle': ui.subtitle,
    if (ui.sizeBytes != null) 'sizeBytes': ui.sizeBytes,
  };

  static Json _attachUiMeta(Json input, AppAiAttachment ui) => {
    ...input,
    '_ui': _uiMetaJson(ui),
  };

  static List<AppAiAttachment> _parseUiAttachments(CopilotMessage message) {
    return message.attachments.map((raw) {
      final kindName = textOf(raw, 'kind', 'file');
      final kind = AppAiAttachmentKind.values.firstWhere(
        (k) => k.name == kindName,
        orElse: () => AppAiAttachmentKind.file,
      );
      final sizeRaw = raw['sizeBytes'];
      final sizeBytes = sizeRaw is int ? sizeRaw : int.tryParse('$sizeRaw');
      final mimeType = textOf(raw, 'mimeType');
      final previewUrl = textOf(raw, 'previewUrl');
      final subtitle = textOf(raw, 'subtitle');
      return AppAiAttachment(
        name: textOf(raw, 'name', 'Attachment'),
        kind: kind,
        mimeType: mimeType.isEmpty ? null : mimeType,
        previewUrl: previewUrl.isEmpty ? null : previewUrl,
        subtitle: subtitle.isEmpty ? null : subtitle,
        sizeBytes: sizeBytes,
      );
    }).toList();
  }

  Future<_DraftAttachment> _buildDraftFromBytes(
    Uint8List bytes,
    String filename, {
    String? extension,
  }) async {
    if (bytes.length > _maxFileBytes) {
      throw const FormatException('Each file must be under 6 MB.');
    }
    final ext = _extensionOf(filename, extension);
    if (_imageExtensions.contains(ext)) {
      String mimeType = switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/png',
      };
      Uint8List payloadBytes = bytes;
      final bool isStandardWebFormat =
          ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'webp';
      if (ext != 'gif' &&
          (!isStandardWebFormat ||
              bytes.length > AttachmentCompressionService.defaultMaxSizeBytes)) {
        try {
          final compressed =
              await AttachmentCompressionService.compressAttachment(
                bytes: bytes,
                filename: filename,
              );
          if (compressed.bytes.isNotEmpty) {
            payloadBytes = compressed.bytes;
            mimeType = compressed.mimeType;
          }
        } catch (_) {
          // Preserve raw image bytes if compression fails in test or odd encoders.
        }
      }
      final dataUrl = 'data:$mimeType;base64,${base64Encode(payloadBytes)}';
      final ui = AppAiAttachment(
        name: filename,
        kind: AppAiAttachmentKind.image,
        mimeType: mimeType,
        previewUrl: dataUrl,
        sizeBytes: payloadBytes.length,
      );
      return _DraftAttachment(
        name: filename,
        input: _attachUiMeta({
          'type': 'input_image',
          'filename': filename,
          'image_url': dataUrl,
        }, ui),
        ui: ui,
      );
    }
    if (ext == 'pdf') {
      final ui = AppAiAttachment(
        name: filename,
        kind: AppAiAttachmentKind.pdf,
        mimeType: 'application/pdf',
        subtitle: 'PDF document',
        sizeBytes: bytes.length,
      );
      return _DraftAttachment(
        name: filename,
        input: _attachUiMeta({
          'type': 'input_file',
          'filename': filename,
          'file_data': 'data:application/pdf;base64,${base64Encode(bytes)}',
        }, ui),
        ui: ui,
      );
    }
    final text = utf8.decode(bytes);
    if (text.length > 80000) {
      throw const FormatException(
        'Text attachments are limited to 80,000 characters.',
      );
    }
    final kind = _kindForExtension(ext);
    final label = ext != null ? ext.toUpperCase() : 'TEXT';
    final ui = AppAiAttachment(
      name: filename,
      kind: kind,
      subtitle: label,
      sizeBytes: bytes.length,
    );
    return _DraftAttachment(
      name: filename,
      input: _attachUiMeta({
        'type': 'input_text',
        'filename': filename,
        'text': 'Attachment $filename:\n$text',
      }, ui),
      ui: ui,
    );
  }

  void _commitAdditions(List<_DraftAttachment> additions) {
    if (additions.isEmpty) return;
    if (_attachments.length + additions.length > _maxAttachments) {
      throw const FormatException(
        'Attach up to four files, each under 6 MB.',
      );
    }
    final totalBytes = utf8
        .encode(
          jsonEncode([
            ..._attachments.map((a) => a.input),
            ...additions.map((a) => a.input),
          ]),
        )
        .length;
    if (totalBytes > _maxCombinedPayloadBytes) {
      throw const FormatException(
        'These files exceed the combined upload limit. Attach fewer or smaller files.',
      );
    }
    setState(() => _attachments.addAll(additions));
  }

  Future<void> _attach() async {
    if (_attaching || controller.generating) return;
    setState(() => _attaching = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _supportedExtensions,
      );
      if (!mounted || picked == null) return;
      final additions = <_DraftAttachment>[];
      for (final file in picked.files) {
        if (_attachments.length + additions.length >= _maxAttachments ||
            file.size > _maxFileBytes) {
          throw const FormatException(
            'Attach up to four files, each under 6 MB.',
          );
        }
        final bytes = file.bytes ?? await file.xFile.readAsBytes();
        if (!mounted) return;
        additions.add(
          await _buildDraftFromBytes(
            bytes,
            file.name,
            extension: file.extension,
          ),
        );
        if (!mounted) return;
      }
      _commitAdditions(additions);
    } catch (error) {
      if (mounted) {
        UiToast.error(
          context,
          title: 'Could not attach file',
          message: '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _attachImage() async {
    if (_attaching || controller.generating) return;
    setState(() => _attaching = true);
    try {
      List<XFile> images = const [];
      try {
        images = await ImagePicker().pickMultiImage(
          limit: _maxAttachments - _attachments.length,
        );
      } catch (_) {
        // Fallback cleanly to image file picker on desktop/unsupported targets.
      }
      if (!mounted) return;
      if (images.isEmpty) {
        final picked = await FilePicker.platform.pickFiles(
          withData: true,
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: _imageExtensions,
        );
        if (!mounted || picked == null) return;
        final additions = <_DraftAttachment>[];
        for (final file in picked.files) {
          if (_attachments.length + additions.length >= _maxAttachments ||
              file.size > _maxFileBytes) {
            throw const FormatException(
              'Attach up to four files, each under 6 MB.',
            );
          }
          final bytes = file.bytes ?? await file.xFile.readAsBytes();
          if (!mounted) return;
          additions.add(
            await _buildDraftFromBytes(
              bytes,
              file.name,
              extension: file.extension,
            ),
          );
          if (!mounted) return;
        }
        _commitAdditions(additions);
        return;
      }
      final additions = <_DraftAttachment>[];
      for (final image in images) {
        if (_attachments.length + additions.length >= _maxAttachments) {
          throw const FormatException(
            'Attach up to four files, each under 6 MB.',
          );
        }
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        final name = image.name.isNotEmpty ? image.name : 'chart_image.png';
        additions.add(await _buildDraftFromBytes(bytes, name));
        if (!mounted) return;
      }
      _commitAdditions(additions);
    } catch (error) {
      if (mounted) {
        UiToast.error(
          context,
          title: 'Could not attach image',
          message: '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _takePhoto() async {
    if (_attaching || controller.generating) return;
    setState(() => _attaching = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
      );
      if (!mounted || photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      final name = photo.name.isNotEmpty ? photo.name : 'camera_capture.jpg';
      final draft = await _buildDraftFromBytes(bytes, name);
      if (!mounted) return;
      _commitAdditions([draft]);
    } catch (error) {
      if (mounted) {
        UiToast.error(
          context,
          title: kIsWeb ? 'Camera unavailable' : 'Could not capture photo',
          message: '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _attachUrlDialog() async {
    if (controller.generating) return;
    final urlController = TextEditingController();
    final labelController = TextEditingController();
    bool asImage = false;
    String? errorText;
    try {
      await UiDialog.present<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setModalState) {
            final raw = urlController.text.trim();
            final uri = Uri.tryParse(raw);
            final validHttps =
                uri != null &&
                (uri.scheme == 'https' || uri.scheme == 'http') &&
                uri.host.isNotEmpty;
            final lowerPath = uri?.path.toLowerCase() ?? '';
            final looksLikeImage =
                lowerPath.endsWith('.png') ||
                lowerPath.endsWith('.jpg') ||
                lowerPath.endsWith('.jpeg') ||
                lowerPath.endsWith('.webp') ||
                lowerPath.endsWith('.gif');
            final effectiveAsImage = asImage || looksLikeImage;
            return UiDialog(
              title: 'Attach web link or image URL',
              description:
                  'Analyze any webpage, earnings release, or hosted chart screenshot directly in Copilot.',
              icon: Icons.add_link_rounded,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UiToggleGroup<bool>(
                    value: effectiveAsImage,
                    onChanged: (value) => setModalState(() => asImage = value),
                    options: const [
                      UiToggleOption(
                        value: false,
                        label: 'Web link',
                        icon: Icons.public_rounded,
                      ),
                      UiToggleOption(
                        value: true,
                        label: 'Image URL',
                        icon: Icons.image_outlined,
                      ),
                    ],
                  ),
                  UiGap.v(context.ui.spacing.sm),
                  UiInput(
                    controller: urlController,
                    label: 'URL',
                    hintText: effectiveAsImage
                        ? 'https://example.com/chart.png'
                        : 'https://investor.nvidia.com/...',
                    errorText: errorText,
                    leading: validHttps
                        ? AppSiteLogo(url: raw, size: context.sz(20))
                        : Icon(
                            Icons.link_rounded,
                            size: context.sz(18),
                            color: context.ui.colors.foregroundMuted,
                          ),
                    onChanged: (_) => setModalState(() => errorText = null),
                  ),
                  UiGap.v(context.ui.spacing.sm),
                  UiInput(
                    controller: labelController,
                    label: 'Label (optional)',
                    hintText: 'Q4 Earnings release / NVDA daily chart',
                  ),
                  if (effectiveAsImage && validHttps) ...[
                    UiGap.v(context.ui.spacing.sm),
                    ClipRRect(
                      borderRadius: context.radius(context.ui.radii.md),
                      child: UiRemoteImage(
                        url: raw,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                UiButton(
                  label: 'Cancel',
                  variant: UiVariant.ghost,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                UiButton(
                  label: 'Attach',
                  icon: Icons.attach_file_rounded,
                  onPressed: () {
                    final url = urlController.text.trim();
                    final parsed = Uri.tryParse(url);
                    if (parsed == null ||
                        (parsed.scheme != 'https' && parsed.scheme != 'http') ||
                        parsed.host.isEmpty) {
                      setModalState(
                        () => errorText = 'Enter a valid http(s):// URL.',
                      );
                      return;
                    }
                    if (_attachments.length >= _maxAttachments) {
                      setModalState(
                        () => errorText = 'Maximum 4 attachments per prompt.',
                      );
                      return;
                    }
                    final host = SiteLogoResolver.extractDomain(url) ?? parsed.host;
                    final customLabel = labelController.text.trim();
                    final displayName = customLabel.isNotEmpty
                        ? customLabel
                        : (effectiveAsImage ? 'Image ($host)' : host);
                    final ui = effectiveAsImage
                        ? AppAiAttachment(
                            name: displayName,
                            kind: AppAiAttachmentKind.image,
                            previewUrl: url,
                            subtitle: host,
                          )
                        : AppAiAttachment(
                            name: displayName,
                            kind: AppAiAttachmentKind.link,
                            previewUrl: url,
                            subtitle: host,
                          );
                    final input = effectiveAsImage
                        ? _attachUiMeta({
                            'type': 'input_image',
                            'filename': displayName,
                            'image_url': url,
                          }, ui)
                        : _attachUiMeta({
                            'type': 'input_text',
                            'filename': displayName,
                            'text': 'Referenced URL ($displayName): $url',
                          }, ui);
                    _commitAdditions([
                      _DraftAttachment(name: displayName, input: input, ui: ui),
                    ]);
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        ),
      );
    } finally {
      urlController.dispose();
      labelController.dispose();
    }
  }

  Future<void> _showDropzoneDialog() async {
    if (controller.generating) return;
    await UiDialog.present<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final previews = _attachments
              .map((a) => a.ui.previewUrl)
              .whereType<String>()
              .where((u) => u.isNotEmpty)
              .toList();
          return UiDialog(
            title: 'Attach images, charts & research files',
            description:
                'Drop chart screenshots, PDFs, CSV datasets, or code files for instant multimodal analysis.',
            icon: Icons.upload_file_rounded,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiDropzone(
                  title: 'Drop or choose files & screenshots',
                  message:
                      'PNG, JPG, WebP, GIF, PDF, CSV, JSON, Markdown, Python, Pine',
                  uploading: _attaching,
                  previewUrls: previews,
                  onPick: () async {
                    await _attach();
                    if (context.mounted) setModalState(() {});
                  },
                  onFilesDropped: (items) {
                    for (final item in items) {
                      final trimmed = item.trim();
                      if (_attachments.length >= _maxAttachments) break;
                      if (trimmed.startsWith('http://') ||
                          trimmed.startsWith('https://') ||
                          trimmed.startsWith('data:image/')) {
                        final ui = AppAiAttachment(
                          name: trimmed.startsWith('data:image/')
                              ? 'Dropped image'
                              : (SiteLogoResolver.extractDomain(trimmed) ?? 'Link'),
                          kind: AppAiAttachmentKind.image,
                          previewUrl: trimmed,
                        );
                        _commitAdditions([
                          _DraftAttachment(
                            name: ui.name,
                            input: _attachUiMeta({
                              'type': 'input_image',
                              'filename': ui.name,
                              'image_url': trimmed,
                            }, ui),
                            ui: ui,
                          ),
                        ]);
                      }
                    }
                    if (context.mounted) setModalState(() {});
                  },
                  onRemove: (url) {
                    setState(() {
                      _attachments.removeWhere((a) => a.ui.previewUrl == url);
                    });
                    setModalState(() {});
                  },
                ),
                UiGap.v(context.ui.spacing.sm),
                Wrap(
                  spacing: context.sp(context.ui.spacing.xs),
                  runSpacing: context.sp(context.ui.spacing.xs),
                  children: [
                    UiButton(
                      label: 'Photos',
                      size: UiSize.sm,
                      variant: UiVariant.soft,
                      icon: Icons.photo_library_outlined,
                      onPressed: () async {
                        await _attachImage();
                        if (context.mounted) setModalState(() {});
                      },
                    ),
                    UiButton(
                      label: 'Files / PDF',
                      size: UiSize.sm,
                      variant: UiVariant.soft,
                      icon: Icons.description_outlined,
                      onPressed: () async {
                        await _attach();
                        if (context.mounted) setModalState(() {});
                      },
                    ),
                    UiButton(
                      label: 'Link / Image URL',
                      size: UiSize.sm,
                      variant: UiVariant.outline,
                      icon: Icons.add_link_rounded,
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        await _attachUrlDialog();
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              UiButton(
                label: 'Done',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _send(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;
    if (controller.isAiQuotaBlocked) {
      await CustomerLimitations.showPlanUpgradeDialog(
        context,
        featureTitle:
            'AI Copilot Quota Reached (${controller.effectiveAiQueriesUsed}/${controller.effectiveAiQueriesLimit})',
        reason:
            'Your ${CustomerLimitations.currentQuota.planName} plan includes ${controller.effectiveAiQueriesLimit} monthly AI prompts. Upgrade your plan or wait for the monthly cycle reset.',
      );
      return;
    }
    final previousDraft = _composer.text;
    final savedAttachments = List<_DraftAttachment>.from(_attachments);
    final attachments = savedAttachments.map((a) => a.input).toList();

    // Clear composer and attachments immediately on Enter/Send for snappy UX.
    _composer.clear();
    setState(() {
      _attachments.clear();
      _optimisticPrompt = trimmed;
      _optimisticAttachments = savedAttachments.map((a) => a.ui).toList();
    });

    final accepted = await controller.sendPrompt(
      trimmed,
      attachments: attachments,
      mode:
          controller.specialist?.research == true &&
              controller.workspace.settings['research'] == true
          ? _mode.name
          : 'auto',
      focus: _focus.name,
    );
    if (!mounted) return;
    if (accepted) {
      setState(() {
        _optimisticPrompt = null;
        _optimisticAttachments = const [];
      });
      if (controller.voiceAutoSpeak &&
          !widget.voiceActive &&
          widget.onSpeakMessage != null) {
        final reply = controller.activeThread?.messages
            .where((m) => !m.isUser && m.body.trim().isNotEmpty)
            .lastOrNull
            ?.body;
        if (reply != null && reply.trim().isNotEmpty) {
          widget.onSpeakMessage!(reply);
        }
      }
    } else {
      final restoredText = previousDraft.isNotEmpty ? previousDraft : prompt;
      _composer.value = TextEditingValue(
        text: restoredText,
        selection: TextSelection.collapsed(offset: restoredText.length),
      );
      setState(() {
        _optimisticPrompt = null;
        _optimisticAttachments = const [];
        if (_attachments.isEmpty && savedAttachments.isNotEmpty) {
          _attachments.addAll(savedAttachments);
        }
      });
    }
  }

  Future<void> _browseSkills() async {
    final skill = await pickTraderSkill(context);
    if (!mounted || skill == null) return;
    final draft = traderSkillDraft(skill, _composer.text);
    _composer.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  Future<void> _browseFormats({String? subject}) async {
    final prompt = await pickResearchFormat(
      context,
      subject: subject ?? _composer.text,
    );
    if (!mounted || prompt == null) return;
    _composer.value = TextEditingValue(
      text: prompt,
      selection: TextSelection.collapsed(offset: prompt.length),
    );
  }

  Future<void> _download(Json artifact) async {
    try {
      final bytes = await controller.api.artifact(
        controller.activeThreadId!,
        artifact,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              name: textOf(artifact, 'filename', 'result.txt'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        UiToast.error(context, title: 'File unavailable', message: '$error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = controller.activeThread;
    final messages = thread?.messages ?? <CopilotMessage>[];
    final approvals =
        thread?.approvals.where((a) => a['status'] == 'pending').toList() ?? [];
    final displayed = messages
        .map(
          (message) => AppAiMessage(
            id: message.id,
            sentAt: DateTime.tryParse(textOf(message.json, 'createdAt')),
            role: message.isUser ? AppAiRole.user : AppAiRole.assistant,
            body: message.id == controller.streamingMessageId
                ? (controller.streamingText.isNotEmpty
                      ? controller.streamingText
                      : message.body)
                : message.body,
            pending:
                (message.status == 'streaming' ||
                    message.id == controller.streamingMessageId) &&
                controller.generating,
            sources: message.sources.map((s) => textOf(s, 'url')).toList(),
            structuredSources: message.sources
                .where((s) => textOf(s, 'url').isNotEmpty)
                .map(
                  (s) => AppAiSource(
                    url: textOf(s, 'url'),
                    title: textOf(s, 'title'),
                    domain: textOf(s, 'domain'),
                    snippet: textOf(s, 'snippet'),
                  ),
                )
                .toList(),
            mode: textOf(message.json, 'mode').isEmpty
                ? null
                : textOf(message.json, 'mode'),
            steps:
                (message.json['steps'] as List?)
                    ?.map((e) => '$e'.trim())
                    .where((e) => e.isNotEmpty)
                    .toList() ??
                const <String>[],
            attachmentItems: _parseUiAttachments(message),
            focus: textOf(message.json, 'focus').isEmpty
                ? null
                : textOf(message.json, 'focus'),
          ),
        )
        .toList();
    final bool hasStreamingAssistant = displayed.any(
      (m) => m.role == AppAiRole.assistant && m.pending,
    );
    if (_optimisticPrompt != null &&
        controller.generating &&
        !hasStreamingAssistant) {
      final bool userAlreadyListed =
          displayed.isNotEmpty &&
          displayed.last.role == AppAiRole.user &&
          displayed.last.body.trim() == _optimisticPrompt;
      if (!userAlreadyListed) {
        displayed.add(
          AppAiMessage(
            id: '__optimistic_user__',
            role: AppAiRole.user,
            body: _optimisticPrompt!,
            attachmentItems: _optimisticAttachments,
          ),
        );
      }
      displayed.add(
        const AppAiMessage(
          id: '__optimistic_assistant__',
          role: AppAiRole.assistant,
          body: '',
          pending: true,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final showQuotaBanner =
            constraints.maxHeight >= 420 && !controller.isAiQuotaBlocked;
        final showPromoPreview =
            !kReleaseMode &&
            AdSenseScope.maybeOf(context)?.config.preview == true;
        final hasTopNotices =
            showPromoPreview ||
            showQuotaBanner ||
            controller.pageContextId != null ||
            controller.isAiQuotaBlocked ||
            controller.error != null;
        final Widget? topNotice = !hasTopNotices
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showPromoPreview)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: context.sp(context.ui.spacing.sm),
                      ),
                      child: const PromotionPreview(surface: 'AI Assistant'),
                    ),
                  if (showQuotaBanner) _AiQuotaBanner(controller: controller),
                  if (controller.pageContextId != null)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: context.sp(context.ui.spacing.sm),
                      ),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: context.sp(context.ui.spacing.xs),
                        children: [
                          UiBadge(
                            label:
                                'Discussing: ${controller.workspace.pages.where((p) => p.id == controller.pageContextId).firstOrNull?.title ?? 'Page'}',
                            icon: Icons.article_outlined,
                            intent: UiIntent.neutral,
                          ),
                          UiIconButton(
                            icon: Icons.close_rounded,
                            tooltip: 'Detach page context',
                            size: UiSize.xs,
                            variant: UiVariant.ghost,
                            onPressed: controller.clearPageContext,
                          ),
                        ],
                      ),
                    ),
                  if (controller.isAiQuotaBlocked)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: context.sp(context.ui.spacing.sm),
                      ),
                      child: UiCallout(
                        title:
                            'Monthly AI quota reached (${controller.effectiveAiQueriesUsed}/${controller.effectiveAiQueriesLimit})',
                        message:
                            'Your ${CustomerLimitations.currentQuota.planName} plan allows ${controller.effectiveAiQueriesLimit} AI prompts per month. Upgrade your plan to unlock additional capacity.',
                        intent: UiIntent.warning,
                        action: UiButton(
                          label: 'Upgrade Plan',
                          size: UiSize.xs,
                          variant: UiVariant.solid,
                          intent: UiIntent.primary,
                          onPressed: () => CustomerLimitations.showPlanUpgradeDialog(
                            context,
                            featureTitle:
                                'AI Copilot Quota Reached (${controller.effectiveAiQueriesUsed}/${controller.effectiveAiQueriesLimit})',
                            reason:
                                'Your ${CustomerLimitations.currentQuota.planName} plan includes ${controller.effectiveAiQueriesLimit} AI queries per month.',
                          ),
                        ),
                      ),
                    )
                  else if (controller.error != null)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: context.sp(context.ui.spacing.sm),
                      ),
                      child: UiCallout(
                        title: 'Could not finish',
                        message: controller.error!,
                        intent: UiIntent.warning,
                        onClose: () => setState(() => controller.error = null),
                        action: UiButton(
                          label: 'Reconnect',
                          size: UiSize.xs,
                          variant: UiVariant.outline,
                          onPressed: () => controller.reload(),
                        ),
                      ),
                    ),
                ],
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AppAiChatBlock(
                key: ValueKey(
                  controller.activeThreadId ??
                      'new-${controller.specialist?.id}',
                ),
                header: topNotice,
                messages: displayed,
                onSend: _send,
                onAttach:
                    controller.isAiQuotaBlocked ||
                        controller.workspace.setup['attachments'] == false
                    ? null
                    : _attach,
                generating:
                    controller.generating || thread?.status == 'running',
                onStop: controller.stop,
                canSend:
                    !controller.isAiQuotaBlocked &&
                    controller.connected &&
                    !controller.hasPendingReview &&
                    controller.workspace.settings['paused'] != true,
                composer: CopilotComposer(
                  onResearchFormats: _browseFormats,
                  controller: _composer,
                  compactHeight:
                      constraints.maxHeight < 520 || widget.voiceActive,
                  enabled:
                      !controller.isAiQuotaBlocked &&
                      controller.connected &&
                      (!controller.voiceBusy || widget.voiceActive) &&
                      !controller.hasPendingReview &&
                      controller.workspace.settings['paused'] != true,
                  busy: controller.generating || thread?.status == 'running',
                  attaching: _attaching,
                  attachments: _attachments.map((a) => a.name).toList(),
                  attachmentItems: _attachments.map((a) => a.ui).toList(),
                  profiles: controller.workspace.specialists,
                  profileId: controller.specialist?.id,
                  mode: _mode,
                  focus: _focus,
                  canResearch:
                      controller.workspace.setup['research'] != false &&
                      controller.workspace.settings['research'] == true &&
                      controller.specialist?.research == true,
                  onModeChanged: (mode) => setState(() => _mode = mode),
                  onFocusChanged: (focus) => setState(() => _focus = focus),
                  onSelectProfile: (id) {
                    controller.newConversation(specialist: id);
                    setState(() {
                      _mode = CopilotPromptMode.auto;
                      _focus = CopilotSearchFocus.all;
                    });
                  },
                  onNewConversation: () => controller.newConversation(),
                  onSend: () => _send(
                    _composer.text.trim().isEmpty
                        ? 'Please review the attached files.'
                        : _composer.text.trim(),
                  ),
                  onAttach:
                      controller.isAiQuotaBlocked ||
                          controller.workspace.setup['attachments'] == false
                      ? null
                      : _attach,
                  onAttachImage:
                      controller.isAiQuotaBlocked ||
                          controller.workspace.setup['attachments'] == false
                      ? null
                      : _attachImage,
                  onTakePhoto:
                      controller.isAiQuotaBlocked ||
                          controller.workspace.setup['attachments'] == false
                      ? null
                      : _takePhoto,
                  onAttachDropzone:
                      controller.isAiQuotaBlocked ||
                          controller.workspace.setup['attachments'] == false
                      ? null
                      : _showDropzoneDialog,
                  onAttachUrl:
                      controller.isAiQuotaBlocked ||
                          controller.workspace.setup['attachments'] == false
                      ? null
                      : _attachUrlDialog,
                  onRemoveAttachment: (i) =>
                      setState(() => _attachments.removeAt(i)),
                  onStop: controller.stop,
                  onVoice: controller.isAiQuotaBlocked ? null : widget.onVoice,
                  onConnectWorkspace: () => showCopilotConnectDialog(
                    context,
                    onAttach: (CopilotConnectedItem item) {
                      if (!mounted) return;
                      final displayName = '${item.category.label}: ${item.title}';
                      final ui = AppAiAttachment(
                        name: displayName,
                        kind: AppAiAttachmentKind.workspace,
                        subtitle: item.category.label,
                      );
                      setState(() {
                        if (_attachments.length >= _maxAttachments) {
                          _attachments.removeAt(0);
                        }
                        _attachments.add(
                          _DraftAttachment(
                            name: displayName,
                            input: _attachUiMeta(item.toAttachmentJson(), ui),
                            ui: ui,
                          ),
                        );
                      });
                    },
                  ),
                  voiceActive: widget.voiceActive,
                ),
                composerController: _composer,
                composerHint: controller.isAiQuotaBlocked
                    ? 'Monthly AI quota exhausted — upgrade plan to continue'
                    : 'Ask ${controller.specialist?.name ?? 'your copilot'} anything…',
                emptyState: ResearchWelcome(
                  onFormats: _browseFormats,
                  onSkills: _browseSkills,
                  onPrompt: (prompt) {
                    if (controller.isAiQuotaBlocked) {
                      unawaited(
                        CustomerLimitations.showPlanUpgradeDialog(
                          context,
                          featureTitle:
                              'AI Copilot Quota Reached (${controller.effectiveAiQueriesUsed}/${controller.effectiveAiQueriesLimit})',
                          reason:
                              'Your ${CustomerLimitations.currentQuota.planName} plan includes ${controller.effectiveAiQueriesLimit} monthly AI prompts.',
                        ),
                      );
                      return;
                    }
                    _composer.text = prompt;
                    _composer.selection = TextSelection.collapsed(
                      offset: prompt.length,
                    );
                  },
                ),
                messageBuilder: (context, message) {
                  final model = messages
                      .where((m) => m.id == message.id)
                      .firstOrNull;
                  final bool isLastAssistant =
                      model != null &&
                      !model.isUser &&
                      model.id == messages.lastOrNull?.id;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (model != null &&
                          !model.isUser &&
                          !message.pending &&
                          model.json['research'] is Map)
                        ResearchFreshness(
                          metadata: Map<String, dynamic>.from(
                            model.json['research'] as Map,
                          ),
                        ),
                      AppAiMessageBubble(
                        message: message,
                        minimal: true,
                        onOpenRef: widget.onOpenRef,
                        onFollowUpTap: controller.generating
                            ? null
                            : (prompt) => _send(prompt),
                        onCopy: message.body.isEmpty
                            ? null
                            : () => Clipboard.setData(
                                ClipboardData(text: message.body),
                              ),
                        onRetry: isLastAssistant && !controller.generating
                            ? () => _send(
                                'Please regenerate and refine your previous response.',
                              )
                            : null,
                        onSourceTap: (url) {
                          final uri = Uri.tryParse(url);
                          if (uri != null &&
                              ['http', 'https'].contains(uri.scheme)) {
                            launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        actionsBuilder: (_) => (model == null || model.isUser)
                            ? []
                            : [
                                UiButton(
                                  label: 'Research format',
                                  icon: Icons.auto_awesome_outlined,
                                  size: UiSize.xs,
                                  variant: UiVariant.ghost,
                                  onPressed: controller.generating
                                      ? null
                                      : () => _browseFormats(
                                          subject:
                                              'this answer: ${message.body.substring(0, message.body.length.clamp(0, 12000))}',
                                        ),
                                ),
                                UiButton(
                                  label: 'Save page',
                                  icon: Icons.add_to_drive_outlined,
                                  size: UiSize.xs,
                                  variant: UiVariant.ghost,
                                  onPressed: message.body.isEmpty
                                      ? null
                                      : () => showSavePageDialog(
                                          context,
                                          controller,
                                          message.body,
                                        ),
                                ),
                                UiButton(
                                  label: 'Save note',
                                  icon: Icons.note_add_outlined,
                                  size: UiSize.xs,
                                  variant: UiVariant.ghost,
                                  onPressed: message.body.isEmpty
                                      ? null
                                      : () => showSaveToFeatureDialog(
                                          context,
                                          initialTarget:
                                              CopilotFeatureTarget.note,
                                          markdownBody: message.body,
                                          onOpenRef: widget.onOpenRef,
                                        ),
                                ),
                                UiButton(
                                  label: 'Log trade',
                                  icon: Icons.candlestick_chart_outlined,
                                  size: UiSize.xs,
                                  variant: UiVariant.ghost,
                                  onPressed: message.body.isEmpty
                                      ? null
                                      : () => showSaveToFeatureDialog(
                                          context,
                                          initialTarget:
                                              CopilotFeatureTarget.journal,
                                          markdownBody: message.body,
                                          onOpenRef: widget.onOpenRef,
                                        ),
                                ),
                                UiButton(
                                  label: 'Strategy',
                                  icon: Icons.psychology_outlined,
                                  size: UiSize.xs,
                                  variant: UiVariant.ghost,
                                  onPressed: message.body.isEmpty
                                      ? null
                                      : () => showSaveToFeatureDialog(
                                          context,
                                          initialTarget:
                                              CopilotFeatureTarget.strategy,
                                          markdownBody: message.body,
                                          onOpenRef: widget.onOpenRef,
                                        ),
                                ),
                                UiButton(
                                  label: 'Share post',
                                  icon: Icons.forum_outlined,
                                  size: UiSize.xs,
                                  variant: UiVariant.ghost,
                                  onPressed: message.body.isEmpty
                                      ? null
                                      : () => showSaveToFeatureDialog(
                                          context,
                                          initialTarget:
                                              CopilotFeatureTarget.community,
                                          markdownBody: message.body,
                                          onOpenRef: widget.onOpenRef,
                                        ),
                                ),
                                if (widget.onSpeakMessage != null)
                                  UiButton(
                                    label: 'Listen',
                                    icon: Icons.volume_up_outlined,
                                    size: UiSize.xs,
                                    variant: UiVariant.ghost,
                                    onPressed: message.body.isEmpty
                                        ? null
                                        : () => widget.onSpeakMessage!(
                                            message.body,
                                          ),
                                  ),
                                if (model.status == 'failed' ||
                                    model.status == 'interrupted')
                                  UiButton(
                                    label: 'Continue',
                                    size: UiSize.xs,
                                    variant: UiVariant.ghost,
                                    onPressed: controller.generating
                                        ? null
                                        : () => _send(
                                            'Continue the previous answer from where it stopped.',
                                          ),
                                  ),
                              ],
                      ),
                      if (model != null && model.artifacts.isNotEmpty) ...[
                        Wrap(
                          spacing: context.sp(context.ui.spacing.xs),
                          runSpacing: context.sp(context.ui.spacing.xs),
                          children: [
                            for (final file in model.artifacts)
                              UiButton(
                                label: textOf(
                                  file,
                                  'filename',
                                  'Download result',
                                ),
                                icon: Icons.download_outlined,
                                variant: UiVariant.outline,
                                size: UiSize.sm,
                                onPressed: () => _download(file),
                              ),
                          ],
                        ),
                        UiGap.v(context.ui.spacing.sm),
                      ],
                      if (model != null)
                        for (final receipt in thread?.approvals ?? <Json>[])
                          if (receipt['kind'] == 'propose_page' &&
                              receipt['status'] == 'approved' &&
                              receipt['messageId'] == model.id &&
                              receipt['result']?['id'] != null)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: context.sp(context.ui.spacing.sm),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: UiButton(
                                  label: 'Open saved page',
                                  icon: Icons.description_outlined,
                                  variant: UiVariant.soft,
                                  size: UiSize.sm,
                                  onPressed: () {
                                    final page = controller.workspace.pages
                                        .where(
                                          (p) =>
                                              p.id == receipt['result']['id'],
                                        )
                                        .firstOrNull;
                                    if (page != null) widget.onPage?.call(page);
                                  },
                                ),
                              ),
                            ),
                      if (model != null && model.activity.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: context.sp(context.ui.spacing.sm),
                          ),
                          child: UiAccordion(
                            sections: [
                              UiAccordionSection(
                                title:
                                    'Work log · ${model.activity.length} steps',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final item in model.activity)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          bottom: context.sp(
                                            context.ui.spacing.xxs,
                                          ),
                                        ),
                                        child: Text(
                                          textOf(
                                            item,
                                            'name',
                                          ).replaceAll('_', ' '),
                                          style: context.uiText.caption,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (model != null && model.id == messages.lastOrNull?.id)
                        for (final approval in approvals)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: context.sp(context.ui.spacing.sm),
                            ),
                            child: CopilotReviewCard(
                              controller: controller,
                              approval: approval,
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
            if (controller.generating && controller.activity.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  top: context.sp(context.ui.spacing.xs),
                ),
                child: Text(
                  textOf(controller.activity.last, 'name').replaceAll('_', ' '),
                  textAlign: TextAlign.center,
                  style: context.uiText.caption.copyWith(
                    color: context.ui.colors.foregroundSubtle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AiQuotaBanner extends StatelessWidget {
  const _AiQuotaBanner({required this.controller});
  final CopilotController controller;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return ValueListenableBuilder<int>(
      valueListenable: AppSession.instance.aiQueriesUsed,
      builder: (context, sessionUsed, _) {
        final limit = controller.effectiveAiQueriesLimit;
        final used = controller.quotaUsed ?? sessionUsed;
        final remaining = limit > 0 ? (limit - used).clamp(0, limit) : 0;
        final isBlocked = controller.isAiQuotaBlocked;
        final progress = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 1.0;
        final intent = isBlocked
            ? UiIntent.danger
            : (remaining <= 2 ? UiIntent.warning : UiIntent.primary);
        final quota = CustomerLimitations.currentQuota;
        return Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
          child: UiCard(
            variant: UiCardVariant.surface,
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.sm),
              vertical: context.sp(theme.spacing.xs),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: context.sp(theme.spacing.xs),
                  runSpacing: context.sp(theme.spacing.xs),
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: context.sp(theme.spacing.xs),
                      runSpacing: context.sp(theme.spacing.xs),
                      children: [
                        UiBadge(
                          label: quota.planName,
                          intent: isBlocked
                              ? UiIntent.warning
                              : UiIntent.neutral,
                          variant: UiBadgeVariant.soft,
                          size: UiSize.xs,
                        ),
                        Text(
                          isBlocked
                              ? 'AI Credits Exhausted ($used / $limit)'
                              : '$remaining of $limit AI credits remaining',
                          style: context.uiText.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isBlocked
                                ? theme.colors.danger
                                : theme.colors.foreground,
                          ),
                        ),
                      ],
                    ),
                    UiButton(
                      label: isBlocked ? 'Upgrade Plan' : 'View Quotas',
                      size: UiSize.xs,
                      variant: isBlocked ? UiVariant.solid : UiVariant.ghost,
                      intent: isBlocked ? UiIntent.primary : UiIntent.neutral,
                      onPressed: () => CustomerLimitations.showPlanUpgradeDialog(
                        context,
                        featureTitle: 'AI Copilot Quota ($used/$limit)',
                        reason:
                            'Your ${quota.planName} plan includes $limit AI queries per month.',
                      ),
                    ),
                  ],
                ),
                UiGap.v(theme.spacing.xs),
                UiProgressBar(
                  value: progress,
                  showValue: false,
                  intent: intent,
                  thickness: context.sz(4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
