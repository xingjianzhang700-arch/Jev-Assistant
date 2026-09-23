import assert from "node:assert/strict";
import { test } from "node:test";
import { customOrigins } from "../lib/origins.js";

test("blank and OpenRouter URLs need no extra permission", () => {
  assert.deepEqual(customOrigins("", "  "), { origins: [] });
  assert.deepEqual(
    customOrigins("https://openrouter.ai/api/v1/chat/completions", "https://openrouter.ai/api/v1"),
    { origins: [] },
  );
});

test("a custom https host becomes an origin pattern", () => {
  assert.deepEqual(customOrigins("https://api.example.com/v1", ""), {
    origins: ["https://api.example.com/*"],
  });
});

test("an unparseable Judge URL is named and blocks save", () => {
  assert.deepEqual(customOrigins("not a url", "https://api.example.com/v1"), {
    error: "Invalid URL: Judge URL",
  });
});

test("an unparseable Reply URL is named", () => {
  assert.deepEqual(customOrigins("https://api.example.com/v1", "::::"), {
    error: "Invalid URL: Reply URL",
  });
});
