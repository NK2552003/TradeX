import assert from "node:assert/strict";
import { handleRequest as ai } from "../ai-gateway/index.ts";
import { handleRequest as deletion } from "../admin-delete-user/index.ts";

const actor = "11111111-1111-4111-8111-111111111111";
const target = "22222222-2222-4222-8222-222222222222";
const record = "33333333-3333-4333-8333-333333333333";
const settings: Record<string, string> = {
  SUPABASE_URL: "https://test.supabase.co",
  SUPABASE_ANON_KEY: "test-public-key",
  SUPABASE_SECRET_KEY: "test-server-key",
  OPENROUTER_API_KEY: "test-provider-key",
};
const env = (name: string) => settings[name];
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
const post = (body: unknown) =>
  new Request("https://test.supabase.co/functions/v1/test", {
    method: "POST",
    headers: { authorization: "Bearer test-user-jwt" },
    body: JSON.stringify(body),
  });
type Call = { path: string; method: string; body: Record<string, unknown> };
function network(
  respond: (call: Call) => Response,
): { fetch: typeof fetch; calls: Call[] } {
  const calls: Call[] = [];
  return {
    calls,
    fetch: ((input: RequestInfo | URL, init?: RequestInit) => {
      const url = new URL(input instanceof Request ? input.url : String(input));
      const call = {
        path: url.pathname,
        method: init?.method ?? "GET",
        body: typeof init?.body === "string" ? JSON.parse(init.body) : {},
      };
      calls.push(call);
      return Promise.resolve(respond(call));
    }) as typeof fetch,
  };
}
const identity = () => json({ id: actor, role: "authenticated" });
const deletionBody = {
  request_id: record,
  confirmation: "test_account",
  reason: "Confirmed test deletion",
};

for (const [name, handler] of [["AI", ai], ["deletion", deletion]] as const) {
  Deno.test(name + " rejects unsigned requests before touching data", async () => {
    const response = await handler(new Request("https://test.invalid", { method: "POST" }));
    assert.equal(response.status, 401);
  });
  Deno.test(name + " permits CORS preflight only", async () => {
    assert.equal((await handler(new Request("https://test.invalid", { method: "OPTIONS" }))).status, 200);
    assert.equal((await handler(new Request("https://test.invalid"))).status, 405);
  });
}

Deno.test("deletion rejects a non-administrator before claiming a job", async () => {
  const remote = network((call) => {
    if (call.path === "/auth/v1/user") return identity();
    if (call.path === "/rest/v1/profiles") return json({ id: actor, role: "customer", status: "active" });
    throw new Error("Unexpected privileged request: " + call.path);
  });
  assert.equal((await deletion(post(deletionBody), { env, ...remote })).status, 403);
  assert.equal(remote.calls.length, 2);
});

Deno.test("deletion cleans files before deleting Auth and records completion", async () => {
  let batches = 0;
  const remote = network((call) => {
    if (call.path === "/auth/v1/user") return identity();
    if (call.path === "/rest/v1/profiles") return json({ id: actor, role: "user_admin", status: "active" });
    if (call.path.endsWith("/admin_claim_deletion")) return json({ user_id: target });
    if (call.path.endsWith("/admin_deletion_storage_batch")) {
      return json(batches++ === 0 ? [{ bucket_id: "notes", name: target + "/example.png" }] : []);
    }
    if (call.path === "/storage/v1/object/notes") {
      assert.deepEqual(call.body.prefixes, [target + "/example.png"]);
      return json([]);
    }
    if (call.path === "/auth/v1/admin/users/" + target) return json({ id: target });
    if (call.path.endsWith("/admin_finish_deletion")) return json(null);
    throw new Error("Unexpected request: " + call.path);
  });
  const response = await deletion(post(deletionBody), { env, ...remote });
  assert.deepEqual(await response.json(), { deleted: true });
  const removedFile = remote.calls.findIndex((call) => call.path.startsWith("/storage/"));
  const removedAuth = remote.calls.findIndex((call) => call.method === "DELETE" && call.path.startsWith("/auth/"));
  assert(removedFile >= 0 && removedFile < removedAuth);
  assert.equal(remote.calls.at(-1)?.body.p_files, 1);
});

