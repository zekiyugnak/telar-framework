#!/usr/bin/env node

/**
 * Generate Codex-compatible distribution files from the Telar source layout.
 *
 * Claude remains the source of truth:
 * - .claude-plugin/
 * - agents/
 * - commands/
 * - skills/
 * - hooks/, rules/, resources/, scripts/, templates/
 *
 * Generated Codex surfaces:
 * - plugins/tl-telar/.codex-plugin/plugin.json
 * - plugins/tl-telar/skills/<name>/SKILL.md
 * - .agents/plugins/marketplace.json
 * - .codex/agents/*.toml
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SOURCE_PLUGIN_JSON = path.join(ROOT, '.claude-plugin', 'plugin.json');
const PLUGIN_NAME = 'tl-telar';
const MARKETPLACE_NAME = 'telar';
const CODEX_PLUGIN_ROOT = path.join(ROOT, 'plugins', PLUGIN_NAME);
const CODEX_PLUGIN_MARKER = path.join(CODEX_PLUGIN_ROOT, '.generated-by-telar-codex');
const CODEX_SKILLS_ROOT = path.join(CODEX_PLUGIN_ROOT, 'skills');
const CODEX_AGENTS_ROOT = path.join(ROOT, '.codex', 'agents');
const CODEX_AGENTS_MARKER = path.join(CODEX_AGENTS_ROOT, '.generated-by-telar-codex');
const MARKETPLACE_JSON = path.join(ROOT, '.agents', 'plugins', 'marketplace.json');

const SUPPORT_DIRS = [
  'agents',
  'commands',
  'hooks',
  'resources',
  'rules',
  'scripts',
  'templates',
];

// Phase 4 curation: orchestration-internal roles that are NOT user-invokable
// specialists. They remain as spawnable `.codex/agents/*.toml` roles but are
// excluded from the installable-plugin `$skill` channel (a plugin user would
// never usefully type `$mobile-orchestrator`).
const SKILL_EXCLUDED_AGENTS = new Set([
  'mobile-orchestrator',
  'mobile-architect-adversarial',
  'mobile-knowledge-curator',
]);

function readText(file) {
  return fs.readFileSync(file, 'utf8');
}

function writeText(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, value);
}

function writeJson(file, value) {
  writeText(file, `${JSON.stringify(value, null, 2)}\n`);
}

function normalizeName(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-{2,}/g, '-');
}

function titleFromName(name) {
  return name
    .split('-')
    .filter(Boolean)
    .map((part) => part[0].toUpperCase() + part.slice(1))
    .join(' ');
}

function stripWrappingQuotes(value) {
  const match = String(value).match(/^(["'])([\s\S]*)\1$/);
  return match ? match[2] : String(value);
}

function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---\n?/);
  if (!match) return {};

  const fields = {};
  const lines = match[1].split('\n');
  let currentKey = null;
  let currentList = null;

  for (const line of lines) {
    const keyMatch = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (keyMatch) {
      if (currentKey && currentList) {
        fields[currentKey] = currentList;
      }

      currentKey = keyMatch[1];
      const raw = keyMatch[2].trim();

      if (raw === '' || raw === '|') {
        currentList = [];
      } else if (raw.startsWith('[') && raw.endsWith(']')) {
        fields[currentKey] = raw
          .slice(1, -1)
          .split(',')
          .map((item) => stripWrappingQuotes(item.trim()))
          .filter(Boolean);
        currentKey = null;
        currentList = null;
      } else {
        fields[currentKey] = stripWrappingQuotes(raw);
        currentKey = null;
        currentList = null;
      }
    } else if (line.match(/^\s+-\s+/)) {
      if (!currentList) currentList = [];
      currentList.push(stripWrappingQuotes(line.replace(/^\s+-\s+/, '').trim()));
    }
  }

  if (currentKey && currentList) {
    fields[currentKey] = currentList;
  }

  return fields;
}

function stripFrontmatter(content) {
  return content.replace(/^---\n[\s\S]*?\n---\n?/, '');
}

function firstHeading(content) {
  const match = content.match(/^#\s+(.+)$/m);
  return match ? match[1].trim() : null;
}

function isUsefulDescription(value) {
  const cleaned = String(value || '').trim();
  if (cleaned.length < 30) return false;
  if (cleaned.endsWith(':')) return false;
  if (/invoked only via/i.test(cleaned)) return false;
  if (/never auto-triggered/i.test(cleaned)) return false;
  return true;
}

function firstParagraph(markdown) {
  const withoutTitle = markdown.replace(/^# .*\n+/, '');
  for (const block of withoutTitle.split(/\n{2,}/)) {
    const cleaned = block
      .trim()
      .replace(/^>\s*/gm, '')
      .replace(/\s+/g, ' ');
    if (
      cleaned &&
      !cleaned.startsWith('#') &&
      !cleaned.startsWith('```') &&
      !cleaned.startsWith('|') &&
      !cleaned.startsWith('- ') &&
      !/^\d+\.\s/.test(cleaned) &&
      isUsefulDescription(cleaned)
    ) {
      return cleaned;
    }
  }
  return '';
}

