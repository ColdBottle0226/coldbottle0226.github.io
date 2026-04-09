---
title: "Nuxt3 특정 IP 대역만 접근 허용하기 - Plugin, Middleware, Spring Boot 연동"
date: 2026-03-15 00:00:00 +0900
categories: [Nuxt3]
tags: [Nuxt3,Middleware, Plugin, IP, 접근제어]
---

##  1. 개요

---

서비스를 운영하다 보면 특정 환경에서만 접근을 허용해야 하는 상황이 생긴다.

사내 네트워크에서만 접근 가능한 관리자 페이지, 배포 전 QA 환경, 또는 서비스 점검 중 내부 인원만 접근해야 하는 경우가 대표적이다. 이번 글에서는 Nuxt3 환경에서 특정 IP 대역만 접근을 허용하고, 그 외의 접속에는 점검 페이지를 보여주는 방법을 정리한다.

### 📌 전체 구조

이 기능을 구현하기 위해 크게 세 가지 레이어를 활용한다.

[![image](/assets/images/nuxt3-ip/image1.svg)](/assets/images/nuxt3-ip/image1.svg)

| 레이어 | 역할 |
|--------|------|
| Nginx | 1차 방어선 - 리버스 프록시, 실제 IP 헤더 주입 |
| Nuxt3 SSR | 2차 방어선 - Plugin + Global Middleware |
| Spring Boot API | IP 허용 정책 데이터 제공 (Redis 기반) |

Nginx에서 1차로 처리하고, Nuxt 레벨에서 2차로 처리하는 이중 구조이며, 이 글에서는 **Nuxt3 + Spring Boot 레벨의 구현**에 집중한다.

---

##  2. Plugin vs Middleware

---

Nuxt3에서 접근 제어를 구현하려면 먼저 **Plugin**과 **Middleware**의 차이를 정확히 이해해야 한다.

### 📌 실행 라이프사이클