Deno.test("deletion reconciles a removed Auth account without deleting it again", async () => {
  const remote = network((call) => {
    if (call.path === "/auth/v1/user") return identity();
    if (call.path === "/rest/v1/profiles") return json({ id: actor, role: "user_admin", status: "active" });
    if (call.path.endsWith("/admin_claim_deletion")) return json({ user_id: target, auth_deleted: true });
    if (call.path.endsWith("/admin_deletion_storage_batch")) return json([]);
    if (call.path.endsWith("/admin_finish_deletion")) return json(null);
    throw new Error("Unexpected destructive request: " + call.path);
  });
  assert.equal((await deletion(post(deletionBody), { env, ...remote })).status, 200);
  assert(!remote.calls.some((call) => call.path.startsWith("/auth/v1/admin")));
});

Deno.test("deletion failures persist a retryable error receipt", async () => {
  const remote = network((call) => {
    if (call.path === "/auth/v1/user") return identity();
    if (call.path === "/rest/v1/profiles") return json({ id: actor, role: "user_admin", status: "active" });
    if (call.path.endsWith("/admin_claim_deletion")) return json({ user_id: target });
    if (call.path === "/auth/v1/admin/users/" + target) return json({ id: target });
    if (call.path.endsWith("/admin_deletion_storage_batch")) return json({ message: "Storage unavailable", code: "P0001" }, 400);
    if (call.path.endsWith("/admin_finish_deletion")) {
      assert.equal(call.body.p_error, "Storage unavailable");
      return json(null);
    }
    throw new Error("Unexpected request: " + call.path);
  });
  assert.equal((await deletion(post(deletionBody), { env, ...remote })).status, 500);
  assert(!remote.calls.some((call) => call.method === "DELETE"));
});

for (const [code, status] of [["P0001", 429], ["42501", 403]] as const) {
  Deno.test("AI stops before provider use when reservation fails: " + code, async () => {
    const remote = network((call) => {
      if (call.path === "/auth/v1/user") return identity();
      if (call.path.endsWith("/reserve_ai_request")) return json({ code, message: "Account request denied" }, 400);
      throw new Error("Provider must not be called: " + call.path);
    });
    assert.equal((await ai(post({ prompt: "Analyze my notes" }), { env, ...remote })).status, status);
    assert.equal(remote.calls.length, 2);
  });
}

for (const canUseAi of [true, false]) {
  Deno.test("AI persists output only while access remains active: " + canUseAi, async () => {
    const remote = network((call) => {
      if (call.path === "/auth/v1/user") return identity();
      if (call.path.endsWith("/reserve_ai_request")) return json({ request_id: record, user_id: actor, usage: { user_id: actor, ai_queries_used: 1 } });
      if (call.path === "/api/v1/chat/completions") return json({ model: "test-model", choices: [{ message: { content: "Recorded analysis" } }], usage: { prompt_tokens: 12, completion_tokens: 8 } });
      if (call.path.endsWith("/get_my_admin_access")) return json({ status: "active", features: { ai: canUseAi } });
      if (call.path.endsWith("/finish_ai_request")) return json(null);
      throw new Error("Unexpected request: " + call.path);
    });
    const response = await ai(post({ prompt: "Analyze my notes" }), { env, ...remote });
    const completed = remote.calls.find((call) => call.path.endsWith("/finish_ai_request"))!;
    assert.equal(response.status, canUseAi ? 200 : 503);
    if (canUseAi) {
      assert.equal(completed.body.p_body, "Recorded analysis");
      assert.equal(completed.body.p_input_tokens, 12);
      assert.equal(completed.body.p_output_tokens, 8);
      assert.equal((await response.json()).usage.ai_queries_used, 1);
    } else {
      assert.equal(completed.body.p_body, undefined);
      assert.equal(typeof completed.body.p_error, "string");
      assert.equal((await response.json()).text, undefined);
    }
  });
}

Deno.test("AI validates conversation identity before reserving quota", async () => {
  const remote = network(() => { throw new Error("No network call expected"); });
  assert.equal((await ai(post({ prompt: "Analyze", thread_id: "../other-account" }), { env, ...remote })).status, 400);
  assert.equal(remote.calls.length, 0);
});
