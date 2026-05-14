# kiro-instagram-mentions

Find Instagram posts that mention Kiro or Kiro products. Use this skill to
discover UGC, influencer mentions, and on-trend hashtag content for Kiro Beauty.

How it works: the skill resolves each hashtag you ask for via the Instagram
Hashtag Search API, fetches recent (or top) public posts under those hashtags,
then filters the captions for the keywords you supply. Only posts whose
captions match at least one keyword are returned (when keywords are provided).

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
- Greet the user: "Connected to kiro-agent as `<email>`. Which hashtags should I scan?"
- Wait for their query and proceed to **Answer queries**.

If it failed, show the error and stop.

## Answer queries

Use `Authorization: Bearer $TOKEN` on all API calls to `$API_BASE`.

### Default hashtag set

If the user doesn't specify hashtags, suggest these and ask them to confirm or edit:

```
kirobeauty, kiro, kiroskincare
```

Don't query more than ~5 hashtags in a single call — the Meta Graph API caps
hashtag lookups at 30 unique tags per 7 days per IG user, so keep the list small
and reuse it across calls.

### Available endpoint

| Endpoint | Description |
|---|---|
| `GET /instagram/hashtag-posts` | Recent or top public posts under given hashtags, optionally caption-filtered by keywords |

### Endpoint details

**GET /instagram/hashtag-posts**

| Param | Type | Default | Description |
|---|---|---|---|
| `tags` | csv | required | Hashtags to scan, comma-separated. Up to 10. Leading `#` is optional. |
| `keywords` | csv | none | Substrings to match against captions (case-insensitive). When omitted, all posts are returned. |
| `period` | `recent\|top` | `recent` | `recent` = chronological recent posts; `top` = Meta's engagement-ranked top posts |
| `limit` | 1–50 | 25 | Max posts to fetch **per hashtag** before dedupe/filter |

Returns:

```json
{
  "tags": ["kirobeauty", "kiro"],
  "keywords": ["kiro", "glow"],
  "period": "recent",
  "limit_per_tag": 25,
  "total_fetched": 47,
  "total_matched": 12,
  "unresolved_tags": [],
  "posts": [
    {
      "id": "17900000000000000",
      "caption": "Loving the new @kirobeauty glow serum...",
      "media_type": "IMAGE",
      "media_url": "https://...",
      "permalink": "https://www.instagram.com/p/...",
      "timestamp": "2026-05-13T18:22:14+0000",
      "like_count": 142,
      "comments_count": 8,
      "hashtag_sources": ["kirobeauty"],
      "matched_keywords": ["kiro", "glow"]
    }
  ]
}
```

Notes on the response:
- `total_fetched` is the deduped count of posts pulled from Meta before keyword filtering.
- `total_matched` is what's returned in `posts` after keyword filtering (equal to `total_fetched` when no keywords were supplied).
- `unresolved_tags` lists hashtags Meta couldn't resolve (typo, banned, or never used) — surface these to the user.
- `posts` is sorted newest first.

### Query patterns

- "Find IG posts mentioning Kiro" →
  `GET /instagram/hashtag-posts?tags=kirobeauty,kiro,kiroskincare&keywords=kiro`
- "Top posts under #kirobeauty this week" →
  `GET /instagram/hashtag-posts?tags=kirobeauty&period=top&limit=25`
- "Posts mentioning our glow serum" →
  `GET /instagram/hashtag-posts?tags=kirobeauty,kiro&keywords=glow%20serum,glow`
- "Latest UGC on #kiroskincare" →
  `GET /instagram/hashtag-posts?tags=kiroskincare&period=recent&limit=50`

### Display guidelines

- Always print a summary line first:
  `Scanned <N> hashtags · fetched <total_fetched> posts · <total_matched> matched`
- Then list matched posts as a bulleted table or list with:
  - timestamp (date only)
  - `matched_keywords` highlighted
  - permalink
  - like/comment counts when present
  - first ~120 chars of caption
- If `unresolved_tags` is non-empty, call them out so the user can fix typos.
- If `total_matched` is 0, suggest broadening the keyword list or switching `period=top`.

### Limits and caveats

- Only **public** posts are visible to the Hashtag Search API. Private accounts and Stories are excluded.
- Meta caps hashtag lookups at **30 unique hashtags per 7 days** per IG user. Reuse the same tag set across calls.
- This skill does not surface @-mentions of `@kirobeauty` — only hashtag-driven discovery. If the user wants @-mentions, tell them that's a future capability and offer the closest hashtag-based proxy (e.g., `#kirobeauty`).

When the user asks for ad performance, sales, inventory, or finance data, suggest
`/kiro-ad-performance`, `/kiro-sales`, `/kiro-inventory`, or `/kiro-finance` instead.
