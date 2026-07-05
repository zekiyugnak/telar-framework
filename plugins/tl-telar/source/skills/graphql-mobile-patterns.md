---
id: graphql-mobile-patterns
category: skill
tags: [graphql, apollo-client, codegen, caching, subscriptions]
capabilities:
  - Apollo Client setup
  - Code generation
  - Normalized caching
  - Subscriptions
useWhen:
  - Setting up GraphQL client
  - Optimizing GraphQL queries
  - Implementing subscriptions
---

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
