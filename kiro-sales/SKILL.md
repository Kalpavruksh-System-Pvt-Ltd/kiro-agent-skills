# kiro-sales

Kiro Beauty sales data. Use this skill to query D2C sales (Shopify) and
B2B/wholesale sales orders (Zoho Inventory).

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
All dates: ISO 8601 for Shopify (e.g. `2026-05-01T00:00:00+05:30`), `YYYY-MM-DD` for Zoho.

### Date rules

1. **Maximum 15-day window** — never query more than 15 days of data in a single request.
2. **Always display the date range** — before showing results, print:
   `Date range: <start_date> to <end_date> (X days)`
3. **User provides a date** — treat it as the **end date**; compute start date as 15 days prior.
   Example: user says "May 10" → end = 2026-05-10, start = 2026-04-25.
4. **No date provided** — default end = today, start = today minus 15 days.
5. **Validate dates** before making any API call:
   - Must be a real calendar date (no Feb 30, no month 13, etc.).
   - Must not be in the future (relative to today).
   - If invalid, tell the user why and ask for a corrected date. Do NOT call the API.

### Available endpoints

| Endpoint | Source | Description |
|---|---|---|
| `GET /shopify/orders` | Shopify | D2C orders (website) |
| `GET /shopify/orders/summary` | Shopify | Revenue summary (total sales, order count, AOV) |
| `GET /zoho/inventory/sales-orders` | Zoho | B2B / wholesale sales orders |

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

**GET /zoho/inventory/sales-orders**

| Param | Type | Default | Description |
|---|---|---|---|
| `page` | 1+ | 1 | Page number |
| `per_page` | 1–200 | 50 | Results per page |
| `date_start` | `YYYY-MM-DD` | — | Filter from this date |
| `date_end` | `YYYY-MM-DD` | — | Filter up to this date |
| `status` | string | — | Status filter |

### Query patterns

- "D2C sales today" → `GET /shopify/orders/summary?created_at_min=<today ISO>`
- "Online orders this week" → `GET /shopify/orders?created_at_min=<monday ISO>`
- "Top products" → `GET /shopify/orders?limit=250` then aggregate by item title
- "Revenue last month" → `GET /shopify/orders/summary?created_at_min=<1st>&created_at_max=<last>`
- "B2B sales orders this month" → `GET /zoho/inventory/sales-orders?date_start=<1st>&date_end=<today>`
- "All sales orders" → `GET /zoho/inventory/sales-orders`

When the user asks for inventory, stock, products, invoices, bills, or expenses, suggest they use `/kiro-inventory` or `/kiro-finance` instead.
