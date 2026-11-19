# AlphaJournal Copilot Server — Encryption at Rest & Operations Guide

## 1. Encryption at Rest (`AES-256-GCM`)

Workspace files in `COPILOT_DATA_DIR` (including saved MCP connector bearer tokens, conversation history, and approval receipts) are encrypted at rest using authenticated encryption (`AES-256-GCM`) before being written to disk.

### Envelope Format
Each `<owner_key>.json` file on disk stores a versioned JSON envelope:
```json
{
  "v": 1,
  "alg": "AES-256-GCM",
  "nonce": "<base64-encoded 96-bit random nonce>",
  "ciphertext": "<base64-encoded ciphertext>",
  "tag": "<base64-encoded 128-bit authentication tag>"
}
```
- **Nonce:** A fresh 96-bit (12-byte) cryptographically random nonce is generated on every write.
- **Additional Authenticated Data (AAD):** Existing encrypted records remain bound to the legacy `tradex-copilot:v1:<owner_key>` compatibility identifier, so moving or renaming a workspace file across owners fails authentication.
- **Atomic Writes:** Temp files (`<owner_key>.json.tmp`) are written only after encryption and renamed atomically. Leftover `.tmp` files from interrupted writes are cleaned up during `open()`.

## 2. Key Configuration

Provide a 256-bit (32-byte) key via environment variable (encoded as 64 hexadecimal characters or 44 base64/base64url characters):

```bash
# Generate a new 256-bit key:
openssl rand -hex 32

# Set in environment or secret manager:
export COPILOT_WORKSPACE_KEY="<64-char-hex-or-base64-key>"
```

If `COPILOT_WORKSPACE_KEY` (or `COPILOT_ENCRYPTION_KEY`) is missing, malformed, wrong length, or all zeros, `bin/copilot.dart` refuses to start with exit code `78`.

## 3. Key Rotation Procedure

To rotate the workspace encryption key without downtime or data loss:

1. Generate a new 256-bit key (`openssl rand -hex 32`).
2. Set `COPILOT_WORKSPACE_KEY` to the **new** key and `COPILOT_PREVIOUS_WORKSPACE_KEY` to the **previous** key.
3. Restart the Copilot service. During `open()`, workspaces encrypted with `COPILOT_PREVIOUS_WORKSPACE_KEY` are authenticated, decrypted, and atomically re-encrypted under the new `COPILOT_WORKSPACE_KEY` with fresh nonces.
4. Once startup completes, remove `COPILOT_PREVIOUS_WORKSPACE_KEY` from the deployment configuration.

You can also rotate keys programmatically on an open `WorkspaceStore` instance by calling `await store.rotateKey(newKey)`.

## 4. Backup Recovery

- **Backups:** Back up the encrypted `<owner_key>.json` files in `COPILOT_DATA_DIR` separately from `COPILOT_WORKSPACE_KEY` (store the key in your secret manager / KMS).
- **Tamper / Wrong-Key Protection:** If a workspace file is corrupted, tampered with, or opened with the wrong key, `WorkspaceStore.open()` aborts with `WorkspaceEncryptionException` before modifying or overwriting the existing `.json` file on disk.
- **Restoring:** Restore the `.json` files into `COPILOT_DATA_DIR`, ensure the matching `COPILOT_WORKSPACE_KEY` (or `COPILOT_PREVIOUS_WORKSPACE_KEY`) is configured in the environment, and start the service.
