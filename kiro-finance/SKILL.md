# kiro-finance

Kiro Beauty financial data. Use this skill to query invoices, credit notes,
and bills/expenses from Zoho Books.

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
Zoho dates use `YYYY-MM-DD` format.

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

| Endpoint | Description |
|---|---|
| `GET /zoho/books/invoices` | Customer invoices |
| `GET /zoho/books/credit-notes` | Credit notes (returns/refunds) |
| `GET /zoho/books/bills` | Bills from vendors (expenses/payables) |

### Shared params

All three endpoints accept the same filters:

| Param | Type | Default | Description |
|---|---|---|---|
| `page` | 1+ | 1 | Page number |
| `per_page` | 1–200 | 50 | Results per page |
| `date_start` | `YYYY-MM-DD` | — | Filter from this date |
| `date_end` | `YYYY-MM-DD` | — | Filter up to this date |
| `status` | string | — | Status filter (varies by entity) |

### Response fields

**Invoices**: `id`, `number`, `date`, `due_date`, `status`, `customer`, `total`, `balance`, `currency`, `created_at`

**Credit notes**: `id`, `number`, `date`, `status`, `customer`, `total`, `balance`, `currency`, `created_at`

**Bills**: `id`, `number`, `date`, `due_date`, `status`, `vendor`, `total`, `balance`, `currency`, `created_at`

### Query patterns

- "Recent invoices" → `GET /zoho/books/invoices`
- "Unpaid invoices" → `GET /zoho/books/invoices?status=unpaid`
- "Overdue invoices" → `GET /zoho/books/invoices?status=overdue`
- "Invoices this month" → `GET /zoho/books/invoices?date_start=<1st>&date_end=<today>`
- "Credit notes / returns" → `GET /zoho/books/credit-notes`
- "Bills / expenses" → `GET /zoho/books/bills`
- "Overdue bills" → `GET /zoho/books/bills?status=overdue`
- "Vendor bills this month" → `GET /zoho/books/bills?date_start=<1st>&date_end=<today>`

When the user asks for sales, revenue, stock, or products, suggest they use `/kiro-sales` or `/kiro-inventory` instead.
