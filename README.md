<p align="center">
  <img src="https://raw.githubusercontent.com/iaurg/paperclip-railway/main/assets/icon.png" alt="Paperclip (Zero Config)" width="128" height="128">
</p>

# Deploy and Host Paperclip with Railway

Paperclip is the open-source app for running a company of AI agents: hire Claude Code, Codex and other agents into an org chart, give them goals and monthly budgets, and review their work from one board. This template deploys it production-ready in one click: login required, Postgres included, every secret pre-generated, nothing to fill in.

## ⚠️ First login

> **Your first admin account is created from a one-time link in the deploy logs, not from a sign-up page.**
>
> After the deploy turns green, open the **Paperclip** service → **Deployments** → **View Logs** and search for **`Invite URL`**. Open that link to create the owner account.
>
> This is on purpose, for security: only members of your Railway project can read the logs, so nobody who finds your URL can claim your instance first. The link expires in 72 hours; if you miss it, **Restart** the service to get a new one.

## About Hosting Paperclip

Paperclip is a Node.js server with a bundled web UI. It keeps companies, agents, tickets and run history in PostgreSQL, and runs agents as processes inside its own container, using the Claude Code, Codex, OpenCode and Gemini CLIs that ship in the official image. Files, the secrets encryption key and agent workspaces live on a persistent volume.

Hosting it on the internet safely takes more than `docker run`: authenticated mode, a public auth URL, four signing and encryption secrets, a volume with the right permissions, and a one-time invite to create the first admin. This template handles all of it. You click Deploy, open one link from the logs, and you're the owner.

## Common Use Cases

- Keep an AI agent team working on scheduled heartbeats 24/7, not only while your laptop is open
- Put Claude Code and Codex agents to work on your GitHub repos, with a per-agent monthly budget that stops runaway spend
- Give your team a shared board to assign tickets to agents, approve their actions and audit every run
- Run several AI "companies" side by side, each with its own goals, org chart and costs

## Dependencies for Paperclip Hosting

- **PostgreSQL**: included in this template, connected over Railway's private network
- **Persistent volume** at `/paperclip`: included in this template
- **An AI provider API key** (Anthropic, OpenAI or Google): optional at deploy time; add it now or later, when you create your first agent

### Deployment Dependencies

- Paperclip documentation: https://docs.paperclip.ing
- Paperclip source code (MIT): https://github.com/paperclipai/paperclip
- Anthropic API keys (for Claude Code agents): https://console.anthropic.com/settings/keys
- OpenAI API keys (for Codex agents): https://platform.openai.com/api-keys

### Implementation Details

**Getting started (about 2 minutes)**

1. Click **Deploy**. There is nothing to configure; optionally paste an AI provider key.
2. When the deploy is green, open the **Paperclip** service → **Deployments** → **View Logs** and find this block:

   ```
   ==================================================================
    Paperclip has no admin yet. Open the invite URL below to become
    the CEO/owner of this instance (expires in 72h; redeploy for a new one).
   ==================================================================
   Invite URL: https://paperclip-production-xxxx.up.railway.app/invite/pcp_bootstrap_...
   ```

3. Open the link and create your account. You're the instance owner, and Paperclip walks you through naming your organization and hiring your first agent.

Only members of your Railway project can see the logs, so only they can see the invite. Missed the 72-hour window? **Restart** the service and a fresh link is printed. No SSH, no CLI. Once an admin exists, the step switches itself off.

**What's configured for you**

- Paperclip runs in `authenticated` + `public` mode, the setting its docs specify for internet-facing servers. There is no open setup page for strangers to find, and claiming admin from the browser is disabled.
- `BETTER_AUTH_SECRET`, `PAPERCLIP_AGENT_JWT_SECRET`, `PAPERCLIP_TOOL_ACTION_SIGNING_SECRET` and `PAPERCLIP_SECRETS_MASTER_KEY` are generated uniquely for your deploy.
- The public URL comes from your Railway domain, and database migrations run on every start.
- It's built on the official `ghcr.io/paperclipai/paperclip` image, not a fork. It adds only a small startup script that writes the config and prints the invite.

**Custom domain:** add the domain in Railway, then set `PAPERCLIP_PUBLIC_URL` to `https://your.domain`.

**Pin a version:** set the `PAPERCLIP_IMAGE_TAG` service variable (e.g. a release tag from https://github.com/paperclipai/paperclip/releases) and redeploy. It defaults to `latest`.

### Why Deploy Paperclip on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Paperclip on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
