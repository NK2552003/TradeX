import 'dart:convert';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/models/messages_models.dart';

String encodePrivateChat(ChatMessage message) => jsonEncode({
  'body': message.body,
  if (message.attachment case final a?)
    'attachment': {
      'id': a.id, 'kind': a.kind.name, 'title': a.title, 'subtitle': a.subtitle,
      'storagePath': a.storagePath,
      // Only inline data or externally shared URLs; signed URLs are never persisted.
      if (a.storagePath == null) 'url': a.url,
      'sizeLabel': a.sizeLabel, 'direction': a.direction, 'entry': a.entry,
      'stop': a.stop, 'target': a.target, 'chartType': a.chartType,
      'timeframe': a.timeframe, 'note': a.note,
      'candles': a.candles
          .map(
            (c) => {
              'time': c.time.toIso8601String(),
              'open': c.open,
              'high': c.high,
              'low': c.low,
              'close': c.close,
              'volume': c.volume,
            },
          )
          .toList(),
    },
  if (message.sharedRef case final r?)
    'ref': {
      'id': r.id,
      'kind': r.kind.name,
      'title': r.title,
      'subtitle': r.subtitle,
      'meta': r.meta,
    },
});

({String body, MessageAttachment? attachment, AppLinkRef? ref})
decodePrivateChat(String text) {
  final data = jsonDecode(text) as Map<String, dynamic>;
  final a = data['attachment'] as Map<String, dynamic>?;
  final r = data['ref'] as Map<String, dynamic>?;
  return (
    body: data['body'] as String,
    attachment: a == null
        ? null
        : MessageAttachment(
            id: a['id'] as String,
            kind: MessageAttachmentKind.values.byName(a['kind'] as String),
            title: a['title'] as String,
            subtitle: a['subtitle'] as String?,
            storagePath: a['storagePath'] as String?,
            url: a['url'] as String?,
            thumbnailUrl: a['url'] as String?,
            sizeLabel: a['sizeLabel'] as String?,
            direction: a['direction'] as String?,
            entry: (a['entry'] as num?)?.toDouble(),
            stop: (a['stop'] as num?)?.toDouble(),
            target: (a['target'] as num?)?.toDouble(),
            chartType: a['chartType'] as String?,
            timeframe: a['timeframe'] as String?,
            note: a['note'] as String?,
            candles: (a['candles'] as List? ?? [])
                .map(
                  (c) => UiCandle(
                    time: DateTime.parse(c['time'] as String),
                    open: (c['open'] as num).toDouble(),
                    high: (c['high'] as num).toDouble(),
                    low: (c['low'] as num).toDouble(),
                    close: (c['close'] as num).toDouble(),
                    volume: (c['volume'] as num).toDouble(),
                  ),
                )
                .toList(),
          ),
    ref: r == null
        ? null
        : AppLinkRef(
            id: r['id'] as String,
            kind: AppLinkKind.values.byName(r['kind'] as String),
            title: r['title'] as String,
            subtitle: r['subtitle'] as String?,
            meta: r['meta'] as String?,
          ),
  );
}
