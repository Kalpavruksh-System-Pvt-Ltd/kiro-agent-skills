# kiro-agent-skills

Claude Code skills for [Kiro Beauty](https://www.kirobeauty.com) — powered by [kiro-agent](https://github.com/Kalpavruksh-System-Pvt-Ltd/kiro-agent).

These skills let you query Kiro's business data (sales, inventory, ads, finance) directly from Claude Desktop by talking naturally.

---

## Installation

Requires [Claude Code](https://claude.ai/code) (any version).

```bash
git clone https://github.com/Kalpavruksh-System-Pvt-Ltd/kiro-agent-skills ~/.claude/skills/kiro-agent-skills
cd ~/.claude/skills/kiro-agent-skills
./install.sh
```

Then authenticate once:

```bash
~/.claude/skills/kiro-agent/bin/kiro-login
```

Your browser opens Google sign-in. After authenticating, copy the token shown and paste it back into the terminal. Done — you stay logged in for 48 hours.

---

## Usage

In any Claude conversation, invoke a skill by name:

```
/kiro-sales
```

Claude will greet you with your connection status and wait for questions like:
- "How many orders did we get this week?"
- "What's our revenue this month vs last month?"
- "Which products are running low on stock?"

---

## Available Skills

| Skill | What it does |
|---|---|
| `/kiro-sales` | D2C sales, revenue, customers (Shopify) |

More skills will be added as integrations are built (inventory, finance, ads, analytics).

---

## Re-authentication

Tokens expire after 48 hours. When Claude tells you the token has expired:

```bash
~/.claude/skills/kiro-agent/bin/kiro-login
```

---

## Updating

```bash
cd ~/.claude/skills/kiro-agent-skills
git pull
./install.sh
```

---

## Access

Only `@kirobeauty.com` Google accounts (and admin-allowlisted emails) can authenticate. Contact the kiro-agent administrator to request access.
