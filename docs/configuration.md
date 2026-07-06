# Configuration Reference

Telar Framework'ün orchestrasyon sistemini yöneten iki ayrı config dosyası vardır:

| Dosya | Amaç | Oluşturulma |
|-------|------|-------------|
| `.tl-telar-thresholds.json` | Kalite kapıları, otonom davranış, paralellik | Otomatik (boot probe) veya `/tl-telar:setup-orchestration` |
| `.tl-telar/external-tools.yaml` | Harici AI adapter (Codex/Gemini) ve çapraz-model review | `/tl-telar:setup-orchestration` |

Her iki dosya da consumer projenizin kökünde (veya `.tl-telar/` altında) yer alır ve `.gitignore`'a eklenir — bu sayede commit geçmişini kirletmez.

---

## Oturum modeli ve maliyet (önemli)

`/tl-telar:orchestrate` **ana oturumda** çalışan bir orkestratördür. Spawn edilen agent'lar kendi model tier'larını (`agents/*.md` frontmatter `model:`) ve reviewer'lar sabit Opus kullanır — ama **orkestratörün kendi turları senin `/model` seçimini** kullanır ve bunu agent frontmatter'ı **override edemez**. Uzun bir orchestrate koşusunu en pahalı modelde (ör. Fable) çalıştırmak maliyetin büyük kısmını oradan üretir. **Öneri:** `orchestrate`'i **Sonnet veya Opus** oturumunda çalıştır; en yüksek-maliyet modeli yalnızca gerçekten gerektiğinde seç.

## `.tl-telar-thresholds.json`

Orchestratörün **Phase 2 VALIDATE** aşamasında okuduğu ana config dosyasıdır. Her gate komutu `*_strict` bayrağına göre "bloklar veya sadece loglar" kararını verir.

### Yaşam döngüsü

```
/tl-telar:orchestrate (ilk çalışma)
  → dosya yoksa "safe no-op" default yazılır (tüm thresholdlar devre dışı)
  → Kullanıcıya "/tl-telar:setup-orchestration çalıştır" mesajı verilir

/tl-telar:setup-orchestration
  → Framework algılar (Flutter / RN / Expo / Vitest)
  → Framework-aware değerlerle dosyayı yeniden yazar
  → Kullanıcı özelleştirmişse dokunmaz (marker kontrolü yapar)
```

