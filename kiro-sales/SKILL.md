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
| `GET /shopify/orders` | List recent Shopify orders |
| `GET /shopify/orders/summary` | Revenue summary (total sales, order count, AOV) |
| `GET /shopify/products` | Product catalog with variants and inventory |
| `GET /zoho/inventory/sales-orders` | Zoho Inventory sales orders |
| `GET /zoho/inventory/purchase-orders` | Zoho Inventory purchase orders |
| `GET /zoho/inventory/items` | Zoho Inventory items with stock levels |
| `GET /zoho/inventory/warehouses` | Warehouse locations |
| `GET /zoho/books/invoices` | Zoho Books invoices |
| `GET /zoho/books/credit-notes` | Zoho Books credit notes (returns/refunds) |
| `GET /zoho/books/bills` | Zoho Books bills (expenses/payables) |

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

**Zoho pagination params** (shared by all Zoho endpoints):

| Param | Type | Default | Description |
|---|---|---|---|
| `page` | 1+ | 1 | Page number |
| `per_page` | 1–200 | 50 | Results per page |

**Zoho date/status filters** (shared by sales-orders, purchase-orders, invoices, credit-notes, bills):

| Param | Type | Description |
|---|---|---|
| `date_start` | `YYYY-MM-DD` | Filter from this date |
| `date_end` | `YYYY-MM-DD` | Filter up to this date |
| `status` | string | Status filter (varies by entity) |

**GET /zoho/inventory/items** additional params:

| Param | Type | Description |
|---|---|---|
| `status` | `active\|inactive` | Item status |
| `search_text` | string | Search by name/SKU |

### Query patterns

**Shopify (D2C e-commerce)**
- "Sales today" → `GET /shopify/orders/summary?created_at_min=<today ISO>`
- "Orders this week" → `GET /shopify/orders?created_at_min=<monday ISO>`
- "Top products" → `GET /shopify/orders?limit=250` then aggregate by item title
- "Revenue last month" → `GET /shopify/orders/summary?created_at_min=<1st>&created_at_max=<last>`
- "Show me our products" → `GET /shopify/products`
- "What's low on stock (Shopify)" → `GET /shopify/products` then filter by low `inventory_quantity`

**Zoho Inventory (system of record)**
- "Inventory stock levels" → `GET /zoho/inventory/items`
- "Low stock items" → `GET /zoho/inventory/items` then filter by low `stock_on_hand`
- "Recent purchase orders" → `GET /zoho/inventory/purchase-orders`
- "Sales orders this month" → `GET /zoho/inventory/sales-orders?date_start=<1st>&date_end=<today>`
- "Our warehouses" → `GET /zoho/inventory/warehouses`
- "Find item by name" → `GET /zoho/inventory/items?search_text=<query>`

**Zoho Books (accounting)**
- "Recent invoices" → `GET /zoho/books/invoices`
- "Unpaid invoices" → `GET /zoho/books/invoices?status=unpaid`
- "Credit notes / returns" → `GET /zoho/books/credit-notes`
- "Bills / expenses" → `GET /zoho/books/bills`
- "Overdue bills" → `GET /zoho/books/bills?status=overdue`

When the user asks for data not yet available (e.g. Meta ads, Google Ads, Zoho Analytics), say:
> "That integration isn't live yet — it's on the roadmap."
