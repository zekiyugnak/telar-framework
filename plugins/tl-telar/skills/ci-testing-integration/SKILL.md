---
name: "ci-testing-integration"
description: "Configuring tests in CI/CD pipelines."
source_type: "skill"
source_file: "skills/ci-testing-integration.md"
---

# ci-testing-integration

Migrated from `skills/ci-testing-integration.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# CI Testing Integration

Configuring tests in CI/CD pipelines.

## GitHub Actions - React Native

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'yarn'

      - name: Install dependencies
        run: yarn install --frozen-lockfile

      - name: Run tests
        run: yarn test --coverage --ci --reporters=default --reporters=jest-junit

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/lcov.info

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: junit.xml
```

## Parallel Test Execution

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        shard: [1, 2, 3, 4]
    steps:
      - name: Run tests (shard ${{ matrix.shard }})
        run: |
          yarn test --shard=${{ matrix.shard }}/4 --ci
```

## Flutter CI Testing

```yaml
name: Flutter Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze

      - name: Run tests
        run: flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: coverage/lcov.info
```

## Jest Configuration for CI

```typescript
// jest.config.js
module.exports = {
  reporters: [
    'default',
    ['jest-junit', {
      outputDirectory: './reports',
      outputName: 'junit.xml',
    }],
  ],
  collectCoverage: true,
  coverageDirectory: './coverage',
  coverageReporters: ['lcov', 'text', 'text-summary'],
  testResultsProcessor: 'jest-sonar-reporter',
}
```

## Test Caching

```yaml
- name: Cache Jest
  uses: actions/cache@v4
  with:
    path: /tmp/jest_rs
    key: jest-${{ runner.os }}-${{ hashFiles('**/yarn.lock') }}

# jest.config.js
module.exports = {
  cacheDirectory: '/tmp/jest_rs',
}
```

## Best Practices

- Run tests on every PR
- Use parallel execution for speed
- Upload coverage to tracking service
- Cache dependencies and test results
