export type GatewayMessage = { role: 'user' | 'assistant' | 'system'; content: string };

export type GatewayAttachment = {
  type: 'input_text' | 'input_image' | 'input_file';
  text?: string;
  image_url?: string;
  filename?: string;
  file_data?: string;
};

export function validAttachment(item: unknown): boolean {
  if (!item || typeof item !== 'object') return false;
  const value = item as Record<string, unknown>;
  if (value.type === 'input_text') {
    return typeof value.text === 'string' && value.text.length <= 80000;
  }
  if (value.type === 'input_image') {
    if (typeof value.image_url !== 'string') return false;
    if (/^data:image\/(png|jpeg|webp|gif);base64,[A-Za-z0-9+/=]+$/.test(value.image_url)) {
      return true;
    }
    try {
      const parsed = new URL(value.image_url);
      return parsed.protocol === 'https:' && parsed.hostname.length > 0 && value.image_url.length <= 2048;
    } catch {
      return false;
    }
  }
  return value.type === 'input_file' &&
    typeof value.filename === 'string' &&
    value.filename.toLowerCase().endsWith('.pdf') &&
    typeof value.file_data === 'string' &&
    /^data:application\/pdf;base64,[A-Za-z0-9+/=]+$/.test(value.file_data);
}

export function parseDataUrl(dataUrl: string): { mimeType: string; data: string } | null {
  const match = /^data:([^;]+);base64,([A-Za-z0-9+/=]+)$/.exec(dataUrl);
  return match ? { mimeType: match[1], data: match[2] } : null;
}

export function buildProviderMessages(
  provider: string,
  messages: GatewayMessage[],
  attachments: GatewayAttachment[],
) {
  if (attachments.length === 0) {
    if (provider === 'gemini') {
      return messages
        .filter((m) => m.role !== 'system')
        .map((m) => ({
          role: m.role === 'assistant' ? 'model' : 'user',
          parts: [{ text: m.content }],
        }));
    }
    if (provider === 'anthropic') {
      return messages.filter((m) => m.role !== 'system');
    }
    return messages;
  }

  const nonSystem = messages.filter((m) => m.role !== 'system');
  const lastIndex = nonSystem.length - 1;

  if (provider === 'gemini') {
    return nonSystem.map((m, idx) => {
      const parts: Record<string, unknown>[] = [{ text: m.content }];
      if (idx === lastIndex && m.role === 'user') {
        for (const att of attachments) {
          if (att.type === 'input_text' && att.text) {
            parts.push({ text: att.text });
          } else if (att.type === 'input_image' && att.image_url) {
            const parsed = parseDataUrl(att.image_url);
            if (parsed) parts.push({ inlineData: parsed });
            else parts.push({ text: `Image URL: ${att.image_url}` });
          } else if (att.type === 'input_file' && att.file_data) {
            const parsed = parseDataUrl(att.file_data);
            if (parsed) parts.push({ inlineData: parsed });
          }
        }
      }
      return { role: m.role === 'assistant' ? 'model' : 'user', parts };
    });
  }

  if (provider === 'anthropic') {
    return nonSystem.map((m, idx) => {
      if (idx !== lastIndex || m.role !== 'user') {
        return { role: m.role, content: m.content };
      }
      const blocks: Record<string, unknown>[] = [{ type: 'text', text: m.content }];
      for (const att of attachments) {
        if (att.type === 'input_text' && att.text) {
          blocks.push({ type: 'text', text: att.text });
        } else if (att.type === 'input_image' && att.image_url) {
          const parsed = parseDataUrl(att.image_url);
          if (parsed) {
            blocks.push({
              type: 'image',
              source: { type: 'base64', media_type: parsed.mimeType, data: parsed.data },
            });
          } else {
            blocks.push({ type: 'image', source: { type: 'url', url: att.image_url } });
          }
        } else if (att.type === 'input_file' && att.file_data) {
          const parsed = parseDataUrl(att.file_data);
          if (parsed) {
            blocks.push({
              type: 'document',
              source: { type: 'base64', media_type: 'application/pdf', data: parsed.data },
            });
          }
        }
      }
      return { role: 'user', content: blocks };
    });
  }

  return messages.map((m, idx) => {
    if (m.role !== 'user' || idx !== messages.length - 1) return m;
    const content: Record<string, unknown>[] = [{ type: 'text', text: m.content }];
    for (const att of attachments) {
      if (att.type === 'input_text' && att.text) {
        content.push({ type: 'text', text: att.text });
      } else if (att.type === 'input_image' && att.image_url) {
        content.push({ type: 'image_url', image_url: { url: att.image_url } });
      } else if (att.type === 'input_file' && att.filename) {
        content.push({ type: 'text', text: `Attached PDF document: ${att.filename}` });
      }
    }
    return { role: 'user', content };
  });
}
