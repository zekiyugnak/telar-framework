---
name: "blueprint-crud-list"
description: "Master-detail pattern with full CRUD, pull-to-refresh, cursor-based pagination, swipe actions, and optimistic updates."
source_type: "blueprint"
source_file: "skills/blueprints/crud-list.md"
---

# blueprint-crud-list

Migrated from `skills/blueprints/crud-list.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# Blueprint: CRUD List

Master-detail pattern with full CRUD, pull-to-refresh, cursor-based pagination, swipe actions, and optimistic updates.

## File Manifest

```markdown
# React Native (TypeScript)
src/
  screens/items/
    ItemListScreen.tsx
    ItemDetailScreen.tsx
    ItemFormScreen.tsx
  hooks/
    useItems.ts
    useItemMutation.ts
  components/
    ItemCard.tsx
    SwipeableRow.tsx
    EmptyState.tsx
    PaginatedList.tsx
  __tests__/
    useItems.test.ts
    ItemListScreen.test.tsx

# Flutter (Dart)
lib/
  features/items/
    screens/
      item_list_screen.dart
      item_detail_screen.dart
      item_form_screen.dart
    providers/
      items_provider.dart
      item_mutation_provider.dart
    widgets/
      item_card.dart
      swipeable_row.dart
      empty_state.dart
test/
  features/items/
    items_provider_test.dart
    item_list_screen_test.dart
```

## React Native Implementation

### Data Hook with Pagination
```typescript
// src/hooks/useItems.ts
import { useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { supabase } from '../services/supabase';

const PAGE_SIZE = 20;

interface Item {
  id: string;
  title: string;
  description: string;
  status: 'active' | 'archived';
  created_at: string;
  updated_at: string;
}

export function useItems() {
  return useInfiniteQuery({
    queryKey: ['items'],
    queryFn: async ({ pageParam }) => {
      let query = supabase
        .from('items')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(PAGE_SIZE);

      if (pageParam) {
        query = query.lt('created_at', pageParam);
      }

      const { data, error } = await query;
      if (error) throw error;
      return data as Item[];
    },
    initialPageParam: null as string | null,
    getNextPageParam: (lastPage) =>
      lastPage.length === PAGE_SIZE
        ? lastPage[lastPage.length - 1].created_at
        : undefined,
  });
}

export function useDeleteItem() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: string) => {
      const { error } = await supabase.from('items').delete().eq('id', id);
      if (error) throw error;
    },
    // Optimistic delete
    onMutate: async (id) => {
      await queryClient.cancelQueries({ queryKey: ['items'] });
      const previous = queryClient.getQueryData(['items']);
      queryClient.setQueryData(['items'], (old: any) => ({
        ...old,
        pages: old.pages.map((page: Item[]) =>
          page.filter((item) => item.id !== id)
        ),
      }));
      return { previous };
    },
    onError: (_err, _id, context) => {
      queryClient.setQueryData(['items'], context?.previous);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['items'] });
    },
  });
}
```

### List Screen
```tsx
// src/screens/items/ItemListScreen.tsx
import { FlatList, RefreshControl, View, Text, Pressable } from 'react-native';
import { useItems, useDeleteItem } from '../../hooks/useItems';
import { ItemCard } from '../../components/ItemCard';
import { EmptyState } from '../../components/EmptyState';
import { SwipeableRow } from '../../components/SwipeableRow';

export function ItemListScreen({ navigation }: Props) {
  const {
    data,
    isLoading,
    isRefetching,
    fetchNextPage,
    hasNextPage,
    refetch,
  } = useItems();
  const deleteItem = useDeleteItem();

  const items = data?.pages.flat() ?? [];

  const renderItem = useCallback(({ item }: { item: Item }) => (
    <SwipeableRow
      onEdit={() => navigation.navigate('ItemForm', { id: item.id })}
      onDelete={() => deleteItem.mutate(item.id)}
    >
      <ItemCard
        item={item}
        onPress={() => navigation.navigate('ItemDetail', { id: item.id })}
      />
    </SwipeableRow>
  ), [navigation, deleteItem]);

  if (isLoading) return <LoadingScreen />;

  return (
    <View style={styles.container}>
      <FlatList
        data={items}
        renderItem={renderItem}
        keyExtractor={(item) => item.id}
        refreshControl={
          <RefreshControl refreshing={isRefetching} onRefresh={refetch} />
        }
        onEndReached={() => hasNextPage && fetchNextPage()}
        onEndReachedThreshold={0.5}
        ListEmptyComponent={
          <EmptyState
            title="No items yet"
            message="Tap + to create your first item"
            actionLabel="Create Item"
            onAction={() => navigation.navigate('ItemForm')}
          />
        }
        accessibilityRole="list"
        accessibilityLabel={`Items list, ${items.length} items`}
      />

      <Pressable
        style={styles.fab}
        onPress={() => navigation.navigate('ItemForm')}
        accessibilityRole="button"
        accessibilityLabel="Create new item"
      >
        <Text style={styles.fabIcon}>+</Text>
      </Pressable>
    </View>
  );
}
```

## Flutter Implementation

### Items Provider
```dart
// lib/features/items/providers/items_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _pageSize = 20;