### Tam şema (framework-aware defaults)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "coverage": {
    "lines": 80,
    "branches": 75,
    "functions": 80,
    "statements": 80
  },
  "performance": {
    "min_fps": 60,
    "max_cold_start_ms": 3000
  },
  "size": {
    "max_apk_mb": 50,
    "max_ipa_mb": 60
  },
  "accessibility": {
    "required_audit_pass": false
  },
  "autonomy": {
    "cycle": "interactive"
  },
  "execution": {
    "max_parallel_wus": 3
  },
  "enforcement": {
    "coverage_command": "npx jest --coverage",
    "coverage_strict": true,
    "perf_command": "bash scripts/perf-smoke.sh",
    "perf_strict": false,
    "size_command": "bash scripts/size-check.sh",
    "size_strict": false,
    "a11y_command": "echo 'a11y audit not configured' && exit 0",
    "a11y_strict": false,
    "blockPRCreation": true,
    "blockTaskCompletion": true,
    "self_reflect_per_wu": false
  }
}
```

---

### `coverage.*` — Coverage eşik değerleri

Orchestratörün Phase 2'de `coverage_command`'ı çalıştırdıktan sonra **raporlanan değerleri** bu eşiklerle karşılaştırır. `coverage_strict: true` olduğunda herhangi bir eşiğin altına düşülmesi COMMIT'i bloklar.

| Alan | Tip | Default (framework-aware) | Açıklama |
|------|-----|--------------------------|---------|
| `coverage.lines` | number (0–100) | `80` | Satır coverage yüzdesi minimum eşiği |
| `coverage.branches` | number (0–100) | `75` | Dal coverage eşiği |
| `coverage.functions` | number (0–100) | `80` | Fonksiyon coverage eşiği |
| `coverage.statements` | number (0–100) | `80` | Statement coverage eşiği |

**Safe default:** `{ "lines": 0, "branches": 0, "functions": 0, "statements": 0 }` — tüm coverage kontrollerini devre dışı bırakır.

**Nasıl çalışır:** `coverage_command` çıktısını orchestratör parse eder ve bu eşiklerle karşılaştırır. Test runner (jest, vitest, flutter test) zaten eşik kontrolü yapıyorsa (örn. `jest --coverage --coverageThreshold`) bu alanlar ek bir doğrulama katmanıdır.

---

### `performance.*` — Performans eşik değerleri

`perf_command`'ın sonuçlarını yorumlamak için kullanılır. Komut bu değerlere göre çıkış kodu döndüreceği şekilde yapılandırılmalıdır.

| Alan | Tip | Default | Açıklama |
|------|-----|---------|---------|
| `performance.min_fps` | number | `60` | Minimum kabul edilebilir FPS |
| `performance.max_cold_start_ms` | number | `3000` | Maksimum soğuk başlatma süresi (ms) |

**Safe default:** `{ "min_fps": 0, "max_cold_start_ms": 999999 }` — pratikte her değeri geçirir.

**Önemli:** `perf_strict: false` olduğu sürece bu değerler sadece referans içindir, COMMIT'i bloklamaz. `scripts/perf-smoke.sh` default olarak stub'dır — gerçek FPS ölçümü için replace etmeniz gerekir.

---

### `size.*` — Bundle boyut limitleri

`size_command`'ın raporladığı APK/IPA boyutlarını bu değerlerle karşılaştırır.

| Alan | Tip | Default | Açıklama |
|------|-----|---------|---------|
| `size.max_apk_mb` | number | `50` | Maksimum APK boyutu (MB) |
| `size.max_ipa_mb` | number | `60` | Maksimum IPA boyutu (MB) |

**Safe default:** `{ "max_apk_mb": 999, "max_ipa_mb": 999 }` — pratikte her boyutu geçirir.

**Not:** `scripts/size-check.sh` default olarak stub'dır. Build artifact'ının mevcut olmasını gerektirir — CI ortamında ya da build sonrası çalıştırılmalıdır.

---

### `accessibility.*` — Erişilebilirlik eşiği

| Alan | Tip | Default | Açıklama |
|------|-----|---------|---------|
| `accessibility.required_audit_pass` | boolean | `false` | `true` yapıldığında a11y audit başarısız olursa COMMIT bloklanır |

Bu alan `enforcement.a11y_strict` ile birlikte çalışır: ikisi de `true` olduğunda a11y gate tamamen blocking hale gelir.

---

### `autonomy.cycle` — Orchestratörün insan müdahalesi modu

| Değer | Davranış |
|-------|---------|
| `"interactive"` (default) | WU `checkpoint: true` olduğunda ve self-reflect onayında duraklar. Geriye dönük uyumlu. |
| `"unattended"` | Tek bir insan kapısı: **Step 5 plan-hazırlık onayı**. Burada tüm UI ASCII taslakları, kararlar ve secret'lar toplanır. Sonrasında tüm WU döngüsü PR-ready'e kadar durmadan çalışır. Checkpoint'ler silinmez — plan-hazırlık aşamasında önceden çözülür. |

**Ne zaman `unattended` kullanılır:** CI benzeri otonom çalışmalar için. Yine de güvenlidir çünkü `ben yapacagim` politikası gereği orchestratör hiçbir zaman commit veya push yapmaz.

**Nasıl değiştirilir:**
```json
{ "autonomy": { "cycle": "unattended" } }
```

---

### `execution.max_parallel_wus` — Eş zamanlı Work Unit sayısı

| Alan | Tip | Default | Açıklama |
|------|-----|---------|---------|
| `execution.max_parallel_wus` | integer | `3` | Aynı anda çalışabilecek maksimum WU sayısı |

**Nasıl çalışır:** `scripts/tl-telar-wu-scheduler.js` bu değeri okur. Her WU dispatch noktasında şu koşullar sağlandığında WU çalıştırılır:
1. Bağımlılıkları (`deps`) COMPLETE durumunda
2. `file_scope`'u, çalışan tüm WU'ların `file_scope`'larıyla kesişmiyor
3. Toplam aktif WU sayısı bu limitin altında

**Neden 3:** Anthropic'in önerdiği 3–5 subagent aralığının alt sınırı. Paralel agent çalışması ~15x chat token tüketir. Çok sayıda küçük ve bağımsız WU için artırılabilir.

**Güvenli geri dönüş:** Değer eksik veya geçersizse `3` kullanılır.

---

### `enforcement.*` — Gate komutları ve blocking davranışı

Bu bölüm orchestratörün Phase 2 VALIDATE'de tam olarak ne çalıştıracağını ve sonucun blocking mi advisory mi olacağını belirler.

#### Gate davranış matrisi

| Gate | Komutu | Strict flag | Default strict | Blocking olduğunda |
|------|--------|------------|---------------|-------------------|
| Coverage | `coverage_command` | `coverage_strict` | `false` (safe) / `true` (framework-aware) | COMMIT bloklanır |
| Perf smoke | `perf_command` | `perf_strict` | `false` | Sadece log |
| Bundle size | `size_command` | `size_strict` | `false` | Sadece log |
| Accessibility | `a11y_command` | `a11y_strict` | `false` | Sadece log |

**Tier 1 — Her zaman bloklayanlar (config bağımsız):**
- `tsc` / `dart analyze` hataları
- `eslint` hataları
- Test exit kodu ≠ 0
- `file_scope` ihlali (WU kapsamı dışına çıkma)

**Tier 2 — Opt-in blocking (bu gate'ler):**  
`*_strict: true` yapılana kadar advisory olarak çalışır.

#### Komut güvenlik modeli

Orchestratör komutları `eval` veya `sh -c` ile değil, argv array olarak çalıştırır. Bu nedenle komutlar aşağıdaki biçimlerden biri olmalıdır:

| Biçim | Örnek | İzin verilir |
|-------|-------|-------------|
| Safe no-op | `echo 'msg' && exit 0` | ✓ |
| Plugin/proje scripti | `bash scripts/perf-smoke.sh` | ✓ |
| Package runner | `npx jest --coverage` | ✓ |
| Package runner | `flutter test --coverage` | ✓ |
| Diğer | `sh -c "..."`, `eval`, pipe, redirect | ✗ — REFUSE |

Güvenlik kuralı ihlali: `coverage_command` reddedilir ve gate FAIL sayılır. `*_strict: false` ise log'a yazılır ama bloklamaz.

#### `enforcement.coverage_command`

| Alan | Tip | Açıklama |
|------|-----|---------|
| `coverage_command` | string | Coverage çalıştırma komutu |

Framework tespitine göre otomatik ayarlanan değerler:

| Framework | Otomatik değer |
|-----------|---------------|
| Flutter | `flutter test --coverage` |
| RN/Expo + jest | `npx jest --coverage` |
| RN/Expo + vitest | `npx vitest run --coverage` |
| Test runner yok | `echo 'no test runner detected' && exit 0` |
| Bilinmeyen framework | `echo 'no framework detected' && exit 0` |

#### `enforcement.coverage_strict`

`true` → coverage gate başarısız olursa COMMIT bloklanır, 3 deneme sonrası kullanıcıya eskalasyon.  
`false` → çalıştırılır, sonuç loglanır, bloklamaz.

Framework-aware setup otomatik olarak `true` yazar (test runner algılandığında).

#### `enforcement.perf_command`

Coverage gate'den sonra çalıştırılır. Default: `bash scripts/perf-smoke.sh`.

`scripts/perf-smoke.sh` proje kurulumunda consumer projenizin `scripts/` klasörüne kopyalanır. Default stub her zaman `exit 0` döner. Gerçek ölçüm için replace edin:

```bash
# scripts/perf-smoke.sh örneği (gerçek ölçüm)
#!/usr/bin/env bash
FPS=$(measure_fps_somehow)
if (( FPS < 60 )); then echo "FPS too low: $FPS" && exit 1; fi
```

`perf_strict: true` yaptıktan sonra bu scripti gerçek ölçümle doldurun.

#### `enforcement.size_command`

Default: `bash scripts/size-check.sh`. Consumer projenizin `scripts/` klasörüne kopyalanır.

Build artifact'ı (APK/IPA) mevcut olmalıdır. CI/CD pipeline'da build sonrası çalıştırmak için uygundur.

#### `enforcement.a11y_command`

Default: `echo 'a11y audit not configured' && exit 0`.

Önerilen araçlar: `axe-core`, `react-native-accessibility-engine`, Flutter'da `semantics` testi.

```json
{
  "enforcement": {
    "a11y_command": "npx axe-cli --disable color-contrast",
    "a11y_strict": true
  }
}
```

#### `enforcement.blockPRCreation` ve `enforcement.blockTaskCompletion`

| Alan | Tip | Safe default | Framework-aware default |
|------|-----|-------------|------------------------|
| `blockPRCreation` | boolean | `false` | `true` |
| `blockTaskCompletion` | boolean | `false` | `true` |

Bu alanlar orchestratörün gate başarısız olduğunda PR oluşturma ve task completion'ı engellemesini sinyalleyen **intent flag**'leridir. Framework-aware setup'ta her ikisi `true` yazılır.

**Not:** Bu alanlar şu an ağırlıklı olarak signal değeridir. Orchestratör zaten gate başarısız olduğunda COMMIT-READY sinyali vermiyor. CI/CD sistemleri bu değerleri okuyabilir.

#### `enforcement.self_reflect_per_wu`

| Değer | Davranış |
|-------|---------|
| `false` (default) | Self-reflect tüm WU döngüsü bittikten sonra bir kez çalışır (pre-PR). |
| `true` | Her WU'nun Phase 4 COMMIT aşamasında self-reflect çalışır. |

**Ne zaman `true` kullanılır:** Çok sayıda bağımsız WU'da öğrenmelerin sürekli yakalanması istendiğinde. Her WU'da bir kullanıcı onay adımı ekler — `unattended` modu ile birlikte dikkatli kullanın.

**Default mantığı:** Multi-WU planlarında bir kez (pre-PR) yakalamak yeterlidir. Single-WU çalışmalarında ise Phase 4'te otomatik tetiklenir (bu flag'den bağımsız).

---

## `.tl-telar/external-tools.yaml`

Harici AI adapter'larını (Codex, Gemini) ve çapraz-model review özelliğini yapılandırır. Bu özellik **Phase β** durumundadır — default olarak `enabled: false`'dur.

### Dosya konumu

`.tl-telar/external-tools.yaml` — `.gitignore`'da. Yalnızca `/tl-telar:setup-orchestration` ile oluşturulur.

### Adapters

```yaml
adapters:
  codex:
    enabled: false
    model: ""
    reasoning_effort: ""
    timeout_seconds: 300
    auth_env_var: "OPENAI_API_KEY"
    sandbox: "none"
  gemini:
    enabled: false
    model: "pro"
    timeout_seconds: 300
    auth_env_var: "GEMINI_API_KEY"
    sandbox: "none"
