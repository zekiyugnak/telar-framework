---
name: "mock-strategies"
description: "Effective mocking patterns for mobile testing."
source_type: "skill"
source_file: "skills/mock-strategies.md"
---

# mock-strategies

Migrated from `skills/mock-strategies.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Mock Strategies

Effective mocking patterns for mobile testing.

## React Native Module Mocks

```typescript
// __mocks__/react-native-keychain.ts
export const setGenericPassword = jest.fn(() => Promise.resolve(true))
export const getGenericPassword = jest.fn(() =>
  Promise.resolve({ username: 'test', password: 'token' })
)
export const resetGenericPassword = jest.fn(() => Promise.resolve(true))

// __mocks__/@react-native-async-storage/async-storage.ts
const store: Record<string, string> = {}

export default {
  setItem: jest.fn((key, value) => {
    store[key] = value
    return Promise.resolve()
  }),
  getItem: jest.fn((key) => Promise.resolve(store[key] || null)),
  removeItem: jest.fn((key) => {
    delete store[key]
    return Promise.resolve()
  }),
  clear: jest.fn(() => {
    Object.keys(store).forEach(key => delete store[key])
    return Promise.resolve()
  }),
}
```

## API Mocking with MSW

```typescript
import { setupServer } from 'msw/node'
import { http, HttpResponse } from 'msw'

const handlers = [
  http.get('/api/users/:id', ({ params }) => {
    return HttpResponse.json({ id: params.id, name: 'Test User' })
  }),

  http.post('/api/login', async ({ request }) => {
    const body = await request.json()
    if (body.email === 'test@test.com') {
      return HttpResponse.json({ token: 'mock-token' })
    }
    return HttpResponse.json({ error: 'Invalid' }, { status: 401 })
  }),
]

export const server = setupServer(...handlers)

// jest.setup.ts
beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

## Navigation Mocking

```typescript
const mockNavigate = jest.fn()
const mockGoBack = jest.fn()

jest.mock('@react-navigation/native', () => ({
  ...jest.requireActual('@react-navigation/native'),
  useNavigation: () => ({
    navigate: mockNavigate,
    goBack: mockGoBack,
  }),
  useRoute: () => ({
    params: { id: '123' },
  }),
}))
```

## Flutter Mocking

```dart
// Mock with Mocktail
class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService mockAuth;

  setUp(() {
    mockAuth = MockAuthService();
  });

  test('login success', () async {
    when(() => mockAuth.login(any(), any()))
        .thenAnswer((_) async => User(id: '1'));

    final result = await mockAuth.login('email', 'pass');
    expect(result.id, '1');
  });
}
```

## Best Practices

- Keep mocks close to their modules
- Reset mocks between tests
- Use MSW for API mocking over manual fetch mocks
- Mock at the boundary, not deep internals
