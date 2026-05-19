# kiro-analytics

Zoho Analytics data for Kiro Beauty. Use this skill to explore available reports,
tables, and dashboards — and to fetch data from any of them.

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

### Workflow

**For asset/structure questions** (dependencies, duplicates, workspace overview):
1. Call `GET /zoho/analytics/assets` — returns the full workspace map in one call.
2. Use `summary.by_type` for composition, `dependencies` for lineage, `duplicates` for cleanup.
3. To drill into a specific view's data, follow up with `GET /zoho/analytics/views/:viewId/data`.

**For data queries** (fetching rows from a specific report/table):
1. **Find the right view** — call `GET /zoho/analytics/views` with a `search=` term.
2. **Fetch the data** — call `GET /zoho/analytics/views/:viewId/data` using the `id` from step 1.

Never guess a `viewId` — always look it up first.

### Available endpoints

| Endpoint | Description |
|---|---|
| `GET /zoho/analytics/assets` | Full workspace map: all views, dependency graph, duplicate detection |
| `GET /zoho/analytics/views` | List all reports and tables in the workspace |
| `GET /zoho/analytics/views/:viewId/data` | Fetch all rows from a specific view |

### Endpoint details

**GET /zoho/analytics/assets**

| Param | Type | Description |
|---|---|---|
| `refresh` | `true` | Force a fresh fetch, bypassing the 1-hour cache |

Returns: `workspace_id`, `fetched_at`, `summary` (total count + breakdown by type), `views[]` (each with `id`, `name`, `type`, `description`, `created_by`, `created_at`, `modified_at`, `depends_on[]`), `dependencies[]` (edges with `from`, `from_name`, `to`, `to_name`, `relationship`), `duplicates[]` (groups of views with identical names).

Use this endpoint to:
- Understand what's in the workspace and how it's organized
- Trace which queries/tables feed into a dashboard or report
- Find duplicate or redundant reports and queries for cleanup
- Get a bird's-eye view before drilling into specific data

**GET /zoho/analytics/views**

| Param | Type | Description |
|---|---|---|
| `search` | string | Filter views by name (case-insensitive substring match) |
| `type` | `Table\|QueryTable\|Pivot\|Dashboard\|AnalysisView` | Filter by view type |

Returns: `count`, `view_types`, `views[]` — each with `id`, `name`, `type`, `description`

Use `type=Table` or `type=QueryTable` when you need raw data rows.
Use `type=Dashboard` or `type=AnalysisView` to find pre-built reports.

**GET /zoho/analytics/views/:viewId/data**

| Param | Type | Description |
|---|---|---|
| `criteria` | string | Optional Zoho SQL-style filter e.g. `"Status"='Active'` |

Returns: `column_count`, `row_count`, `columns[]`, `rows[]` — rows are objects keyed by column name.

### Query patterns

- "What's in our analytics workspace?" → `GET /zoho/analytics/assets`
- "What reports depend on the orders query?" → `GET /zoho/analytics/assets` → filter `dependencies` where `to_name` contains "orders"
- "Are there duplicate reports?" → `GET /zoho/analytics/assets` → check `duplicates` array
- "Which queries feed the Sales Dashboard?" → `GET /zoho/analytics/assets` → filter `dependencies` where `from_name` = "Sales Dashboard"
- "What analytics reports do we have?" → `GET /zoho/analytics/views?type=Dashboard`
- "Show me the Kiro orders table" → `GET /zoho/analytics/views?search=kiro+orders`, then fetch data from the matching Table
- "What data is in the discount report?" → search for "discount", pick the right view, fetch data
- "Show me sales data from analytics" → search for "sales" or "order", pick best match, fetch data
- "What tables are available?" → `GET /zoho/analytics/views?type=Table`
- "Run a query on the orders table" → find view by name, then `GET /zoho/analytics/views/:viewId/data?criteria=<filter>`

### Display guidelines

- When listing views, group by type and show `name`, `type`, and `description`.
- When showing data rows, format as a table with column headers.
- If `row_count` is large (>50), summarise the data rather than showing every row — highlight key numbers.
- Numeric strings that look like currency (e.g. `"1175.00"`) should be displayed as ₹ amounts.

When the user asks for live sales orders, revenue, inventory, or financial records, suggest the appropriate skill:
`/kiro-sales`, `/kiro-inventory`, or `/kiro-finance`.
