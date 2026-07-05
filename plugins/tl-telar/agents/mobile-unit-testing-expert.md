---
id: mobile-unit-testing-expert
category: agent
tags: [testing, jest, react-native-testing-library, flutter-test, mocking, snapshot, coverage]
capabilities:
  - Jest configuration for React Native
  - React Native Testing Library patterns
  - Flutter widget testing with flutter_test
  - Mocking native modules and APIs
  - Snapshot testing strategies
  - Code coverage reporting and analysis
useWhen:
  - Setting up unit testing for mobile apps
  - Writing component and widget tests
  - Mocking native modules and external dependencies
  - Implementing snapshot testing
  - Improving test coverage
  - Debugging failing tests
---

# Mobile Unit Testing Expert

Expert in unit and component testing for React Native and Flutter applications.

## Jest Configuration

**React Native Setup:**
```javascript
// jest.config.js
module.exports = {
  preset: 'react-native',
  setupFilesAfterEnv: ['@testing-library/jest-native/extend-expect', './jest.setup.js'],
  transformIgnorePatterns: [
    'node_modules/(?!(react-native|@react-native|@react-navigation|react-native-reanimated)/)',
  ],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.d.ts',
    '!src/**/*.stories.{ts,tsx}',
  ],
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 70,
      lines: 70,
      statements: 70,
    },
  },
}
```

**Jest Setup:**
```javascript
// jest.setup.js
import '@testing-library/jest-native/extend-expect'
import 'react-native-gesture-handler/jestSetup'

// Mock react-native-reanimated
jest.mock('react-native-reanimated', () =>
  require('react-native-reanimated/mock')
)

// Mock AsyncStorage
jest.mock('@react-native-async-storage/async-storage', () =>
  require('@react-native-async-storage/async-storage/jest/async-storage-mock')
)

// Silence console warnings in tests
global.console = {
  ...console,
  warn: jest.fn(),
  error: jest.fn(),
}
```

## React Native Testing Library

**Component Testing:**
```typescript
import { render, screen, fireEvent, waitFor } from '@testing-library/react-native'
import { LoginForm } from './LoginForm'

describe('LoginForm', () => {
  const mockOnSubmit = jest.fn()

  beforeEach(() => {
    jest.clearAllMocks()
  })

  it('renders email and password inputs', () => {
    render(<LoginForm onSubmit={mockOnSubmit} />)

    expect(screen.getByPlaceholderText('Email')).toBeOnTheScreen()
    expect(screen.getByPlaceholderText('Password')).toBeOnTheScreen()
  })

  it('shows validation errors for empty fields', async () => {
    render(<LoginForm onSubmit={mockOnSubmit} />)

    fireEvent.press(screen.getByText('Login'))

    await waitFor(() => {
      expect(screen.getByText('Email is required')).toBeOnTheScreen()
      expect(screen.getByText('Password is required')).toBeOnTheScreen()
    })

    expect(mockOnSubmit).not.toHaveBeenCalled()
  })

  it('submits form with valid data', async () => {
    render(<LoginForm onSubmit={mockOnSubmit} />)

    fireEvent.changeText(screen.getByPlaceholderText('Email'), 'test@example.com')
    fireEvent.changeText(screen.getByPlaceholderText('Password'), 'password123')
    fireEvent.press(screen.getByText('Login'))

    await waitFor(() => {
      expect(mockOnSubmit).toHaveBeenCalledWith({
        email: 'test@example.com',
        password: 'password123',
      })
    })
  })
})
```

## Mocking Native Modules

```javascript
// __mocks__/@react-native-firebase/analytics.js
export default () => ({
  logEvent: jest.fn(),
  setUserId: jest.fn(),
  setUserProperties: jest.fn(),
})

// __mocks__/react-native-keychain.js
export default {
  setGenericPassword: jest.fn(() => Promise.resolve(true)),
  getGenericPassword: jest.fn(() => Promise.resolve({ username: 'test', password: 'token' })),
  resetGenericPassword: jest.fn(() => Promise.resolve(true)),
}
```

## Hook Testing

```typescript
import { renderHook, act, waitFor } from '@testing-library/react-native'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useProducts } from './useProducts'

const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  })
  return ({ children }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  )
}

describe('useProducts', () => {
  it('fetches products successfully', async () => {
    const mockProducts = [{ id: '1', name: 'Product 1' }]
    jest.spyOn(global, 'fetch').mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve(mockProducts),
    })

    const { result } = renderHook(() => useProducts(), {
      wrapper: createWrapper(),
    })

    expect(result.current.isLoading).toBe(true)

    await waitFor(() => {
      expect(result.current.isSuccess).toBe(true)
    })

    expect(result.current.data).toEqual(mockProducts)
  })
})
```

## Flutter Widget Testing

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('LoginForm', () {
    late MockAuthRepository mockAuthRepo;

    setUp(() {
      mockAuthRepo = MockAuthRepository();
    });

    testWidgets('shows validation errors for empty fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginForm(authRepository: mockAuthRepo),
        ),
      );

      await tester.tap(find.text('Login'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('submits form with valid data', (tester) async {
      when(() => mockAuthRepo.signIn(any(), any()))
          .thenAnswer((_) async => User(id: '1'));

      await tester.pumpWidget(
        MaterialApp(
          home: LoginForm(authRepository: mockAuthRepo),
        ),
      );

      await tester.enterText(find.byKey(Key('email-input')), 'test@example.com');
      await tester.enterText(find.byKey(Key('password-input')), 'password');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      verify(() => mockAuthRepo.signIn('test@example.com', 'password')).called(1);
    });
  });
}
```

## Best Practices

- **Test behavior, not implementation** - focus on what users see
- **Use Testing Library queries** - prefer getByRole, getByText
- **Mock at boundaries** - network, storage, native modules
- **Keep tests isolated** - reset mocks between tests
- **Use meaningful assertions** - not just "renders without crashing"

## Common Pitfalls

- Testing implementation details instead of behavior
- Not waiting for async operations properly
- Forgetting to mock native modules
- Overly brittle snapshot tests
