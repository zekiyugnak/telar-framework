---
name: "flutter-state-management"
description: "Using `setState` in `StatefulWidget` for app-wide state causes the entire widget subtree to rebuild on every state change. In a screen with 50+ widgets, a single `setState` call triggers 50+ `build` methods. Users see vi"
source_type: "skill"
source_file: "skills/flutter-state-management.md"
---

# flutter-state-management

Migrated from `skills/flutter-state-management.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- The original Telar orchestration source (`skills/orchestration/...`) is packaged under `source/skills/orchestration/...` for exact-reference lookups; all other Telar skills exist here only as the generated adapters under the plugin-root `skills/` directory.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Eliminate Rebuild Storms from setState in StatefulWidgets

Using `setState` in `StatefulWidget` for app-wide state causes the entire widget subtree to rebuild on every state change. In a screen with 50+ widgets, a single `setState` call triggers 50+ `build` methods. Users see visible jank, slow animations, and battery drain from constant layout recalculations. This skill covers migrating to Riverpod with AsyncNotifier and StateNotifier patterns, plus a decision framework for choosing between Riverpod and BLoC.

## Problem

Developers use `setState` for state that affects multiple screens or shared data. Every `setState` call rebuilds the entire `StatefulWidget` subtree, including child widgets that did not change.

```dart
// BAD: setState for app-wide state causes full subtree rebuilds
// Every time cart, user, OR theme changes, ALL children rebuild
class AppShell extends StatefulWidget {
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  User? user;
  List<CartItem> cart = [];
  ThemeMode themeMode = ThemeMode.light;
  bool isLoading = false;

  // WRONG: This rebuilds Header, ProductList, CartBadge, and ALL their children
  // even though only cart changed
  void addToCart(CartItem item) {
    setState(() {
      cart = [...cart, item];
    });
  }

  // WRONG: Passing state + callbacks down through props (drilling)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Header(
        user: user,
        cartCount: cart.length, // Header rebuilds when cart changes
        themeMode: themeMode,   // Header rebuilds when theme changes
      ),
      body: ProductList(
        user: user,
        cart: cart,
        onAddToCart: addToCart,  // New function reference each build
        isLoading: isLoading,
      ),
      bottomNavigationBar: CartBar(
        cart: cart,
        total: cart.fold(0.0, (sum, item) => sum + item.price),
      ),
    );
  }
}

// BAD: Fetching data in initState with manual loading/error tracking
class ProductListState extends State<ProductList> {
  List<Product> products = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadProducts(); // No retry, no caching, no refresh
  }

  Future<void> _loadProducts() async {
    try {
      setState(() => isLoading = true);
      products = await api.getProducts();
      setState(() => isLoading = false);
    } catch (e) {
      // WRONG: setState after async gap - widget may be disposed
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }
}
```

## Solution

### Decision Framework: Riverpod vs BLoC

Choose based on your team and project:

| Criteria | Choose Riverpod | Choose BLoC |
|---|---|---|
| Team size | Small-medium (1-5 devs) | Large (5+ devs) |
| Codebase | Greenfield or small existing | Large existing codebase |
| Testing | Prefers simple overrides | Prefers strict event/state contracts |
| Boilerplate tolerance | Wants minimal boilerplate | Accepts more structure for predictability |
| Code generation | Comfortable with build_runner | Prefers explicit code |
| Learning curve | Steeper initial, simpler long-term | Moderate initial, consistent patterns |

**Default recommendation**: Riverpod for new projects. BLoC for large teams that need strict architectural boundaries.

### Riverpod AsyncNotifier for Data Fetching

```dart
// GOOD: AsyncNotifier handles loading, error, and data states automatically
// lib/features/products/providers/product_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'product_provider.g.dart';

// Simple async data provider - replaces initState + setState + loading + error
@riverpod
class ProductList extends _$ProductList {
  @override
  Future<List<Product>> build() async {
    // This IS the fetch. Riverpod tracks loading/error/data automatically.
    // Re-runs when dependencies change (e.g., auth state).
    final repository = ref.watch(productRepositoryProvider);
    return repository.getProducts();
  }

  // Pull-to-refresh: invalidate triggers a rebuild (re-fetch)
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future; // Wait for the rebuild to complete
  }

  // Optimistic add
  Future<void> addProduct(CreateProductDto dto) async {
    final repository = ref.read(productRepositoryProvider);
    // Optimistic: update UI immediately
    final optimisticProduct = Product.fromDto(dto, id: 'temp-${DateTime.now()}');
    state = AsyncData([...state.value ?? [], optimisticProduct]);

    try {
      final created = await repository.createProduct(dto);
      // Replace optimistic entry with server response
      state = AsyncData([
        ...state.value?.where((p) => p.id != optimisticProduct.id).toList() ?? [],
        created,
      ]);
    } catch (e, st) {
      // Rollback: remove optimistic entry and show error
      state = AsyncData(
        state.value?.where((p) => p.id != optimisticProduct.id).toList() ?? [],
      );
      state = AsyncError(e, st);
    }
  }
}

