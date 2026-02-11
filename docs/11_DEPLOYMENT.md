# Deployment Guide

## 🚀 Deployment Strategy

This project consists of two parts to deploy:
1.  **Static Frontend** (The PWA)
2.  **Backend Worker** (Cloudflare Worker)

### 1. Deploying the PWA (Frontend)
Since the frontend is purely static files, it can be hosted anywhere (GitHub Pages, Vercel, Netlify, Cloudflare Pages).

**Recommended: Cloudflare Pages**
1.  Connect your GitHub Repo.
2.  Build settings:
    - **Build Command**: (Empty) - none needed.
    - **Output Directory**: `pwa`
3.  Deploy.

**Important: Updating**
When you push code changes:
1.  Modify `pwa/sw.js`.
2.  Change `const CACHE_NAME = 'hyper-monitor-vX';` to a new number (`vX+1`).
3.  Commit and Push.
4.  If you *don't* do this, users will not see the new changes until their cache expires (days).

### 2. Deploying the Backend
(Assuming you have the worker script in a separate repo or folder)

Use `wrangler` (Cloudflare CLI):
```bash
npx wrangler deploy worker.js
```
Ensure the worker is returning CORS headers allowing your Frontend's domain.

## 🔄 CI/CD
Currently, deployment is manual.
Future improvement: Set up GitHub Actions to automatically run linter and deploy to Cloudflare Pages on push to `master`.
