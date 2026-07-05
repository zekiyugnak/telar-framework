---
id: mock-strategies
category: skill
tags: [mocking, test-doubles, native-modules, api-mocking]
capabilities:
  - Native module mocking
  - API mocking strategies
  - Test double patterns
  - Mock implementation
useWhen:
  - Mocking native modules
  - Setting up API mocks
  - Creating test doubles
---

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
