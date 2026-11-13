import archive from './trader-skills.json' with { type: 'json' };

// Only the public, bundled toolkit is uploaded. Inputs and intermediate results
// belong to the container created for the current conversation.
export async function uploadTraderToolkit(key: string, send: typeof fetch): Promise<string> {
  const form = new FormData();
  const bytes = Uint8Array.from(atob(archive.base64), c => c.charCodeAt(0));
  form.append('file', new Blob([bytes], { type: 'application/zip' }), archive.filename);
  form.append('purpose', 'user_data');
  form.append('expires_after[anchor]', 'created_at');
  form.append('expires_after[seconds]', '3600');
  const response = await send('https://api.openai.com/v1/files', {
    method: 'POST', headers: { Authorization: `Bearer ${key}` }, body: form,
    signal: AbortSignal.timeout(15000),
  });
  const file = response.ok ? await response.json() : {};
  if (typeof file.id !== 'string') throw new Error('The trader toolkit could not be loaded. Retry this request.');
  return file.id;
}

export const openTraderSkill = {
  type: 'function', name: 'open_trader_skill',
  description: 'Load the supplied Python trader skills for a trading workflow, including budgeting, screening, public disclosures and risk checks.',
  parameters: { type: 'object', properties: {}, required: [], additionalProperties: false },
  strict: true,
};