```

| Alan | Tip | Açıklama |
|------|-----|---------|
| `enabled` | boolean | `true` yapıldığında adapter aktifleşir. Öncesinde CLI kurulu ve `auth_env_var` set edilmiş olmalıdır. |
| `model` | string | Boş bırakılırsa adapter'ın kendi default modeli kullanılır (Codex: `~/.codex/config.toml`). Örn. `"gpt-5.3-codex"` |
| `reasoning_effort` | string (codex only) | `minimal \| low \| medium \| high`. Boş = codex config default. |
| `timeout_seconds` | number | Adapter invocation timeout. |
| `auth_env_var` | string | Dispatcher'ın auth için okuduğu env var adı. |
| `sandbox` | string | `"none"` — sandbox izolasyonu yok. |

**Aktivasyon adımları (Codex):**
```bash
npm install -g codex          # CLI kurulumu
export OPENAI_API_KEY="sk-..."
# .tl-telar/external-tools.yaml içinde:
# adapters.codex.enabled: true
```

> **Codex plugin ile Codex adapter farklıdır.** `codex plugin marketplace add zekiyugnak/telar-framework --ref develop` ve `codex plugin add tl-telar@telar` Telar'ı Codex içinde kullanılabilir yapar. Buradaki `adapters.codex.enabled: true` ise Telar'ın orchestrated mode sırasında bazı işleri harici Codex CLI'a delege etmesi içindir ve default olarak kapalıdır.

### Routing

```yaml
routing:
  default_implementer: "cheapest-available"
  escalation_order: ["codex", "gemini", "claude"]
  health_recheck_every_n_tasks: 10