// Family modifier: one provider instance per category ID
@riverpod
Future<List<Product>> productsByCategory(
  ProductsByCategoryRef ref,
  String categoryId,
) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductsByCategory(categoryId);
}
```

### StateNotifier for Complex State Machines

```dart
// GOOD: StateNotifier for state that has multiple interdependent fields
// lib/features/checkout/providers/checkout_provider.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'checkout_provider.freezed.dart';
part 'checkout_provider.g.dart';

@freezed
class CheckoutState with _$CheckoutState {
  const factory CheckoutState({
    @Default([]) List<CartItem> items,
    Address? shippingAddress,
    Address? billingAddress,
    PaymentMethod? paymentMethod,
    @Default(false) bool useShippingAsBilling,
    @Default(CheckoutStep.cart) CheckoutStep currentStep,
    @Default(false) bool isProcessing,
    String? error,
  }) = _CheckoutState;

  const CheckoutState._();

  double get subtotal =>
      items.fold(0.0, (sum, item) => sum + item.price * item.quantity);
  double get tax => subtotal * 0.08;
  double get total => subtotal + tax;
  bool get canProceed => switch (currentStep) {
    CheckoutStep.cart => items.isNotEmpty,
    CheckoutStep.shipping => shippingAddress != null,
    CheckoutStep.payment => paymentMethod != null,
    CheckoutStep.review => !isProcessing,
  };
}

enum CheckoutStep { cart, shipping, payment, review }

@riverpod
class Checkout extends _$Checkout {
  @override
  CheckoutState build() => const CheckoutState();

  void addItem(CartItem item) {
    final existing = state.items.indexWhere((i) => i.id == item.id);
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(
        quantity: updated[existing].quantity + 1,
      );
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [...state.items, item]);
    }
  }

  void removeItem(String itemId) {
    state = state.copyWith(
      items: state.items.where((i) => i.id != itemId).toList(),
    );
  }

  void setShippingAddress(Address address) {
    state = state.copyWith(
      shippingAddress: address,
      billingAddress: state.useShippingAsBilling ? address : state.billingAddress,
    );
  }

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(paymentMethod: method);
  }

  void nextStep() {
    if (!state.canProceed) return;
    final nextIndex = CheckoutStep.values.indexOf(state.currentStep) + 1;
    if (nextIndex < CheckoutStep.values.length) {
      state = state.copyWith(currentStep: CheckoutStep.values[nextIndex]);
    }
  }

  void previousStep() {
    final prevIndex = CheckoutStep.values.indexOf(state.currentStep) - 1;
    if (prevIndex >= 0) {
      state = state.copyWith(currentStep: CheckoutStep.values[prevIndex]);
    }
  }

  Future<Order> placeOrder() async {
    state = state.copyWith(isProcessing: true, error: null);
    try {
      final orderService = ref.read(orderServiceProvider);
      final order = await orderService.placeOrder(
        items: state.items,
        shipping: state.shippingAddress!,
        billing: state.useShippingAsBilling
            ? state.shippingAddress!
            : state.billingAddress!,
        payment: state.paymentMethod!,
      );
      // Reset checkout state after successful order
      state = const CheckoutState();
      return order;
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
      rethrow;
    }
  }
}
```

### Widget Consuming Providers (Minimal Rebuilds)

```dart
// GOOD: Each widget watches only the slice of state it needs
// lib/features/products/screens/product_list_screen.dart
class ProductListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AsyncValue handles loading, error, and data states
    final productsAsync = ref.watch(productListProvider);

    return productsAsync.when(
      loading: () => const ProductListSkeleton(),
      error: (error, stack) => ErrorWidget(
        message: error.toString(),
        onRetry: () => ref.invalidate(productListProvider),
      ),
      data: (products) => RefreshIndicator(
        onRefresh: () => ref.read(productListProvider.notifier).refresh(),
        child: ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) => ProductCard(
            productId: products[index].id,
          ),
        ),
      ),
    );
  }
}

// GOOD: CartBadge only rebuilds when item count changes
class CartBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // select() subscribes to a computed value, not the entire state
    final count = ref.watch(
      checkoutProvider.select((state) => state.items.length),
    );
    if (count == 0) return const SizedBox.shrink();
    return Badge(label: Text('$count'));
  }
}

