---
name: "graphql-mobile-patterns"
description: "GraphQL client patterns for mobile apps."
source_type: "skill"
source_file: "skills/graphql-mobile-patterns.md"
---

# graphql-mobile-patterns

Migrated from `skills/graphql-mobile-patterns.md`.

## Codex packaging notes

- Claude/Telar source files remain the source of truth; this file is the generated Codex adapter.
- Skill-local support files from the original Telar skill, such as `references/...` or `workflow/...`, are packaged beside this `SKILL.md`.
- Repo-root references from the original Telar file, such as `agents/...`, `commands/...`, `scripts/...`, `resources/...`, `rules/...`, `hooks/...`, or `templates/...`, are packaged at this plugin root.
- Original Telar `skills/...` source paths are packaged under `source/skills/...` because the plugin-root `skills/` directory is reserved for generated Codex skill adapters.
- Resolve plugin-root paths from this generated skill directory via `../..` when reading support files or running packaged scripts.


# GraphQL Mobile Patterns

GraphQL client patterns for mobile apps.

## Apollo Client Setup

```typescript
import {
  ApolloClient,
  InMemoryCache,
  createHttpLink,
  split,
} from '@apollo/client'
import { setContext } from '@apollo/client/link/context'
import { GraphQLWsLink } from '@apollo/client/link/subscriptions'
import { getMainDefinition } from '@apollo/client/utilities'
import { createClient } from 'graphql-ws'

const httpLink = createHttpLink({
  uri: 'https://api.example.com/graphql',
})

const authLink = setContext(async (_, { headers }) => {
  const token = await getToken()
  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : '',
    },
  }
})

const wsLink = new GraphQLWsLink(
  createClient({
    url: 'wss://api.example.com/graphql',
    connectionParams: async () => ({
      authToken: await getToken(),
    }),
  })
)

const splitLink = split(
  ({ query }) => {
    const definition = getMainDefinition(query)
    return (
      definition.kind === 'OperationDefinition' &&
      definition.operation === 'subscription'
    )
  },
  wsLink,
  authLink.concat(httpLink)
)

export const client = new ApolloClient({
  link: splitLink,
  cache: new InMemoryCache(),
})
```

## Code Generation

```yaml
# codegen.yml
schema: 'https://api.example.com/graphql'
documents: 'src/**/*.graphql'
generates:
  src/generated/graphql.tsx:
    plugins:
      - typescript
      - typescript-operations
      - typescript-react-apollo
    config:
      withHooks: true
```

```graphql
# src/queries/posts.graphql
query GetPosts($limit: Int!) {
  posts(limit: $limit) {
    id
    title
    author {
      name
    }
  }
}

mutation CreatePost($input: CreatePostInput!) {
  createPost(input: $input) {
    id
    title
  }
}
```

## Using Generated Hooks

```typescript
import { useGetPostsQuery, useCreatePostMutation } from './generated/graphql'

function PostsList() {
  const { data, loading, refetch } = useGetPostsQuery({
    variables: { limit: 10 },
  })

  const [createPost] = useCreatePostMutation({
    update(cache, { data }) {
      // Update cache after mutation
      cache.modify({
        fields: {
          posts(existing = []) {
            return [data.createPost, ...existing]
          },
        },
      })
    },
  })
}
```

## Optimistic Updates

```typescript
const [likePost] = useLikePostMutation({
  optimisticResponse: {
    likePost: {
      __typename: 'Post',
      id: postId,
      likesCount: currentLikes + 1,
      isLiked: true,
    },
  },
})
```

## Best Practices

- Use code generation for type safety
- Implement optimistic updates for UX
- Configure cache policies per query
- Use fragments for reusable selections
