---
id: mobile-performance-testing
category: agent
tags: [performance-testing, load-testing, profiling, benchmarks, memory-leaks, startup-time]
capabilities:
  - Load testing for mobile backends
  - Performance profiling automation
  - Benchmark suite implementation
  - Memory leak detection
  - Startup time measurement
  - Battery and resource usage testing
useWhen:
  - Setting up performance testing for mobile apps
  - Creating automated benchmark suites
  - Detecting memory leaks systematically
  - Measuring and optimizing app startup time
  - Testing app performance under load
  - Profiling resource usage and battery impact
---

# Mobile Performance Testing Specialist

Expert in performance testing, profiling, and optimization for mobile applications.

## Startup Time Testing

**React Native Measurement:**
```typescript
// index.js
import { performance } from 'perf_hooks'

const startupStart = performance.now()

AppRegistry.registerComponent(appName, () => {
  const startupEnd = performance.now()
  console.log(`Startup time: ${startupEnd - startupStart}ms`)

  // Report to analytics
  analytics.track('app_startup', {
    duration: startupEnd - startupStart,
    platform: Platform.OS,
    version: DeviceInfo.getVersion(),
  })

  return App
})
```

**Automated Benchmark:**
```typescript
// benchmarks/startup.test.ts
describe('Startup Performance', () => {
  const STARTUP_THRESHOLD = 2000 // 2 seconds

  beforeEach(async () => {
    await device.terminateApp()
  })

  it('should start within threshold', async () => {
    const start = Date.now()
    await device.launchApp({ newInstance: true })
    await waitFor(element(by.id('home-screen'))).toBeVisible().withTimeout(10000)
    const duration = Date.now() - start

    console.log(`Startup duration: ${duration}ms`)
    expect(duration).toBeLessThan(STARTUP_THRESHOLD)
  })

  it('should cold start under 3 seconds', async () => {
    await device.clearKeychain()
    const start = Date.now()
    await device.launchApp({ newInstance: true })
    await waitFor(element(by.id('onboarding-screen'))).toBeVisible()
    const duration = Date.now() - start

    expect(duration).toBeLessThan(3000)
  })
})
```

## Memory Leak Detection

**Automated Memory Tests:**
```typescript
// tests/memory.test.ts
describe('Memory Leak Detection', () => {
  it('should not leak memory when navigating', async () => {
    const initialMemory = await device.getMemoryUsage()

    // Perform navigation cycle multiple times
    for (let i = 0; i < 10; i++) {
      await element(by.id('profile-tab')).tap()
      await element(by.id('home-tab')).tap()
      await element(by.id('settings-tab')).tap()
      await element(by.id('home-tab')).tap()
    }

    // Force garbage collection if possible
    await new Promise(resolve => setTimeout(resolve, 2000))

    const finalMemory = await device.getMemoryUsage()
    const memoryGrowth = finalMemory - initialMemory

    console.log(`Memory growth: ${memoryGrowth}MB`)
    expect(memoryGrowth).toBeLessThan(50) // Max 50MB growth
  })
})
```

**React Native Memory Profiling:**
```typescript
// Use Hermes profiler
import { HermesProfiler } from 'react-native'

async function captureMemorySnapshot(label: string) {
  if (__DEV__) {
    const snapshot = await HermesProfiler.takeHeapSnapshot()
    console.log(`[${label}] Heap size: ${snapshot.heapSize}`)
    return snapshot
  }
}
```

## FPS and Rendering Tests

**Frame Rate Monitoring:**
```typescript
// hooks/useFrameRate.ts
import { useEffect, useRef } from 'react'

export function useFrameRateMonitor(screenName: string) {
  const frameCount = useRef(0)
  const lastTime = useRef(performance.now())

  useEffect(() => {
    let rafId: number

    const measureFPS = () => {
      frameCount.current++
      const currentTime = performance.now()

      if (currentTime - lastTime.current >= 1000) {
        const fps = frameCount.current
        frameCount.current = 0
        lastTime.current = currentTime

        if (fps < 55) {
          console.warn(`[${screenName}] Low FPS: ${fps}`)
          analytics.track('low_fps', { screen: screenName, fps })
        }
      }

      rafId = requestAnimationFrame(measureFPS)
    }

    rafId = requestAnimationFrame(measureFPS)
    return () => cancelAnimationFrame(rafId)
  }, [screenName])
}
```

## Load Testing Backend

**k6 for Mobile Backend:**
```javascript
// load-tests/api.js
import http from 'k6/http'
import { check, sleep } from 'k6'

export const options = {
  stages: [
    { duration: '1m', target: 100 },   // Ramp up
    { duration: '5m', target: 100 },   // Steady state
    { duration: '1m', target: 200 },   // Spike
    { duration: '2m', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% under 500ms
    http_req_failed: ['rate<0.01'],    // <1% errors
  },
}

export default function () {
  // Simulate mobile API calls
  const authResponse = http.post('https://api.myapp.com/auth/login', {
    email: 'test@example.com',
    password: 'password',
  })

  check(authResponse, {
    'login succeeded': (r) => r.status === 200,
  })

  const token = authResponse.json('token')

  // Simulate typical user flow
  const headers = { Authorization: `Bearer ${token}` }

  http.get('https://api.myapp.com/user/profile', { headers })
  sleep(1)

  http.get('https://api.myapp.com/products?page=1', { headers })
  sleep(2)

  http.get('https://api.myapp.com/products?page=2', { headers })
  sleep(1)
}
```

## Benchmark Suite

```typescript
// benchmarks/suite.ts
interface BenchmarkResult {
  name: string
  duration: number
  iterations: number
  opsPerSecond: number
}

async function runBenchmark(
  name: string,
  fn: () => Promise<void>,
  iterations = 100
): Promise<BenchmarkResult> {
  const start = performance.now()

  for (let i = 0; i < iterations; i++) {
    await fn()
  }

  const duration = performance.now() - start
  return {
    name,
    duration,
    iterations,
    opsPerSecond: (iterations / duration) * 1000,
  }
}

// Example benchmarks
const results = await Promise.all([
  runBenchmark('JSON parse 1KB', async () => {
    JSON.parse(smallJson)
  }),
  runBenchmark('Image decode', async () => {
    await Image.prefetch(imageUrl)
  }),
  runBenchmark('AsyncStorage read', async () => {
    await AsyncStorage.getItem('test-key')
  }),
])
```

## Best Practices

- **Establish baselines** before optimization
- **Test on low-end devices** to catch performance issues early
- **Automate benchmarks** in CI for regression detection
- **Profile in production builds** - debug builds are slower
- **Monitor real user metrics** - synthetic tests don't catch everything

## Common Pitfalls

- Testing only on high-end devices
- Not warming up before benchmarks
- Measuring in debug mode
- Ignoring memory usage patterns
