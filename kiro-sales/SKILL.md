# kiro-sales

Kiro Beauty sales assistant. Authenticates with the kiro-agent API server and
retrieves business data. Use this skill to query sales, inventory, ads, and
financial data for Kiro Beauty.

## Connect

Run this single block. It checks for a saved token, signs in if needed, and
verifies the connection — all in one step.

```bash
TOKEN_FILE="$HOME/.claude/skills/kiro-agent/.kiro-token"
API_BASE="https://app-service-lmqrue7ola-el.a.run.app"

# Load existing token
TOKEN=""
[ -f "$TOKEN_FILE" ] && TOKEN=$(cat "$TOKEN_FILE" 2>/dev/null | tr -d '[:space:]')

# If no token, sign in
if [ -z "$TOKEN" ]; then
  echo "No token found — signing in..."
  ~/.claude/skills/kiro-agent/bin/kiro-login
  [ -f "$TOKEN_FILE" ] && TOKEN=$(cat "$TOKEN_FILE" 2>/dev/null | tr -d '[:space:]')
fi

# Verify
if [ -n "$TOKEN" ]; then
  RESPONSE=$(curl -sf -H "Authorization: Bearer $TOKEN" "$API_BASE/hello" 2>&1) && {
    echo "$RESPONSE"
    exit 0
  }
  # Token expired — re-authenticate
  echo "Token expired — re-authenticating..."
  rm -f "$TOKEN_FILE"
  ~/.claude/skills/kiro-agent/bin/kiro-login
  [ -f "$TOKEN_FILE" ] && TOKEN=$(cat "$TOKEN_FILE" 2>/dev/null | tr -d '[:space:]')
  if [ -n "$TOKEN" ]; then
    curl -sf -H "Authorization: Bearer $TOKEN" "$API_BASE/hello" 2>&1
  fi
fi
```

If the response contains `"Hello, Kiro"`:
- Greet the user: "Connected to kiro-agent as `<email>`. What would you like to know?"
- Wait for their query and proceed to **Answer queries**.

If it failed, show the error and stop.

## Answer queries

Use `Authorization: Bearer $TOKEN` on all API calls to `$API_BASE`.
All dates use ISO 8601 format (e.g. `2026-05-01T00:00:00+05:30`). Kiro is based in India (IST).

### Available endpoints

| Endpoint | Description |
|---|---|
| `GET /hello` | Connection test — returns greeting and authenticated email |
| `GET /shopify/orders` | List recent orders |
| `GET /shopify/orders/summary` | Revenue summary (total sales, order count, AOV) |
| `GET /shopify/products` | Product catalog with variants and inventory |

### Endpoint details

**GET /shopify/orders**

| Param | Type | Default | Description |
|---|---|---|---|
| `status` | `any\|open\|closed\|cancelled` | `any` | Order status filter |
| `financial_status` | `any\|paid\|pending\|refunded` | — | Payment status filter |
| `created_at_min` | ISO date | — | Orders created after this date |
| `created_at_max` | ISO date | — | Orders created before this date |
| `limit` | 1–250 | 50 | Max orders to return |

**GET /shopify/orders/summary**

| Param | Type | Default | Description |
|---|---|---|---|
| `created_at_min` | ISO date | — | Period start |
| `created_at_max` | ISO date | — | Period end |
| `financial_status` | `any\|paid\|pending\|refunded` | `any` | Filter by payment status |

Returns: `order_count`, `total_revenue`, `average_order_value`, `total_tax`, `total_discounts`, `currency`

**GET /shopify/products**

| Param | Type | Default | Description |
|---|---|---|---|
| `status` | `active\|draft\|archived` | `active` | Product status |
| `limit` | 1–250 | 50 | Max products to return |

### Query patterns

- "Sales today" → `GET /shopify/orders/summary?created_at_min=<today ISO>`
- "Orders this week" → `GET /shopify/orders?created_at_min=<monday ISO>`
- "Top products" → `GET /shopify/orders?limit=250` then aggregate by item title
- "Revenue last month" → `GET /shopify/orders/summary?created_at_min=<1st>&created_at_max=<last>`
- "Show me our products" → `GET /shopify/products`
- "What's low on stock" → `GET /shopify/products` then filter by low `inventory_quantity`

When the user asks for data not yet available (e.g. Meta ads, Zoho), say:
> "That integration isn't live yet — it's on the roadmap. Your Shopify connection is working."