```

| Alan | Tip | Açıklama |
|------|-----|---------|
| `default_implementer` | string | `cheapest-available` (en ucuz aktif adapter), `round-robin`, `claude`, veya `codex`/`gemini` |
| `escalation_order` | array | Birincil adapter başarısız olduğunda sırasıyla denenir |
| `health_recheck_every_n_tasks` | number | Her N görevde bir health check yenilenir |

### Budget

```yaml
budget:
  per_task_usd: 1.00
  per_session_usd: 10.00
  ledger_file: ".tl-telar/context/external-tools-budget.jsonl"
  circuit_breaker_message: "Per-task budget exceeded — switching to Claude."
```

| Alan | Tip | Açıklama |
|------|-----|---------|
| `per_task_usd` | number | Tek bir adapter invocation için maksimum USD maliyeti. Aşılırsa Claude'a fallback. |
| `per_session_usd` | number | Session başına toplam adapter harcaması limiti. |
| `ledger_file` | string | Her adapter invocation'ı JSONL formatında kaydeder. Audit ve `budget-status` için kullanılır. |
| `circuit_breaker_message` | string | Budget aşıldığında terminale yazılacak mesaj. |

**Budget durumu kontrol:**
```bash
bash scripts/tl-telar-external-tools.sh budget-status
```

### Cross-model review (Phase γ)

```yaml
cross_model_review:
  enabled: false
  on_unavailable: "block"
  matrix:
    codex: ["gemini", "claude"]
    gemini: ["codex", "claude"]
    claude: ["codex", "gemini"]