function descriptionFor(content, frontmatter, name, sourceType) {
  if (
    typeof frontmatter.description === 'string' &&
    isUsefulDescription(frontmatter.description)
  ) {
    return frontmatter.description.trim().replace(/\s+/g, ' ');
  }

  const paragraph = firstParagraph(stripFrontmatter(content));
  if (paragraph) return paragraph.slice(0, 220);

  return `${titleFromName(name)} ${sourceType} from Telar.`;
}

function collectMarkdownFiles(dir, predicate = () => true) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.md') && predicate(entry.name))
    .map((entry) => path.join(dir, entry.name))
    .sort();
}

function collectSkillSources() {
  const sources = [];

  for (const file of collectMarkdownFiles(path.join(ROOT, 'agents'), (name) => !name.startsWith('_') && !SKILL_EXCLUDED_AGENTS.has(name.replace(/\.md$/, '')))) {
    sources.push({ file, sourceType: 'agent' });
  }

  for (const file of collectMarkdownFiles(path.join(ROOT, 'commands'))) {
    sources.push({ file, sourceType: 'command' });
  }

  for (const file of collectMarkdownFiles(path.join(ROOT, 'skills'), (name) => !name.startsWith('_'))) {
    sources.push({ file, sourceType: 'skill' });
  }

  const blueprintsDir = path.join(ROOT, 'skills', 'blueprints');
  for (const file of collectMarkdownFiles(blueprintsDir, (name) => name !== 'README.md' && !name.startsWith('_'))) {
    sources.push({ file, sourceType: 'blueprint', namePrefix: 'blueprint-' });
  }

  const orchestrationDir = path.join(ROOT, 'skills', 'orchestration');
  for (const file of collectMarkdownFiles(orchestrationDir, (name) => !name.startsWith('_'))) {
    sources.push({ file, sourceType: 'orchestration', namePrefix: 'orchestration-' });
  }

  if (fs.existsSync(orchestrationDir)) {
    for (const entry of fs.readdirSync(orchestrationDir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      if (!entry.isDirectory()) continue;
      const skillFile = path.join(orchestrationDir, entry.name, 'SKILL.md');
      if (fs.existsSync(skillFile)) {
        sources.push({
          file: skillFile,
          sourceType: 'orchestration',
          fallbackName: entry.name,
          namePrefix: 'orchestration-',
        });
      }
    }
  }

  return sources;
}

function collectAgentSources() {
  return collectMarkdownFiles(path.join(ROOT, 'agents'), (name) => !name.startsWith('_')).map((file) => ({
    file,
    sourceType: 'agent',
  }));
}

function sourceName(source, frontmatter) {
  const fallback = source.fallbackName || path.basename(source.file, '.md');
  const raw = frontmatter.id || frontmatter.name || fallback;
  const normalizedRaw = normalizeName(raw);
  const prefix = source.namePrefix || '';
  if (prefix && normalizedRaw.startsWith(prefix)) return normalizedRaw;
  return normalizeName(`${prefix}${raw}`);
}

function relativeSource(file) {
  return path.relative(ROOT, file).split(path.sep).join('/');
}

function removeGeneratedDir(dir, marker) {
  if (!fs.existsSync(dir)) return;
  if (!fs.existsSync(marker)) {
    throw new Error(`Refusing to overwrite ${relativeSource(dir)}; generated marker is missing.`);
  }
  fs.rmSync(dir, { recursive: true, force: true });
}

function copySupportDirectories() {
  for (const dir of SUPPORT_DIRS) {
    const from = path.join(ROOT, dir);
    if (!fs.existsSync(from)) continue;
    fs.cpSync(from, path.join(CODEX_PLUGIN_ROOT, dir), { recursive: true });
  }

  // Phase 4: only the orchestration source subtree is referenced (generated command
  // skills do exact `skills/orchestration/<name>` Telar-source lookups). Copying all
  // of skills/ here duplicated ~100 files that nothing references.
  const sourceOrchestration = path.join(ROOT, 'skills', 'orchestration');
  if (fs.existsSync(sourceOrchestration)) {
    fs.cpSync(sourceOrchestration, path.join(CODEX_PLUGIN_ROOT, 'source', 'skills', 'orchestration'), { recursive: true });
  }
}

function copySkillSupportFiles(sourceFile, targetDir) {
  if (path.basename(sourceFile) !== 'SKILL.md') return;

  const sourceDir = path.dirname(sourceFile);
  for (const entry of fs.readdirSync(sourceDir, { withFileTypes: true })) {
    if (entry.name === 'SKILL.md') continue;
    fs.cpSync(path.join(sourceDir, entry.name), path.join(targetDir, entry.name), {
      recursive: true,
    });
  }
}

function buildSkill(source) {
  const content = readText(source.file);
  const frontmatter = parseFrontmatter(content);
  const name = sourceName(source, frontmatter);
  const sourceFile = relativeSource(source.file);
  const description = descriptionFor(content, frontmatter, name, source.sourceType);
  const body = stripFrontmatter(content).trimEnd();
  const compatibilityNotes = codexCompatibilityNotes(source, name);

  const output = [
    '---',
    `name: ${JSON.stringify(name)}`,
    `description: ${JSON.stringify(description)}`,
    `source_type: ${JSON.stringify(source.sourceType)}`,
    `source_file: ${JSON.stringify(sourceFile)}`,
    '---',
    '',
    `# ${name}`,
    '',
    `Migrated from \`${sourceFile}\`.`,
    '',
    '## Codex packaging notes',
    '',
    ...compatibilityNotes,
    '',
    body,
    '',
  ].join('\n');

  return {
    name,
    sourceFile,
    output,
  };
}

function codexCompatibilityNotes(source, skillName) {
  const notes = [
    '- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.',
    '- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.',
    '- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.',
    '- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.',
    '- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.',
  ];

  if (source.sourceType === 'command') {
    notes.push(
      `- In Codex, this skill is the replacement for the Claude slash command \`/tl-telar:${skillName}\`; invoke it as \`$${skillName}\` or through \`@tl-telar\`.`,
      '- Do not require Claude slash-command dispatch or Claude-only environment setup before following the workflow.',
      '- When the original command says to load `skills/orchestration/<name>`, load the generated Codex skill at `../orchestration-<name>/SKILL.md` first. The original source copy also exists under `../../source/skills/orchestration/<name>/SKILL.md` for exact Telar-source references.'
    );
  }

  if (source.sourceType === 'orchestration' || skillName === 'orchestrate') {
    notes.push(
      '- **Codex subagent gate — probe, then use or degrade (fail-closed; never fake).** Claude `Task()` calls map to Codex subagent spawns. Before EVERY multi-reviewer gate: (1) PROBE whether the current Codex surface exposes an agent-spawn tool. (2) If YES → spawn the resolver-selected reviewers as fresh, parallel Codex agent roles; preserve each role, its own rubric, and the freshness rule (no reviewer sees another\'s verdict or a prior iteration), then close each subagent handle before the next iteration so long runs do not exhaust the local subagent thread limit. (3) If NO → emit a literal `DEGRADED: full multi-reviewer gate unavailable on this Codex surface` line and STOP the gate. Recommend re-running on a Claude Code host or a Codex build that exposes subagent spawning. NEVER substitute a single inline self-review for the independent multi-reviewer gate, and never silently continue as if the gate passed.',
      '- **Stack-aware roster (parity with the Claude path).** Derive the reviewer roster from `scripts/tl-telar-reviewer-roster.js` (packaged at this plugin root) against the WU `file_scope` — do NOT hardcode a mobile roster. It returns the domain-correct Security/BackendCorrectness/FrontendUX/Accessibility/Performance reviewers, each with its own rubric path, for mobile, web, backend-data, and rust changes alike.',
      '- Treat Claude `Workflow` tool references as unavailable in Codex unless an explicit equivalent tool is present. Use the documented prose fallback path by default.',
      '- Treat `TL_TELAR_ORCHESTRATED=1` as a workflow mode marker in Codex. Do not require a literal Claude slash command to set it.',
      '- Do not pass scheduler `--isolate` merely because Codex is running. Use `--isolate` only after a concrete Codex worktree isolation and merge-back mechanism has been verified for the run; otherwise keep disjoint file-scope serialization.'
    );
  }

  if (source.sourceType === 'agent') {
    notes.push(
      '- This agent is packaged as a Codex skill for installable plugin portability. Project-scoped Codex custom-agent TOML is also generated under `.codex/agents/` in the source repository.'
    );
  }

  return notes;
}

// Phase 3: map the Claude agent tier (frontmatter `model:`, set in Phase 1) to a
// Codex per-agent `model_reasoning_effort`. Codex custom-agent TOML supports this
// field natively (openai/codex external_agent_config_tests.rs); Codex tiers by
// reasoning effort, not by model swap. opus→high, sonnet→medium, haiku→low.
const TIER_TO_EFFORT = { opus: 'high', sonnet: 'medium', haiku: 'low' };

function buildAgentToml(source) {
  const content = readText(source.file);
  const frontmatter = parseFrontmatter(content);
  const name = sourceName(source, frontmatter);
  const body = stripFrontmatter(content).trimEnd();
  const title = firstHeading(body) || titleFromName(name);
  const description = descriptionFor(content, frontmatter, name, 'agent');
  const effort = TIER_TO_EFFORT[frontmatter.model] || 'medium';
  const sourceFile = relativeSource(source.file);
  const instructions = [
    `You are the Telar ${title}.`,
    '',
    `Source file: ${sourceFile}`,
    '',
    'Follow the source instructions below when this custom Codex agent is explicitly spawned.',
    'Keep output focused on the delegated task and return concise findings or implementation notes to the parent agent.',
    '',
    body,
    '',
  ].join('\n');

  return [
    `name = ${JSON.stringify(name)}`,
    `description = ${JSON.stringify(description)}`,
    `model_reasoning_effort = ${JSON.stringify(effort)}`,
    `developer_instructions = ${JSON.stringify(instructions)}`,
    '',
  ].join('\n');
}

function liveSummary() {
  const countFiles = (dir, predicate) => {
    if (!fs.existsSync(path.join(ROOT, dir))) return 0;
    return fs
      .readdirSync(path.join(ROOT, dir), { withFileTypes: true })
      .filter((entry) => entry.isFile() && predicate(entry.name))
      .length;
  };

  const walk = (dir, predicate) => {
    const abs = path.join(ROOT, dir);
    if (!fs.existsSync(abs)) return 0;
    let count = 0;
    for (const entry of fs.readdirSync(abs, { withFileTypes: true })) {
      const full = path.join(abs, entry.name);
      const rel = path.relative(ROOT, full).split(path.sep).join('/');
      if (entry.isDirectory()) {
        count += walk(rel, predicate);
      } else if (predicate(rel, entry.name)) {
        count += 1;
      }
    }
    return count;
  };

  const agents = countFiles('agents', (name) => name.endsWith('.md') && !name.startsWith('_'));
  const skills = walk('skills', (rel, name) => (
    name.endsWith('.md') &&
    !name.startsWith('_') &&
    !rel.includes('/references/')
  ));
  const commands = countFiles('commands', (name) => name.endsWith('.md'));
  const hooks = countFiles('hooks', (name) => name.endsWith('.sh') && !name.endsWith('.deprecated.sh'));
  const rules = countFiles('rules', (name) => name.endsWith('.md'));
  const scripts = countFiles('scripts', (name) => /\.(js|sh|ts)$/.test(name));

  return `${agents} agents, ${skills} skills, ${commands} commands, ${hooks} hooks, ${rules} rules, ${scripts} scripts`;
}

function buildPluginJson(sourceManifest) {
  return {
    name: PLUGIN_NAME,
    version: sourceManifest.version,
    description: `Cross-platform mobile application development with React Native and Flutter - ${liveSummary()}`,
    author: sourceManifest.author,
    homepage: 'https://zekiyugnak.github.io/telar-framework/',
    repository: 'https://github.com/zekiyugnak/telar-framework',
    license: sourceManifest.license,
    keywords: sourceManifest.keywords,
    skills: './skills/',
    interface: {
      displayName: 'Telar',
      shortDescription: 'Agentic engineering workflows for Codex.',
      longDescription:
        'Telar packages mobile, web, and backend engineering workflows as Codex skills: planning, implementation, review, release, orchestration, and specialist guidance.',
      developerName: sourceManifest.author.name,
      category: 'Developer Tools',
      capabilities: ['Interactive', 'Read', 'Write'],
      defaultPrompt: [
        'Use Telar to plan a mobile app feature.',
        'Review this code with Telar guidance.',
        'Create a release checklist with Telar.',
      ],
      brandColor: '#2563EB',
    },
  };
}

function marketplaceEntry() {
  return {
    name: PLUGIN_NAME,
    source: {
      source: 'local',
      path: `./plugins/${PLUGIN_NAME}`,
    },
    policy: {
      installation: 'AVAILABLE',
      authentication: 'ON_INSTALL',
    },
    category: 'Developer Tools',
  };
}

function buildMarketplace() {
  let payload = {
    name: MARKETPLACE_NAME,
    interface: {
      displayName: 'Telar',
    },
    plugins: [],
  };

  if (fs.existsSync(MARKETPLACE_JSON)) {
    payload = JSON.parse(readText(MARKETPLACE_JSON));
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      throw new Error(`${relativeSource(MARKETPLACE_JSON)} must contain a JSON object.`);
    }
    if (!Array.isArray(payload.plugins)) payload.plugins = [];
    if (!payload.interface || typeof payload.interface !== 'object') {
      payload.interface = { displayName: 'Telar' };
    }
    if (!payload.name) payload.name = MARKETPLACE_NAME;
  }

  const entry = marketplaceEntry();
  const existingIndex = payload.plugins.findIndex((plugin) => plugin && plugin.name === PLUGIN_NAME);
  if (existingIndex >= 0) {
    payload.plugins[existingIndex] = entry;
  } else {
    payload.plugins.push(entry);
  }

  return payload;
}

