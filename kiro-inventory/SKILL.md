# kiro-inventory

Kiro Beauty inventory data. Use this skill to query stock levels, products,
purchase orders, and warehouses from Zoho Inventory and Shopify.

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
Zoho dates use `YYYY-MM-DD`. Shopify dates use ISO 8601.

### Available endpoints

| Endpoint | Source | Description |
|---|---|---|
| `GET /zoho/inventory/items` | Zoho | Items with stock levels (system of record) |
| `GET /zoho/inventory/purchase-orders` | Zoho | Purchase orders from suppliers |
| `GET /zoho/inventory/warehouses` | Zoho | Warehouse locations |
| `GET /shopify/products` | Shopify | D2C product catalog with variants |

### Endpoint details

**GET /zoho/inventory/items**

| Param | Type | Default | Description |
|---|---|---|---|
| `page` | 1+ | 1 | Page number |
| `per_page` | 1–200 | 50 | Results per page |
| `status` | `active\|inactive` | — | Item status |
| `search_text` | string | — | Search by name or SKU |

Returns: `id`, `name`, `sku`, `status`, `rate`, `purchase_rate`, `stock_on_hand`, `available_stock`, `unit`, `item_type`, `product_type`, `category`, `brand`

**GET /zoho/inventory/purchase-orders**

| Param | Type | Default | Description |
|---|---|---|---|
| `page` | 1+ | 1 | Page number |
| `per_page` | 1–200 | 50 | Results per page |
| `date_start` | `YYYY-MM-DD` | — | Filter from this date |
| `date_end` | `YYYY-MM-DD` | — | Filter up to this date |
| `status` | string | — | Status filter |

**GET /zoho/inventory/warehouses**

No parameters. Returns list of warehouses with `id`, `name`, `status`, `is_primary`, `city`, `state`, `country`.

**GET /shopify/products**

| Param | Type | Default | Description |
|---|---|---|---|
| `status` | `active\|draft\|archived` | `active` | Product status |
| `limit` | 1–250 | 50 | Max products to return |

### Query patterns

- "What's our stock?" → `GET /zoho/inventory/items`
- "Low stock items" → `GET /zoho/inventory/items` then filter by low `stock_on_hand`
- "Find item by name" → `GET /zoho/inventory/items?search_text=<query>`
- "Recent purchase orders" → `GET /zoho/inventory/purchase-orders`
- "POs this month" → `GET /zoho/inventory/purchase-orders?date_start=<1st>&date_end=<today>`
- "Our warehouses" → `GET /zoho/inventory/warehouses`
- "Shopify products" → `GET /shopify/products`
- "Show me our product catalog" → `GET /shopify/products?limit=250`

When the user asks for sales, revenue, invoices, or bills, suggest they use `/kiro-sales` or `/kiro-finance` instead.