final itemsProvider = StateNotifierProvider<ItemsNotifier, ItemsState>((ref) {
  return ItemsNotifier(Supabase.instance.client);
});

class ItemsState {
  final List<Item> items;
  final bool loading;
  final bool hasMore;
  final String? error;

  const ItemsState({
    this.items = const [],
    this.loading = false,
    this.hasMore = true,
    this.error,
  });

  ItemsState copyWith({List<Item>? items, bool? loading, bool? hasMore, String? error}) {
    return ItemsState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class ItemsNotifier extends StateNotifier<ItemsState> {
  final SupabaseClient _client;

  ItemsNotifier(this._client) : super(const ItemsState()) {
    loadItems();
  }

  Future<void> loadItems({bool refresh = false}) async {
    if (state.loading) return;
    state = state.copyWith(loading: true, error: null);
    try {
      var query = _client
          .from('items')
          .select()
          .order('created_at', ascending: false)
          .limit(_pageSize);

      if (!refresh && state.items.isNotEmpty) {
        query = query.lt('created_at', state.items.last.createdAt);
      }

      final data = await query;
      final newItems = (data as List).map((e) => Item.fromJson(e)).toList();

      state = state.copyWith(
        items: refresh ? newItems : [...state.items, ...newItems],
        loading: false,
        hasMore: newItems.length == _pageSize,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> deleteItem(String id) async {
    // Optimistic delete
    final previous = state.items;
    state = state.copyWith(
      items: state.items.where((i) => i.id != id).toList(),
    );
    try {
      await _client.from('items').delete().eq('id', id);
    } catch (e) {
      state = state.copyWith(items: previous, error: e.toString());
    }
  }
}
```

### List Screen
```dart
// lib/features/items/screens/item_list_screen.dart
class ItemListScreen extends ConsumerWidget {
  const ItemListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(itemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Items')),
      body: state.items.isEmpty && state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
              ? EmptyState(
                  title: 'No items yet',
                  message: 'Tap + to create your first item',
                  onAction: () => context.push('/items/new'),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(itemsProvider.notifier).loadItems(refresh: true),
                  child: ListView.builder(
                    itemCount: state.items.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.items.length) {
                        ref.read(itemsProvider.notifier).loadItems();
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ));
                      }
                      final item = state.items[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        background: _deleteBackground(),
                        confirmDismiss: (_) => _confirmDelete(context),
                        onDismissed: (_) => ref.read(itemsProvider.notifier).deleteItem(item.id),
                        child: ItemCard(
                          item: item,
                          onTap: () => context.push('/items/${item.id}'),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/items/new'),
        tooltip: 'Create new item',
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

## Supabase Backend

```sql
CREATE TABLE public.items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX items_user_created ON public.items (user_id, created_at DESC);

ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own items"
  ON public.items FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

## Tests

```typescript
describe('useItems', () => {
  it('loads first page of items', async () => {
    const { result } = renderHook(() => useItems(), { wrapper });
    await waitFor(() => expect(result.current.data?.pages).toHaveLength(1));
    expect(result.current.data?.pages[0]).toHaveLength(20);
  });

  it('optimistically deletes an item', async () => {
    const { result: list } = renderHook(() => useItems(), { wrapper });
    const { result: del } = renderHook(() => useDeleteItem(), { wrapper });

    await act(async () => { del.current.mutate('item-1'); });

    expect(list.current.data?.pages.flat().find(i => i.id === 'item-1')).toBeUndefined();
  });
});
```

## Accessibility Checklist

- [x] List announces item count to screen readers
- [x] Swipe actions have accessible alternatives (long-press menu)
- [x] Empty state action button has descriptive label
- [x] FAB has tooltip/accessibilityLabel
- [x] Loading and error states announced
- [x] Delete confirmation dialog is keyboard-navigable