function generatePlugin(sourceManifest) {
  removeGeneratedDir(CODEX_PLUGIN_ROOT, CODEX_PLUGIN_MARKER);
  fs.mkdirSync(CODEX_SKILLS_ROOT, { recursive: true });
  writeText(CODEX_PLUGIN_MARKER, 'Generated by scripts/generate-codex-plugin.js. Do not edit generated files manually.\n');
  writeJson(path.join(CODEX_PLUGIN_ROOT, '.codex-plugin', 'plugin.json'), buildPluginJson(sourceManifest));
  copySupportDirectories();

  const seen = new Map();
  let count = 0;
  for (const source of collectSkillSources()) {
    const skill = buildSkill(source);
    if (seen.has(skill.name)) {
      throw new Error(
        `Duplicate Codex skill name '${skill.name}' from ${skill.sourceFile} and ${seen.get(skill.name)}`
      );
    }
    seen.set(skill.name, skill.sourceFile);

    const targetDir = path.join(CODEX_SKILLS_ROOT, skill.name);
    writeText(path.join(targetDir, 'SKILL.md'), skill.output);
    copySkillSupportFiles(source.file, targetDir);
    count += 1;
  }

  return count;
}

function generateAgents() {
  removeGeneratedDir(CODEX_AGENTS_ROOT, CODEX_AGENTS_MARKER);
  fs.mkdirSync(CODEX_AGENTS_ROOT, { recursive: true });
  writeText(CODEX_AGENTS_MARKER, 'Generated by scripts/generate-codex-plugin.js. Do not edit generated files manually.\n');

  let count = 0;
  for (const source of collectAgentSources()) {
    const content = readText(source.file);
    const frontmatter = parseFrontmatter(content);
    const name = sourceName(source, frontmatter);
    writeText(path.join(CODEX_AGENTS_ROOT, `${name}.toml`), buildAgentToml(source));
    count += 1;
  }
  return count;
}

function main() {
  const sourceManifest = JSON.parse(readText(SOURCE_PLUGIN_JSON));
  const skillCount = generatePlugin(sourceManifest);
  const agentCount = generateAgents();
  writeJson(MARKETPLACE_JSON, buildMarketplace());

  console.log(`Generated Codex plugin at ${relativeSource(CODEX_PLUGIN_ROOT)}`);
  console.log(`Generated marketplace at ${relativeSource(MARKETPLACE_JSON)}`);
  console.log(`Generated ${skillCount} Codex skills`);
  console.log(`Generated ${agentCount} Codex agents`);
}

main();