```

Orchestrated mode'da her WU için **iki bağımsız review** çalışır:
- **Review 1 (her zaman):** 2–4 Claude Task() reviewer (Phase 3 sidecar)
- **Review 2 (cross-model, `enabled: true` olduğunda):** Yazardan ve Claude'dan farklı bir model

| Alan | Tip | Açıklama |
|------|-----|---------|
| `enabled` | boolean | `true` → Review 2 ZORUNLU hale gelir (her WU'da) |
| `on_unavailable` | string | `"block"` (default): Review 2 çalışmazsa COMMIT bloklanır; `"warn_and_proceed"`: sadece log, devam eder |
| `matrix` | object | "Yazan model → onu review edebilecek modeller" kuralı. Yazar kendi kodunu review edemez. |

**Matris kuralı:** `claude` ile yazılan WU → Review 2 için `codex` veya `gemini`. Review 2 asla Claude olamaz (Review 1 zaten Claude'dur).

**Şu anki durum (Phase β):** `cross_model_review` YAML'da mevcuttur ancak Phase 3'e bağlanmamıştır. Phase γ (sub-spec 8) bunu aktifleştirecek.

### CC features (Claude Code yerel yetenekleri)

```yaml
cc_features:
  dynamic_workflows:
    enabled: true
    on_unavailable: "warn_and_proceed"
  worktree_isolation:
    enabled: true
    on_unavailable: "warn_and_proceed"
