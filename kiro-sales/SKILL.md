# kiro-sales

Kiro Beauty sales assistant. Authenticates with the kiro-agent API server and
retrieves business data. Use this skill to query sales, inventory, ads, and
financial data for Kiro Beauty.

## Preamble

```bash
TOKEN_FILE="$HOME/.claude/skills/kiro-agent/.kiro-token"
API_BASE="https://app-service-lmqrue7ola-el.a.run.app"
TOKEN=""
[ -f "$TOKEN_FILE" ] && TOKEN=$(cat "$TOKEN_FILE" 2>/dev/null | tr -d '[:space:]')
echo "API_BASE: $API_BASE"
echo "TOKEN_PRESENT: $([ -n "$TOKEN" ] && echo yes || echo no)"
```

## Step 1 — Authenticate

If `TOKEN_PRESENT` is `no`, tell the user "Signing you in..." and run:

```bash
~/.claude/skills/kiro-agent/bin/kiro-login
```

This opens the browser for Google sign-in and captures the token automatically.
If it fails, stop and show the error.

## Step 2 — Verify connection

```bash
TOKEN=$(cat "$HOME/.claude/skills/kiro-agent/.kiro-token" | tr -d '[:space:]')
API_BASE="https://app-service-lmqrue7ola-el.a.run.app"
curl -sf -H "Authorization: Bearer $TOKEN" "$API_BASE/hello"
```

If the response contains `"Hello, Kiro"`:
- Greet the user: "Connected to kiro-agent as `<email>`. What would you like to know?"
- Wait for their query and proceed to Step 3.

If the response is 401 or an error, tell the user "Token expired, re-authenticating..." and run:
```bash
rm -f "$HOME/.claude/skills/kiro-agent/.kiro-token"
~/.claude/skills/kiro-agent/bin/kiro-login
```
Then retry Step 2. If it fails again, stop and show the error.

## Step 3 — Answer queries

Use `Authorization: Bearer $TOKEN` on all API calls to `$API_BASE`.

Available endpoints (grows as integrations are built):

| Endpoint | Description |
|---|---|
| `GET /hello` | Connection test — returns greeting and authenticated email |

When the user asks for data not yet available, say:
> "That integration isn't live yet — it's on the roadmap. Your connection is working correctly."