// GOOD: Checkout total only rebuilds when total changes
class CheckoutTotalBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(
      checkoutProvider.select((state) => state.total),
    );
    final canProceed = ref.watch(
      checkoutProvider.select((state) => state.canProceed),
    );

    return BottomAppBar(
      child: Row(
        children: [
          Text('Total: \$${total.toStringAsFixed(2)}'),
          const Spacer(),
          ElevatedButton(
            onPressed: canProceed
                ? () => ref.read(checkoutProvider.notifier).nextStep()
                : null,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
```

### Provider Scoping for Testing

```dart
// GOOD: Override providers in tests without DI frameworks
// test/features/checkout/checkout_test.dart
void main() {
  testWidgets('checkout shows correct total', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Replace real repository with fake
          productRepositoryProvider.overrideWithValue(FakeProductRepository()),
          // Pre-populate checkout state
          checkoutProvider.overrideWith(() => Checkout()
            ..addItem(CartItem(id: '1', name: 'Test', price: 9.99, quantity: 2))),
        ],
        child: const MaterialApp(home: CheckoutScreen()),
      ),
    );

    expect(find.text('Total: \$21.58'), findsOneWidget); // 9.99 * 2 + tax
  });
}
```

## Why This Works

- **Riverpod providers are external to the widget tree**: Unlike `setState`, changing a provider's state only notifies widgets that explicitly `watch` that provider. A `CartBadge` watching `checkoutProvider.select((s) => s.items.length)` does not rebuild when `shippingAddress` changes.
- **`select()` enables sub-state subscriptions**: `ref.watch(provider.select((s) => s.total))` computes the total and only triggers a rebuild when the computed value differs from the previous one. This is equivalent to Zustand selectors.
- **AsyncNotifier eliminates manual loading/error state**: The `AsyncValue<T>` sealed class guarantees you handle loading, error, and data. No more forgotten `isLoading = false` in catch blocks or `setState` after dispose.
- **Freezed + copyWith makes state updates safe**: Immutable state with `copyWith` prevents accidental mutations. The compiler enforces that all state transitions produce new objects.

## Edge Cases & Pitfalls

### Platform-Specific Gotchas

**iOS:**
- Large Riverpod provider trees with many `autoDispose` providers can cause micro-stutters during rapid navigation (mounting/unmounting screens fast). Profile with Flutter DevTools Timeline view.
- `keepAlive()` in providers that hold large datasets (images, ML models) can cause memory warnings on older iPhones. Use `ref.onDispose` to release resources.

**Android:**
- Dart isolates are limited on older Android devices. If your StateNotifier does heavy computation (sorting 10K+ items), move it to `compute()` or a separate isolate to avoid jank.
- Provider state is lost when Android kills the process in background. Use `shared_preferences` or `hive` to persist critical state and restore in the provider's `build` method.

### Common Mistakes

- **Watching providers in callbacks**: `ref.watch` must only be called in `build`. Using `ref.watch` inside `onPressed` or `Future.then` causes undefined behavior. Use `ref.read` in callbacks.
- **Forgetting `autoDispose`**: Code-generated providers (`@riverpod`) are auto-disposed by default. Hand-written providers are NOT. Add `.autoDispose` modifier to avoid memory leaks: `StateNotifierProvider.autoDispose`.
- **Overusing `family`**: Every unique argument to a `family` provider creates a new provider instance. `productsByCategoryProvider('electronics')` and `productsByCategoryProvider('clothing')` are separate cached instances. This is correct but can use significant memory with thousands of unique keys.
- **Mutating state directly**: `state.items.add(item)` mutates the list in place. Riverpod compares by reference, so it does not detect the change. Always create new collections: `state = state.copyWith(items: [...state.items, item])`.

## Verification

```bash
# Run the build_runner for code generation
dart run build_runner build --delete-conflicting-outputs

# Profile widget rebuilds with Flutter DevTools
flutter run --profile
# Open DevTools > Performance > Widget rebuild counts
```

- [ ] Open Flutter DevTools Widget Inspector. Toggle theme. Verify only theme-dependent widgets rebuild (not product list, not cart).
- [ ] Watch `CheckoutTotalBar` rebuild count. Add items to cart. Verify it only rebuilds when total changes, not when address or step changes.
- [ ] Override a provider in a test. Verify the test uses the fake data, not real API.
- [ ] Navigate away from ProductListScreen and back. Verify cached data loads instantly (no loading spinner).
- [ ] Add 100 items to cart rapidly. Verify no dropped frames in the checkout animation.

## References

- [Riverpod Documentation](https://riverpod.dev/docs/introduction/getting-started)
- [Riverpod AsyncNotifier](https://riverpod.dev/docs/providers/async_notifier_provider)
- [flutter_bloc Documentation](https://bloclibrary.dev/)
- [Freezed Package](https://pub.dev/packages/freezed)
- [Flutter Performance Profiling](https://docs.flutter.dev/perf/ui-performance)