Nuxt 공식 문서([Nuxt Lifecycle](https://nuxt.com/docs/4.x/guide/concepts/nuxt-lifecycle))에 따르면 SSR 요청 시 실행 순서는 다음과 같다.

[![image](/assets/images/nuxt3-ip/image2.svg)](/assets/images/nuxt3-ip/image2.svg)

이 순서가 핵심이다. **Plugin이 Middleware보다 먼저 실행**되기 때문에, Plugin에서 데이터를 준비하고 Middleware에서 그 데이터를 활용하는 패턴이 가능하다.

### 📌 Plugin

Nuxt 공식 문서([plugins](https://nuxt.com/docs/3.x/guide/directory-structure/plugins))에 따르면, Plugin은 **Vue 앱 인스턴스가 생성되는 시점에 단 1회 실행**된다.

주요 특성은 아래와 같다.

- `plugins/` 디렉토리에 파일을 두면 자동으로 등록된다
- `nuxtApp` 인스턴스 하나만을 인자로 받는다
- `.server.ts` / `.client.ts` 접미사로 실행 환경을 제한할 수 있다
- 파일명 앞에 숫자를 붙여(`01.plugin.ts`) 실행 순서를 보장할 수 있다

> 💡
> Plugin은 앱이 시작될 때 **한 번만 실행**되므로, 매 라우트 이동마다 반복적으로 실행되어서는 안 되는 초기화 작업에 적합하다.
> IP 허용 정책을 API에서 불러오는 작업이 바로 이 케이스다.

### 📌 Middleware

Nuxt 공식 문서([middleware](https://nuxt.com/docs/guide/directory-structure/middleware))에 따르면, Middleware는 **특정 라우트로 이동하기 전마다 실행**되는 Navigation Guard다.

3가지 종류가 있다.

- **Anonymous (inline)**: 페이지 컴포넌트 내 `definePageMeta`에 직접 정의
- **Named**: `middleware/` 디렉토리에 파일로 생성, 페이지에서 이름으로 참조
- **Global**: `middleware/*.global.ts` 파일명으로 생성, 모든 라우트에 자동 적용

IP 접근 제어는 모든 페이지에 적용되어야 하므로 **Global Middleware**가 적합하다. `to`, `from` 두 인자로 현재/목적지 라우트 정보를 받으며, `navigateTo()`와 `abortNavigation()`으로 라우트 이동을 제어한다.

### 📌 역할 분리

| 구분 | Plugin | Global Middleware |
|------|--------|-------------------|
| 실행 시점 | 앱 초기화 시 1회 | 라우트 이동마다 |
| 이번 구현에서의 역할 | IP 정책 API 호출 및 전역 상태 저장 | IP 허용 여부 체크 및 리다이렉트 |
| 왜 이 역할인가 | API는 1번만 호출하면 충분 | 모든 라우트를 가드해야 함 |

---

##  3. 클라이언트 IP 추출

---

### 📌 왜 서버에서만 IP를 알 수 있나

브라우저(클라이언트) 환경에서는 자신의 공인 IP를 직접 알 수 없다. `window` 객체나 JavaScript API 어디에도 현재 클라이언트 IP를 반환하는 수단이 없기 때문에, 알려면 외부 API를 별도로 호출해야 한다.

반면 서버는 클라이언트가 HTTP 요청을 보낼 때 **TCP 소켓 연결** 자체에서 상대방 IP를 알 수 있다. Nuxt SSR 환경에서는 `useRequestEvent()`로 현재 HTTP 요청 객체를 가져와 이 정보를 추출한다.

### 📌 리버스 프록시 환경의 문제

실제 운영 환경에서는 클라이언트와 Nuxt 서버 사이에 Nginx 같은 **리버스 프록시**가 존재한다.

[![image](/assets/images/nuxt3-ip/image3.svg)](/assets/images/nuxt3-ip/image3.svg)

이 구조에서 Nuxt가 `socket.remoteAddress`만 보면 실제 클라이언트 IP가 아닌 **Nginx의 IP**를 클라이언트 IP로 인식하게 된다. 이 문제를 해결하기 위해 Nginx는 원래 클라이언트 IP를 **HTTP 헤더에 담아** Nuxt로 전달한다.

```nginx
# nginx.conf
proxy_set_header X-Real-IP        $remote_addr;
proxy_set_header X-Forwarded-For  $proxy_add_x_forwarded_for;
```

### 📌 X-Real-IP vs X-Forwarded-For

**X-Real-IP**는 Nginx가 `$remote_addr`(실제 연결된 클라이언트 IP)를 직접 세팅하는 헤더다. 단일 프록시 환경에서 가장 신뢰도가 높다.

**X-Forwarded-For**는 여러 프록시를 경유할 때 IP가 누적되는 헤더다. 쉼표로 구분된 IP 목록에서 **첫 번째 값**이 원래 클라이언트 IP다.

```
클라이언트 → 프록시A → 프록시B → Nuxt
X-Forwarded-For: "203.0.113.5, 10.0.0.1, 172.16.0.1"
                  ↑ 원래 클라이언트 IP
```

> 💡
> `X-Forwarded-For`는 클라이언트가 직접 이 헤더를 조작할 수 있어 `X-Real-IP`보다 신뢰도가 낮다.
> 따라서 IP 추출 우선순위는 **X-Real-IP → X-Forwarded-For → socket.remoteAddress** 순으로 설정한다.

### 📌 useState와 payload를 통한 SSR/CSR 상태 공유

일반 `ref()`는 SSR과 CSR 각각 독립적인 상태를 가진다. 즉, 서버에서 만든 `ref` 값이 클라이언트에서 재사용되지 않는다.

반면 `useState`는 서버에서 생성한 상태를 **hydration 시 클라이언트가 그대로 이어받는다**. 또한 Nuxt SSR은 HTML을 생성할 때 `__NUXT__` 라는 전역 객체를 HTML 안에 포함시켜 클라이언트로 전달하는데, `nuxtApp.payload`가 바로 이 데이터 공간이다.

[![image](/assets/images/nuxt3-ip/image4.svg)](/assets/images/nuxt3-ip/image4.svg)

서버(SSR)에서 추출한 클라이언트 IP를 `payload`에 저장해두면, 이후 CSR 라우트 이동 시 Middleware에서 동일한 IP 값을 별도 API 호출 없이 재사용할 수 있다.

---

##  4. CIDR 기반 IP 대역 체크

---

IP 허용 정책은 단일 IP뿐만 아니라 **IP 대역(CIDR 표기)**으로 관리하는 것이 일반적이다.

**CIDR(Classless Inter-Domain Routing)** 표기법은 `10.0.0.0/8`처럼 IP 주소와 서브넷 마스크 비트 수를 함께 표현한다. `/8`은 앞 8비트가 네트워크 주소이고 나머지 24비트가 호스트 주소임을 의미한다.

CIDR 포함 여부 체크는 **비트마스크 연산**으로 수행한다. IP 문자열을 32bit 정수로 변환한 뒤, 마스크를 적용해 네트워크 주소 부분만 비교한다.

[![image](/assets/images/nuxt3-ip/image5.svg)](/assets/images/nuxt3-ip/image5.svg)

---

##  5. Redis에서 IP 정책 관리

---

IP 허용 대역을 코드나 설정 파일에 하드코딩하면, 변경할 때마다 배포가 필요하다. 이를 **Redis에 공통코드로 관리**하면 서버 재시작 없이 실시간으로 정책을 변경할 수 있다.

### 📌 Redis 저장 구조

```
key:   cmcd:list
value: JSON 배열 문자열

[
  {
    "cmcd": "ipAddr",
    "cmcdVal": "ip허용대역",
    "comCdNm": "10.0.0.0/8, 192.168.1.0/24",
    "useYn": "Y"
  },
  ...
]
```

`comCdNm` 필드에 쉼표로 구분하여 여러 대역을 저장하고, `*` 값은 전체 허용을 의미하는 특수값으로 사용한다. `useYn` 필드로 정책의 활성화 여부를 관리한다.

> 💡
> `RedisTemplate.opsForValue().get(key)`는 Redis String 타입의 값을 조회한다.
> `opsForList().range()`와 달리 키 하나에 값 하나(전체 JSON 문자열)가 저장된 구조이므로, 한 번의 조회로 전체를 가져온 뒤 Java Stream에서 필터링한다.

---

##  6. Spring Boot 구현

---

### 📌 디렉토리 구조

```
src/main/java/
  └── dto/
      ├── CommonCode.java
      └── IpPolicyResponse.java
  └── service/
      └── CommonCodeService.java
  └── controller/
      └── IpPolicyController.java
```

### 📌 CommonCode.java

```java
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class CommonCode {
    private String cmcd;       // 공통코드 구분 (ex: "ipAddr")
    private String cmcdVal;    // 코드값
    private String comCdNm;    // 코드명 (IP 대역이 쉼표로 저장된 필드)
    private String useYn;      // 사용여부 (Y/N)
}
```

### 📌 IpPolicyResponse.java

```java
@Getter
@Builder
public class IpPolicyResponse {
    private boolean allowedAll;          // true면 전체 허용 (*)
    private List<String> allowedRanges;  // 허용 IP 대역 목록
}
```

### 📌 CommonCodeService.java

```java
@Slf4j
@Service
@RequiredArgsConstructor
public class CommonCodeService {

    private static final String REDIS_KEY   = "cmcd:list";
    private static final String TARGET_CMCD = "ipAddr";

    private final RedisTemplate<String, String> redisTemplate;
    private final ObjectMapper objectMapper;

    /**
     * Redis에서 IP 허용 정책 조회
     */
    public IpPolicyResponse getIpPolicy() {
        List<String> ranges = resolveIpRanges();
        return IpPolicyResponse.builder()
                .allowedAll(ranges.contains("*"))
                .allowedRanges(ranges)
                .build();
    }

    private List<String> resolveIpRanges() {
        // opsForValue().get() : Redis String 타입 단일 값 조회
        String raw = redisTemplate.opsForValue().get(REDIS_KEY);

        if (raw == null || raw.isBlank()) {
            log.warn("[IpPolicy] Redis 키 없음 - key: {}", REDIS_KEY);
            return List.of();
        }

        try {
            return objectMapper.readValue(raw, new TypeReference<List<CommonCode>>() {})
                    .stream()
                    // useYn = Y 이고 cmcd = ipAddr 인 항목만 필터
                    .filter(code -> "Y".equalsIgnoreCase(code.getUseYn()) && TARGET_CMCD.equals(code.getCmcd()))
                    .findFirst()
                    .map(code -> parseIpRanges(code.getComCdNm()))
                    .orElseGet(() -> {
                        log.warn("[IpPolicy] cmcd='{}' 항목 없음 또는 useYn=N", TARGET_CMCD);
                        return List.of();
                    });

        } catch (JsonProcessingException e) {
            log.error("[IpPolicy] 파싱 실패 - key: {}", REDIS_KEY, e);
            return List.of();
        }
    }

    /**
     * comCdNm 필드 파싱
     * - "*"  → 전체 허용
     * - "10.0.0.0/8, 192.168.1.0/24" → 리스트로 분리
     */
    private List<String> parseIpRanges(String comCdNm) {
        if (comCdNm == null || comCdNm.isBlank()) return List.of();

        // 전체 허용
        if ("*".equals(comCdNm.trim())) return List.of("*");

        // 쉼표로 분리 후 공백 제거
        return Arrays.stream(comCdNm.split(","))
                .map(String::trim)
                .filter(s -> !s.isBlank())
                .collect(Collectors.toList());
    }
}
```

### 📌 IpPolicyController.java

```java
@Slf4j
@RestController
@RequestMapping("/api/common")
@RequiredArgsConstructor
public class IpPolicyController {

    private final CommonCodeService commonCodeService;

    /**
     * Nuxt 초기 진입 시 IP 허용 정책 조회
     * GET /api/common/ip-policy
     */
    @GetMapping("/ip-policy")
    public ResponseEntity<IpPolicyResponse> getIpPolicy() {
        return ResponseEntity.ok(commonCodeService.getIpPolicy());
    }
}
```

### 📌 API 응답 예시

```json
// comCdNm = "10.0.0.0/8, 192.168.1.0/24" 인 경우
{ "allowedAll": false, "allowedRanges": ["10.0.0.0/8", "192.168.1.0/24"] }

// comCdNm = "*" 인 경우 (전체 허용)
{ "allowedAll": true, "allowedRanges": ["*"] }

// Redis 키 없거나 파싱 실패인 경우 (전체 차단)
{ "allowedAll": false, "allowedRanges": [] }
```

---

##  7. Nuxt3 구현

---

### 📌 디렉토리 구조

```
plugins/
  └── 01.ip-policy.ts          ← 서버 API 호출 & IP 정책 전역 저장
middleware/
  └── ip-guard.global.ts       ← 모든 라우트에서 IP 체크 & 리다이렉트
composables/
  └── useIpPolicy.ts           ← IP 상태 관리 composable
pages/
  └── maintenance.vue          ← 점검 페이지
```

### 📌 composables/useIpPolicy.ts

IP 접근 정책 상태를 전역으로 관리하는 composable이다.

일반 `ref()`는 SSR/CSR 간 상태가 공유되지 않기 때문에 `useState`를 사용한다. `useState`는 서버에서 만든 상태를 클라이언트 hydration 시 그대로 이어받는다.

```typescript
/**
 * IP 접근 정책 상태 인터페이스
 */
interface IpPolicy {
  allowedAll: boolean      // true = 전체 허용 (Redis comCdNm = "*")
  allowedRanges: string[]  // 허용 IP 대역 목록 ex) ["10.0.0.0/8", "192.168.1.0/24"]
  isLoaded: boolean        // 정책 로딩 완료 여부 (미들웨어에서 로딩 전 접근 방지용)
}

/**
 * IP 정책 전역 상태 반환
 * Plugin에서 API 호출 후 이 상태를 채워넣고,
 * Middleware에서 이 상태를 읽어 IP 체크에 활용한다.
 */
export const useIpPolicy = () => {
  return useState<IpPolicy>('ipPolicy', () => ({
    allowedAll: false,
    allowedRanges: [],
    isLoaded: false,
  }))
}

/**
 * 클라이언트 IP가 현재 정책상 허용되는지 종합 판단
 *
 * 판단 순서:
 *  1. 정책이 아직 로딩 안 됐으면 → 차단 (false)
 *  2. allowedAll = true 이면    → 전체 허용 (true)
 *  3. 허용 대역이 비어있으면    → 전체 차단 (false)
 *  4. 하나라도 대역에 포함되면  → 허용 (true)
 */
export const checkIpAllowed = (clientIp: string, policy: IpPolicy): boolean => {
  if (!policy.isLoaded) return false
  if (policy.allowedAll) return true
  if (!policy.allowedRanges.length) return false

  return policy.allowedRanges.some(range => isIpInRange(clientIp, range))
}

/**
 * 단일 IP가 특정 범위(단일 IP 또는 CIDR)에 속하는지 체크
 */
const isIpInRange = (ip: string, range: string): boolean => {
  if (!range?.trim()) return false

  // 단일 IP 비교
  if (!range.includes('/')) return ip === range.trim()

  // CIDR 비트마스크 비교
  try {
    const [rangeIp, bits] = range.split('/')

    /**
     * 비트마스크 계산
     * ex) /8  → mask = 11111111.00000000.00000000.00000000
     *     /24 → mask = 11111111.11111111.11111111.00000000
     *
     * clientIp & mask === rangeIp & mask 이면 같은 네트워크 대역
     */
    const mask     = ~((1 << (32 - parseInt(bits))) - 1)
    const ipNum    = ipToNum(ip)
    const rangeNum = ipToNum(rangeIp)
    return (ipNum & mask) === (rangeNum & mask)
  } catch {
    return false
  }
}

/**
 * IPv4 문자열을 32bit 정수로 변환
 * ex) "10.0.0.1" → 167772161
 *
 * >>> 0 : JavaScript 비트 연산의 부호 있는 정수 처리를
 *         부호 없는 32bit 정수로 강제 변환
 *         (255.x.x.x 같은 큰 IP에서 음수로 처리되는 것을 방지)
 */
const ipToNum = (ip: string): number => {
  return ip.split('.').reduce((acc, octet) => (acc << 8) + parseInt(octet), 0) >>> 0
}
```

### 📌 plugins/01.ip-policy.ts

앱 초기화 시 IP 정책을 서버 API에서 로딩하고 전역 상태에 저장한다.

파일명 앞 `01.`은 여러 플러그인이 있을 때 실행 순서를 보장하기 위한 것이다. ip-policy가 다른 플러그인보다 먼저 실행되어야 미들웨어에서 상태를 사용할 수 있다.

```typescript
/**
 * h3는 Nuxt 내부 서버 엔진(Nitro)이 사용하는 HTTP 프레임워크
 * plugins/ 디렉토리에서는 자동 import가 안되므로 명시적으로 import 필요
 */
import { getRequestHeader } from 'h3'

export default defineNuxtPlugin(async (nuxtApp) => {
  const ipPolicy = useIpPolicy()

  /**
   * [SSR 전용 블록]
   * 서버에서만 실행되는 코드로, 클라이언트 IP를 추출해 payload에 저장
   *
   * payload에 저장하는 이유:
   * - SSR 완료 후 HTML과 함께 클라이언트로 payload 데이터가 전달됨
   * - CSR hydration 시 동일한 payload 값을 꺼내 쓸 수 있음
   *
   * IP 추출 우선순위:
   *  1. X-Real-IP         : nginx에서 직접 세팅한 실제 클라이언트 IP (가장 신뢰)
   *  2. X-Forwarded-For   : 프록시 체인 경유 시 첫 번째 값이 원래 클라이언트 IP
   *  3. remoteAddress     : 위 헤더가 없을 때 TCP 연결의 직접 IP (fallback)
   */
  if (import.meta.server) {
    const event = useRequestEvent()
    if (event) {
      nuxtApp.payload.clientIp =
        getRequestHeader(event, 'x-real-ip') ||
        getRequestHeader(event, 'x-forwarded-for')?.split(',')[0].trim() ||
        event.node.req.socket.remoteAddress ||
        ''
    }
  }

  /**
   * 이미 정책이 로딩된 경우 API 재호출 skip
   *
   * SSR에서 정책을 로딩하고 useState에 저장하면,
   * CSR hydration 시 useState가 서버 상태를 그대로 이어받아 isLoaded = true
   * 따라서 CSR에서 플러그인이 다시 실행되어도 API를 중복 호출하지 않음
   */
  if (ipPolicy.value.isLoaded) return

  try {
    /**
     * Spring Boot API 호출
     * $fetch는 Nuxt 내장 fetch 유틸로 SSR/CSR 환경을 자동으로 처리
     */
    const data = await $fetch<{ allowedAll: boolean; allowedRanges: string[] }>(
      '/api/common/ip-policy'
    )

    ipPolicy.value = {
      allowedAll: data.allowedAll,
      allowedRanges: data.allowedRanges,
      isLoaded: true,
    }

  } catch (e) {
    /**
     * API 호출 실패 시 보수적 차단 정책 적용
     * - 정책을 알 수 없는 상황에서 허용하는 것보다 차단이 더 안전
     * - isLoaded는 true로 설정하여 미들웨어에서 무한 재시도 방지
     */
    console.error('[ip-policy] 정책 로딩 실패:', e)
    ipPolicy.value = { allowedAll: false, allowedRanges: [], isLoaded: true }
  }
})
```

### 📌 middleware/ip-guard.global.ts

모든 라우트 진입 시 IP 허용 여부를 체크하여 비허용 IP를 점검 페이지로 차단한다.

```typescript
/**
 * [Global Middleware]
 * 파일명에 '.global' 접미사를 붙이면 모든 라우트에 자동 적용
 * Plugin 다음, 페이지 렌더링 전에 실행되는 라이프사이클 보장
 */
export default defineNuxtRouteMiddleware((to) => {

  /**
   * 체크 제외 경로 설정
   *
   * /maintenance 를 제외하는 이유:
   * - 점검 페이지 자체에도 미들웨어가 실행되므로
   *   제외하지 않으면 "/maintenance → 차단 → /maintenance → ..." 무한 루프 발생
   *
   * /_nuxt 를 제외하는 이유:
   * - Nuxt의 JS 번들, CSS 등 정적 리소스 요청 경로
   * - 이 경로까지 차단하면 점검 페이지 자체도 스타일/스크립트 로딩 불가
   */
  const EXCLUDED_PATHS = ['/maintenance', '/favicon.ico']
  if (EXCLUDED_PATHS.includes(to.path) || to.path.startsWith('/_nuxt')) return

  // Plugin에서 이미 로딩되어 있으므로 API 재호출 없이 즉시 사용
  const ipPolicy = useIpPolicy()

  /**
   * 정책 미로딩 상태 방어 처리
   * Plugin에서 API 호출이 실패했을 때 보수적으로 점검 페이지로 이동
   */
  if (!ipPolicy.value.isLoaded) return navigateTo('/maintenance')

  // 전체 허용(*) 설정 시 즉시 통과 (이후 IP 체크 로직 실행 불필요)
  if (ipPolicy.value.allowedAll) return

  /**
   * 클라이언트 IP 추출
   *
   * nuxtApp.payload.clientIp를 사용하는 이유:
   * - Plugin에서 서버 측 HTTP 헤더로 추출한 실제 클라이언트 IP
   * - SSR에서 payload에 저장 → 클라이언트 hydration 시 그대로 전달
   * - CSR 라우트 이동 시에도 최초 접속 IP를 그대로 재사용
   */
  const nuxtApp  = useNuxtApp()
  const clientIp = (nuxtApp.payload.clientIp as string) || ''

  // IP 값이 없는 경우 차단 (헤더 파싱 실패, nginx 설정 누락 등)
  if (!clientIp) return navigateTo('/maintenance')

  // CIDR 비트마스크 연산으로 허용 여부 최종 판단
  if (!checkIpAllowed(clientIp, ipPolicy.value)) {
    return navigateTo('/maintenance')
  }

  // 모든 체크를 통과하면 아무것도 반환하지 않음 → 정상적으로 목적지 라우트 진행
})
```

### 📌 pages/maintenance.vue

비허용 IP 접속 시 미들웨어에 의해 강제 이동되는 점검 페이지다.

```vue
<template>
  <div class="wrap">
    <div class="card">
      <p class="icon">🔧</p>
      <h1>서비스 점검 중입니다</h1>
      <p class="desc">
        보다 나은 서비스 제공을 위해 점검을 진행하고 있습니다.<br />
        이용에 불편을 드려 대단히 죄송합니다.
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
/**
 * definePageMeta({ middleware: [] }) 를 설정하는 이유:
 * - global middleware는 기본적으로 모든 페이지에 실행됨
 * - 이 설정으로 이 페이지만 미들웨어 실행 대상에서 제외
 * - EXCLUDED_PATHS 설정과 이중으로 방어
 */
definePageMeta({ middleware: [] })
</script>

<style scoped>
.wrap {
  min-height: 100vh;
  display: flex;
  justify-content: center;
  align-items: center;
  background: #f5f7fa;
}
.card {
  text-align: center;
  padding: 60px 48px;
  background: #fff;
  border-radius: 16px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08);
  max-width: 480px;
  width: 100%;
}
.icon  { font-size: 56px; margin-bottom: 20px; }
h1     { font-size: 24px; font-weight: 700; color: #1a1a2e; margin-bottom: 16px; }
.desc  { font-size: 15px; color: #666; line-height: 1.7; }
</style>
```

---

##  8. 전체 흐름

---

[![image](/assets/images/nuxt3-ip/image6.svg)](/assets/images/nuxt3-ip/image6.svg)

### 📌 비허용 IP 접근 시

```
브라우저 요청 (비허용 IP: 8.8.8.8)
    │
    ▼
[Plugin] payload.clientIp = "8.8.8.8", 정책 로딩 완료
    │
    ▼
[Middleware] checkIpAllowed("8.8.8.8", policy) → false
    │
    ▼
navigateTo('/maintenance') → 점검 페이지 렌더링
```

---

##  9. 주요 트러블슈팅

---

### 📌 getRequestHeader is not defined 오류

`getRequestHeader`는 H3의 유틸 함수인데, `plugins/`나 `middleware/` 파일에서는 자동 import가 되지 않는다. `server/` 디렉토리 내부에서만 자동 import된다.

**해결 방법 1**: `h3`에서 직접 import

```typescript
import { getRequestHeader } from 'h3'
```

**해결 방법 2**: `event.node.req.headers`로 직접 접근

```typescript
const headers = event.node.req.headers
const xRealIp = headers['x-real-ip']
const xForwardedFor = headers['x-forwarded-for']
```

> 💡
> `h3`는 Nuxt가 내부적으로 사용하는 패키지라 별도 설치 없이 바로 사용 가능하다.
> 명시적 import 방식이 타입도 명확하게 잡혀 권장한다.

### 📌 점검 페이지에서 무한 루프

Global Middleware의 `EXCLUDED_PATHS`에 `/maintenance`를 추가하지 않으면 점검 페이지 자체에서도 미들웨어가 실행되어 무한 리다이렉트가 발생한다.

`middleware: []` 설정과 `EXCLUDED_PATHS` 두 가지를 모두 적용하여 이중으로 방어하는 것이 좋다.

---

##  10. 정리

---

이 구현의 핵심은 **역할의 명확한 분리**다.

- **Plugin**: "어떤 IP를 허용할 것인가" 라는 정책 데이터를 API에서 **한 번** 가져오는 역할
- **Middleware**: "이 접속자가 허용된 IP인가" 를 **매 라우트마다** 검사하는 역할

또한 SSR에서 추출한 클라이언트 IP를 `payload`를 통해 CSR로 전달함으로써, 클라이언트 측에서 별도 API 호출 없이도 일관된 IP 체크가 가능하다. Redis에 IP 정책을 관리하면 서버 재시작 없이 `*` 값 하나로 전체 허용 전환, `useYn = N`으로 정책 비활성화 등 **운영 유연성**을 확보할 수 있다.

---

## 참고 자료

- Nuxt3 공식 문서 - Plugins: <https://nuxt.com/docs/3.x/guide/directory-structure/plugins>
- Nuxt3 공식 문서 - Middleware: <https://nuxt.com/docs/guide/directory-structure/middleware>
- Nuxt3 공식 문서 - Nuxt Lifecycle: <https://nuxt.com/docs/4.x/guide/concepts/nuxt-lifecycle>
- Nuxt3 공식 문서 - Server Directory: <https://nuxt.com/docs/4.x/directory-structure/server>
- H3 공식 문서: <https://h3.unjs.io>
- MDN - X-Forwarded-For: <https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Forwarded-For>
- RFC 4632 - CIDR: <https://datatracker.ietf.org/doc/html/rfc4632>
