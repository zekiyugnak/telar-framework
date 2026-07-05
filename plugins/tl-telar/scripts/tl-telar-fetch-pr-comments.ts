#!/usr/bin/env npx tsx
// Pure data fetcher for PR comments (CodeRabbit / Bugbot / Greptile / Copilot / human).
// Adapted from dsifry/metaswarm (MIT, (c) 2026 Dave Sifry). See THIRD_PARTY_NOTICES.md.
// Writes .tl-telar/temp/pr-comments.json. No AI calls. No state modifications.
//
// Usage: GITHUB_TOKEN=$(gh auth token) npx tsx scripts/tl-telar-fetch-pr-comments.ts --days 7
// Exit 0 = success or graceful degrade (no comments found). Exit 1 = unexpected error.

import { execSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';

interface Args { days: number; out: string }

interface PrComment {
  pr: number;
  prTitle: string;
  author: string;
  reviewerType: 'coderabbit' | 'bugbot' | 'greptile' | 'copilot' | 'human' | 'unknown';
  body: string;
  createdAt: string;
  url: string;
}

interface OutputData {
  fetchedAt: string;
  daysWindow: number;
  totalPRs: number;
  totalComments: number;
  comments: PrComment[];
  notes: string[];
}

function parseArgs(): Args {
  const args = process.argv.slice(2);
  let days = 7;
  let out = '.tl-telar/temp/pr-comments.json';
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--days') days = Number(args[++i]);
    else if (args[i] === '--out') out = args[++i];
  }
  return { days, out };
}

function classifyReviewer(login: string): PrComment['reviewerType'] {
  const l = login.toLowerCase();
  if (l.includes('coderabbit')) return 'coderabbit';
  if (l.includes('bugbot')) return 'bugbot';
  if (l.includes('greptile')) return 'greptile';
  if (l.includes('copilot')) return 'copilot';
  if (l.endsWith('[bot]') || l.endsWith('-bot')) return 'unknown';
  return 'human';
}

function gh(cmd: string): unknown {
  try {
    return JSON.parse(execSync(`gh ${cmd}`, { encoding: 'utf8', stdio: ['pipe','pipe','pipe'] }));
  } catch (e) {
    return null;
  }
}

function main() {
  const { days, out } = parseArgs();
  const notes: string[] = [];

  // Check auth
  try {
    execSync('gh auth status', { stdio: 'pipe' });
  } catch {
    notes.push('gh auth status failed — no GitHub access. Writing empty output.');
    const empty: OutputData = { fetchedAt: new Date().toISOString(), daysWindow: days, totalPRs: 0, totalComments: 0, comments: [], notes };
    mkdirSync(dirname(out), { recursive: true });
    writeFileSync(out, JSON.stringify(empty, null, 2));
    console.log(`Wrote ${out} (empty; gh auth failed).`);
    process.exit(0);
  }

  const sinceISO = new Date(Date.now() - days * 86400000).toISOString();
  const prs = gh(`pr list --state all --search "updated:>=${sinceISO.split('T')[0]}" --limit 50 --json number,title,updatedAt`);
  if (!Array.isArray(prs) || prs.length === 0) {
    notes.push(`No PRs updated in last ${days} days.`);
  }

  const comments: PrComment[] = [];
  for (const pr of (prs as Array<{ number: number; title: string }> || [])) {
    const issueComments = gh(`api repos/{owner}/{repo}/issues/${pr.number}/comments`) as Array<{
      user: { login: string }; body: string; created_at: string; html_url: string;
    }> | null;
    const reviewComments = gh(`api repos/{owner}/{repo}/pulls/${pr.number}/comments`) as Array<{
      user: { login: string }; body: string; created_at: string; html_url: string;
    }> | null;
    const reviews = gh(`api repos/{owner}/{repo}/pulls/${pr.number}/reviews`) as Array<{
      user: { login: string }; body?: string; submitted_at: string; html_url: string;
    }> | null;

    for (const c of [...(issueComments||[]), ...(reviewComments||[])]) {
      if (!c.body) continue;
      comments.push({
        pr: pr.number,
        prTitle: pr.title,
        author: c.user.login,
        reviewerType: classifyReviewer(c.user.login),
        body: c.body,
        createdAt: c.created_at,
        url: c.html_url,
      });
    }
    for (const r of (reviews||[])) {
      if (!r.body) continue;
      comments.push({
        pr: pr.number,
        prTitle: pr.title,
        author: r.user.login,
        reviewerType: classifyReviewer(r.user.login),
        body: r.body,
        createdAt: r.submitted_at,
        url: r.html_url,
      });
    }
  }

  const output: OutputData = {
    fetchedAt: new Date().toISOString(),
    daysWindow: days,
    totalPRs: Array.isArray(prs) ? prs.length : 0,
    totalComments: comments.length,
    comments,
    notes,
  };

  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, JSON.stringify(output, null, 2));
  console.log(`Wrote ${out} (${comments.length} comments across ${output.totalPRs} PRs).`);
}

main();
