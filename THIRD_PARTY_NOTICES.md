# Third-Party Notices

This project incorporates material from the projects listed below. The original
copyright notices and the licenses under which Zeki Yugnak received such material
are set out here. This file is the authoritative attribution for the project; it
is reproduced to satisfy the conditions of the licenses below.

---

## 1. metaswarm — REQUIRED ATTRIBUTION

Portions of the orchestration "external-tools" layer are adapted from the
**metaswarm** project (https://github.com/dsifry/metaswarm), used under the MIT
License.

Files in this repository that are adapted from metaswarm:

- `skills/orchestration/external-tools/adapters/_common.sh`
- `skills/orchestration/external-tools/adapters/codex.sh`
- `skills/orchestration/external-tools/adapters/gemini.sh`
- `scripts/estimate-cost.sh`
- `scripts/tl-telar-fetch-pr-comments.ts`

```
MIT License

Copyright (c) 2026 Dave Sifry

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 2. karpathy-guidelines — REQUIRED ATTRIBUTION

`rules/simplicity-first.md` adapts one principle from the **karpathy-guidelines**
plugin (https://github.com/forrestchang/andrej-karpathy-skills) by forrestchang,
used under the MIT License. (Derived from Andrej Karpathy's public observations
on LLM coding pitfalls.)

```
MIT License

Copyright (c) forrestchang (andrej-karpathy-skills)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 3. superpowers — runtime dependency (acknowledgement)

Some orchestration workflows can interoperate with the **superpowers** plugin
(https://github.com/anthropics/claude-code, claude-plugins-official), © 2025
Jesse Vincent, MIT License. superpowers is **not redistributed** as part of this
project; it is referenced only as an optional runtime dependency. Acknowledged
with thanks.

---

## 4. dimensional-drawing — REQUIRED ATTRIBUTION

Two skills are vendored (pinned copy, upstream commit
`5c457437c8c83524308aad3b7443e81adcc13153`) from the **dimensional-drawing**
project (https://github.com/enesozturk/dimensional-drawing), used under the MIT
License. Local modifications: Telar adapter frontmatter on both `SKILL.md`
files, one adapter note in the motion skill, and one declared path edit (the
`cd` line in `adapters/headless/README.md`); see `third-party/SOURCES.md`. The license is also at
`skills/third-party/dimensional-drawing/LICENSE`.

Files in this repository that come from dimensional-drawing:

- `skills/third-party/dimensional-drawing/dimensional-drawing/SKILL.md`
- `skills/third-party/dimensional-drawing/dimensional-drawing/examples/card-sheet.html`
- `skills/third-party/dimensional-drawing/dimensional-drawing/examples/dialog-sheet.html`
- `skills/third-party/dimensional-drawing/dimensional-drawing-motion/SKILL.md`
- `skills/third-party/dimensional-drawing/dimensional-drawing-motion/adapters/claude-motion.md`
- `skills/third-party/dimensional-drawing/dimensional-drawing-motion/adapters/headless/README.md`
- `skills/third-party/dimensional-drawing/dimensional-drawing-motion/adapters/headless/package.json`
- `skills/third-party/dimensional-drawing/dimensional-drawing-motion/adapters/headless/player.html`
- `skills/third-party/dimensional-drawing/dimensional-drawing-motion/adapters/headless/render.mjs`
- `skills/third-party/dimensional-drawing/dimensional-drawing-motion/templates/base.css`
- `skills/third-party/dimensional-drawing/dimensional-drawing-motion/templates/scene-dialog.js`

```
MIT License

Copyright (c) 2026 Enes Ozturk

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 5. design.how — REQUIRED ATTRIBUTION

Five workflow skills are vendored (pinned copy, upstream commit
`419fa5af1721eebfab9e0062a630de36ffd0b342`) from the **design.how** project
(https://github.com/arla6ka/design.how), used under the MIT License. Local modifications: Telar adapter frontmatter on all five `SKILL.md`
files and adapter notes on two of them. The upstream `migrate-design-system`
skill is not shipped; see `third-party/SOURCES.md`.
The license is also at `skills/third-party/design.how/LICENSE`.

Files in this repository that come from design.how (all under
`skills/third-party/design.how/`):

- `design-system-boss/SKILL.md`, `design-system-boss/playbooks/build.md`, `component.md`, `migrate.md`, `review.md`
- `build-design-system/SKILL.md`
- `build-design-system/references/components.md`, `glossary.md`, `taste.md`, `tokens.md`, `traps.md`
- `build-design-system/scripts/capture-guard.mjs`, `capture.mjs`, `check-system.mjs`, `find-chromium.mjs`, `oklch.mjs`, `pixdiff.mjs`
- `token-mapping/SKILL.md`, `token-mapping/references/mapping-rules.md`
- `component-docs/SKILL.md`, `component-docs/references/doc-format.md`
- `ui-review/SKILL.md`, `ui-review/references/criteria.md`

```
MIT License

Copyright (c) 2026 Arlan Marat

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 6. Reference-only design tools — acknowledgement

The following MIT-licensed projects are **documented but not redistributed** by
Telar (`third-party/README.md`); users install them themselves:

- **brand-identity-skill** (https://github.com/fatihaydost/brand-identity-skill),
  © 2026 Fatih Aydost, MIT License. It ships its own third-party notices.
- **oil-ui** (https://github.com/oil-oil/oil-ui), © 2026 oil-oil, MIT License.
  Not shipped or routed to by Telar; see the warning in `third-party/README.md`.
- **awwwards-mcp** (https://github.com/INSANE0777/Awwwards-mcp), © 2026 Afjal,
  MIT License. Independent project, not affiliated with Awwwards.