```

Daha yeni Claude Code yerel yeteneklerinin **opt-in** adaptasyonu. `adapters` bloğuyla aynı deseni kullanır — ama kritik bir farkla: `enabled` **niyet** demek, **yetenek** değil. Bir özellik yalnızca `enabled: true` **VE** runtime capability probe doğruladığında aktifleşir; aksi halde orchestrator mevcut-davranış yoluna **fail-closed** düşer, tek satır uyarı basar ve yokluğunda **asla hard-fail etmez**.

Bu yüzden varsayılanlar `true`'dur: her yol eski Claude Code'da zarifçe eski davranışa döndüğü için, yeteneği olan session'larda hızlı yolu tercih etmek güvenlidir.

| Alan | Tip | Açıklama |
|------|-----|---------|
| `dynamic_workflows.enabled` | boolean | `true` (default) → review kapıları (önce plan-review) prose Task() fan-out yerine deterministik bir **Workflow** scripti ile koşar (`Workflow` aracı mevcutsa). Her iki yol da birebir aynı aggregated verdict objesini döndürür; downstream wiring hangisinin koştuğunu bilmez. |
| `worktree_isolation.enabled` | boolean | `true` (default) → her paralel WU kendi git worktree'sinde koşar; böylece **çakışan** `file_scope`'a sahip WU'lar eşzamanlı çalışabilir (ayrık-scope kısıtı gevşer). Fallback: bugünkü ayrık-scope serileştirmesi (yavaş ama asla yanlış değil). |
| `<feature>.on_unavailable` | string | Yetenek doğrulanamadığında: `"warn_and_proceed"` (default) mevcut-davranış fallback'ini LOUDLY loglayarak koşar; `"block"` preflight'ta durur (özellik takımın için zorunluysa). |

**Capability probe sinyalleri:**
- `dynamic_workflows` → top-level session'da `Workflow` aracının mevcut olması (binary tool-presence).
- `worktree_isolation` → `isolation: worktree` desteğinin **pozitif doğrulanması**. Eski Claude Code bu frontmatter'ı **sessizce yok sayabileceği** için, probe pozitif doğrulayamazsa scheduler `enabled: true` olsa bile ayrık kısıtı korur — bayrağa değil, probe'a güvenir.

**Şu anki durum:** `dynamic_workflows` plan-review kapısı için bağlanmıştır (`skills/orchestration/plan-review-gate/workflow/plan-review.mjs`). `worktree_isolation` WU execution döngüsüne bağlanmıştır: orchestrator Step 5b fail-closed capability preflight'ı yapar, aktifse scheduler'a `--isolate` geçer (çakışan-scope WU'lar eşzamanlı) ve her WU'nun `wu-<id>` branch'ini `git merge --squash` ile geri birleştirir (staged, commit'siz — `ben yapacagim` korunur); merge conflict mevcut retry/escalate döngüsüne yönlenir.

---

## Hardcode (config ile değiştirilemeyen) değerler

Bunlar kaynak kodda sabit olup `.tl-telar-thresholds.json` veya `external-tools.yaml` ile ayarlanamaz:

| Özellik | Sabit değer | Kaynak |
|---------|------------|--------|
| Plan review reviewer sayısı | 3 (paralel) | `skills/orchestration/plan-review-gate/SKILL.md` |
| Design review reviewer sayısı | 6 (paralel: PM, Architect, Designer, Security-Design, CTO, Mobile-Platform) | `skills/orchestration/design-review-gate/SKILL.md` |
| Phase 3 adversarial reviewer (her zaman) | 2 (Code + Mobile Security) | `skills/orchestration/adversarial-code-review.md` |
| Phase 3 adversarial reviewer (conditional) | +2 (A11y, Perf — file_scope'a göre) | Aynı skill |
| Gate başarısız olduğunda maksimum retry | 3 | `skills/orchestration/orchestrated-execution/SKILL.md` |
| 3 retry sonrası | Kullanıcıya eskalasyon | Aynı skill |
| WU checkpoint (unattended modda) | Plan-readiness'a çekilir, mid-cycle pause yok | `agents/orchestrator.md` |
| Commit ve push | Asla otomatik değil — `ben yapacagim` politikası | `commands/orchestrate.md` |

---

## Otomatik yönetilen state dosyaları

Bu dosyalar orchestratör tarafından oluşturulur ve güncellenir. Manuel düzenleme yapılmamalıdır:

| Dosya | İçerik | Yaşam döngüsü |
|-------|--------|--------------|
| `.tl-telar/project-profile.json` | Setup sentinel (framework, timestamp) | `/tl-telar:setup-orchestration` yazar; silmek setup'ı sıfırlar |
| `.tl-telar/plans/active-plan.md` | Aktif plandaki WU listesi ve statuslar | Orchestratör her WU sonrası günceller |
| `.tl-telar/context/execution-state.md` | Her phase geçişi, gate sonuçları, review verdicts | Her phase'de güncellenir |
| `.tl-telar/context/project-context.md` | Tamamlanan WU'lar ve ortaya çıkan pattern'lar | Her WU Phase 4'te güncellenir |
| `.tl-telar/context/external-tools-budget.jsonl` | Adapter invocation ledger | Her adapter çağrısında append edilir |
| `.tl-telar/context/wu-*-baseline.tsv` | Her WU başındaki dosya durumu (path + hash) | Phase 1 yazar, Phase 4 siler |
| `.tl-telar/context/wu-*-changes.txt` | WU'ya atfedilen değişiklikler | Phase 2 yazar, Phase 4 siler |
| `.tl-telar/logs/wu-*-validate.log` | Gate komutlarının stdout/stderr çıktısı | Phase 2 yazar; hatada `execution-state.md`'ye pointer |
| `.tl-telar/knowledge/*.jsonl` | KB kaydı (self-reflect çıktıları) | `/tl-telar:self-reflect` yazar |

---

## Hızlı başlangıç rehberi

### 1. İlk kurulum

```bash
/tl-telar:setup-orchestration
```

Framework otomatik algılanır, coverage komutu ayarlanır, tüm script stub'ları projenize kopyalanır.

### 2. Coverage'ı aktifleştirmek

`/tl-telar:setup-orchestration` zaten `coverage_strict: true` yazar (test runner algılandığında). Manuel olarak:

```json
{
  "enforcement": {
    "coverage_command": "npx jest --coverage",
    "coverage_strict": true
  },
  "coverage": { "lines": 80, "branches": 75, "functions": 80, "statements": 80 }
}
```

### 3. Performans ve boyut kontrolü aktifleştirmek

```bash
# Önce scripts/perf-smoke.sh ve scripts/size-check.sh'ı gerçek ölçümle doldurun
```

```json
{
  "enforcement": {
    "perf_strict": true,
    "size_strict": true
  },
  "performance": { "min_fps": 60, "max_cold_start_ms": 3000 },
  "size": { "max_apk_mb": 50, "max_ipa_mb": 60 }
}
```

### 4. Tam otonom mod

```json
{
  "autonomy": { "cycle": "unattended" },
  "execution": { "max_parallel_wus": 5 }
}
```

### 5. Harici AI review'u aktifleştirmek

```bash
npm install -g codex
export OPENAI_API_KEY="sk-..."
```

`.tl-telar/external-tools.yaml`:
```yaml
adapters:
  codex:
    enabled: true
cross_model_review:
  enabled: true
  on_unavailable: "warn_and_proceed"
```

---

## Sık sorulan sorular

**S: Coverage'ın threshold'u nasıl değiştiririm?**  
`coverage.*` alanlarını düzenleyin ve `enforcement.coverage_strict: true` yapın.

**S: "coverage not configured" mesajı görüyorum.**  
Safe-default dosya var demektir. `/tl-telar:setup-orchestration` çalıştırın.

**S: WU'lar çok yavaş çalışıyor.**  
`execution.max_parallel_wus`'u artırın (ör. `5`). Her paralel WU ~15x token tüketir.

**S: Her feature sonrası self-reflect çalışmasını istemiyorum.**  
`enforcement.self_reflect_per_wu: false` (default) olduğunda self-reflect tüm WU döngüsü bittikten sonra bir kez çalışır. Tamamen kapatmak için self-reflect skill'ini okuyun — şu an kapatma flag'i yoktur.

**S: `blockPRCreation: true` PR oluşturmamı engelliyor mu?**  
Hayır — bu flag orchestratörün davranışını sinyalleyen bir intent değeridir. Orchestratör zaten hiçbir zaman PR oluşturmaz (`ben yapacagim` politikası).

**S: Review sayısını azaltabilir miyim?**  
Hayır — plan review (3 reviewer), design review (6 reviewer) ve Phase 3 adversarial review (2–4 reviewer) hardcode'dur. Review sayısı config ile değiştirilemez.
