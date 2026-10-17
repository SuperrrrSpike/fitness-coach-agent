import assert from "node:assert/strict";
import test from "node:test";

import { authenticateUser } from "../supabase/functions/recognize-food/auth.mjs";


function request(headers = {}) {
  return new Request("https://function.example/recognize-food", { headers });
}


test("missing user JWT is rejected without an auth request", async () => {
  let called = false;
  const result = await authenticateUser(request({ apikey: "fixture-public-key" }), {
    supabaseUrl: "https://demo.supabase.co",
    fetcher: async () => {
      called = true;
      return new Response(null, { status: 200 });
    },
  });

  assert.equal(result.status, 401);
  assert.equal(called, false);
});


test("valid user JWT is verified by Supabase Auth", async () => {
  const calls = [];
  const result = await authenticateUser(
    request({
      authorization: "Bearer fixture-user-jwt",
      apikey: "fixture-public-key",
    }),
    {
      supabaseUrl: "https://demo.supabase.co/",
      fetcher: async (url, options) => {
        calls.push({ url, options });
        return new Response("{}", { status: 200 });
      },
    },
  );

  assert.equal(result.ok, true);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, "https://demo.supabase.co/auth/v1/user");
  assert.equal(calls[0].options.headers.Authorization, "Bearer fixture-user-jwt");
  assert.equal(calls[0].options.headers.apikey, "fixture-public-key");
});


test("invalid user JWT is rejected without reading the response body", async () => {
  const result = await authenticateUser(
    request({ authorization: "Bearer expired-user-jwt" }),
    {
      supabaseUrl: "https://demo.supabase.co",
      anonKey: "fixture-public-key",
      fetcher: async () => new Response("sensitive upstream detail", { status: 401 }),
    },
  );

  assert.deepEqual(result, {
    ok: false,
    status: 401,
    error: "登录状态无效或已过期",
  });
});


test("auth service failure is distinguished from an invalid login", async () => {
  const result = await authenticateUser(
    request({ authorization: "Bearer fixture-user-jwt" }),
    {
      supabaseUrl: "https://demo.supabase.co",
      anonKey: "fixture-public-key",
      fetcher: async () => {
        throw new Error("fixture network failure");
      },
    },
  );

  assert.equal(result.status, 503);
  assert.match(result.error, /暂时不可用/);
});
