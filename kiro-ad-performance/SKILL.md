# kiro-ad-performance

Meta Ads performance data for Kiro Beauty. Use this skill to query ad spend,
ROAS, attributed revenue, and per-campaign / per-ad breakdowns.

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
All dates: `YYYY-MM-DD`.

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
| `GET /meta/ads/account-insights` | Total ad spend, ROAS, revenue, impressions, clicks, CPC, CPM, CTR, reach, frequency |
| `GET /meta/ads/campaign-insights` | Same metrics broken down by campaign |
| `GET /meta/ads/top-ads` | Top N ads by spend with full metrics |

### Endpoint details

**GET /meta/ads/account-insights**

| Param | Type | Default | Description |
|---|---|---|---|
| `date_start` | `YYYY-MM-DD` | required | Period start |
| `date_end` | `YYYY-MM-DD` | required | Period end |
| `time_increment` | `1\|all_days` | `all_days` | `1` = daily breakdown, `all_days` = single total |

Returns: `spend`, `roas`, `purchases`, `purchase_value`, `impressions`, `clicks`, `cpc`, `cpm`, `ctr`, `reach`, `frequency`

**GET /meta/ads/campaign-insights**

| Param | Type | Default | Description |
|---|---|---|---|
| `date_start` | `YYYY-MM-DD` | required | Period start |
| `date_end` | `YYYY-MM-DD` | required | Period end |

Returns array of campaigns each with: `campaign_id`, `campaign_name`, `spend`, `roas`, `purchases`, `purchase_value`, `impressions`, `clicks`, `cpc`, `cpm`, `ctr`, `reach`, `frequency`

**GET /meta/ads/top-ads**

| Param | Type | Default | Description |
|---|---|---|---|
| `date_start` | `YYYY-MM-DD` | required | Period start |
| `date_end` | `YYYY-MM-DD` | required | Period end |
| `limit` | 1–50 | 10 | Number of top ads to return |

Returns array of ads sorted by spend (descending) with: `ad_id`, `ad_name`, `campaign_name`, plus all metrics above.

### Query patterns

- "Ad spend this week" → `GET /meta/ads/account-insights?date_start=<start>&date_end=<end>`
- "Daily ad spend breakdown" → `GET /meta/ads/account-insights?date_start=<start>&date_end=<end>&time_increment=1`
- "ROAS last 15 days" → `GET /meta/ads/account-insights?date_start=<start>&date_end=<end>`
- "Best performing campaigns" → `GET /meta/ads/campaign-insights?date_start=<start>&date_end=<end>`
- "Top 5 ads by spend" → `GET /meta/ads/top-ads?date_start=<start>&date_end=<end>&limit=5`
- "How much did we spend on ads" → account-insights
- "Which campaign has the best ROAS" → campaign-insights, then highlight highest roas

### Display guidelines

- Always show spend as currency (INR assumed).
- ROAS is a multiplier (e.g., 2.5 means ₹2.50 revenue per ₹1 spent).
- When showing campaign or ad lists, sort by spend descending by default.
- Calculate and show total spend and total purchase_value when showing breakdowns.

When the user asks for sales, revenue, stock, invoices, or bills, suggest they use `/kiro-sales`, `/kiro-inventory`, or `/kiro-finance` instead.
