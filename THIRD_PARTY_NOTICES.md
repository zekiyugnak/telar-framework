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
