---
title: "스프링 클라우드 기반 MSA 구성 - Circuit Breaker"
date: 2026-04-09 09:40:00 +0900
categories: [Spring, MSA]
order: 4
tags: [SpringCloud, MSA, CircuitBreaker, Resilience4j, Fallback, CascadeFailure, FeignClient]
---

##  1. 개요

---

MSA에서는 서비스들이 서로 HTTP 호출로 연결되어 있다. 만약 `ai-service`가 다운됐는데 `recommendation-service`가 계속 ai-service를 호출한다면 어떤 일이 벌어질까?

호출 스레드가 타임아웃을 기다리며 쌓이고, 결국 스레드 풀이 고갈되어 recommendation-service까지 죽는다. 이 현상을 **Cascade Failure(연쇄 장애)**라고 한다.

**Circuit Breaker(서킷 브레이커)**는 이 문제를 막는 패턴이다. 마치 전기 회로의 차단기처럼, 장애가 감지되면 즉시 요청을 차단하고 **Fallback(대체 응답)**을 반환한다.

> 💡 Chris Richardson의 책 "Microservice Patterns"에서는 이렇게 설명한다: "A service client should invoke a remote service via a proxy that functions in a similar fashion to an electrical circuit breaker."

Spring Cloud는 Circuit Breaker의 공식 추상화 레이어로 **Spring Cloud CircuitBreaker** 프로젝트를 제공하며, 구현체로 **Resilience4j**를 권장한다.

> "The Spring Cloud Circuit Breaker project solves this. It provides an abstraction layer across different circuit breaker implementations."
> 출처: [spring.io/projects/spring-cloud-circuitbreaker](https://spring.io/projects/spring-cloud-circuitbreaker/)

### 📌 Hystrix vs Resilience4j

과거에는 Netflix Hystrix를 사용했지만, Spring Cloud 2020.0부터 Hystrix가 제거됐다.

| 구분 | Netflix Hystrix | Resilience4j |
|---|---|---|
| 유지보수 | Netflix (deprecated) | 활발히 개발 중 |
| Spring Boot 3 지원 | ❌ | ✅ |
| Java 8 함수형 지원 | 제한적 | ✅ (FP 스타일) |
| 스레드 모델 | ThreadPool 기반 | Semaphore / ThreadPool 선택 가능 |
| 모듈 분리 | 단일 패키지 | CB, Retry, RateLimit, Bulkhead 분리 |

---

##  2. 핵심 개념 — 상태 전이

---

### 📌 Circuit Breaker 상태 머신

> Resilience4j 공식 문서: "The CircuitBreaker is implemented via a finite state machine with three normal states: CLOSED, OPEN and HALF_OPEN."

```
                실패율 > 임계값
[CLOSED] ─────────────────────────▶ [OPEN]
(정상 운영)                          (즉시 차단)
    ▲                                    │
    │ 성공                               │ 대기 시간 경과
    │                                    ▼
    └──────────────────────── [HALF_OPEN]
         성공률 ≥ 임계값              (테스트 중)
```

| 상태 | 동작 |
|---|---|
| **CLOSED** | 정상 상태. 모든 요청을 통과시키고 결과를 슬라이딩 윈도우에 기록 |
| **OPEN** | 차단 상태. 모든 요청을 즉시 `CallNotPermittedException`으로 거부하고 Fallback 실행 |
| **HALF_OPEN** | 복구 테스트 상태. 설정한 수만큼의 요청을 테스트로 허용. 성공 → CLOSED, 실패 → OPEN |

### 📌 슬라이딩 윈도우 (Sliding Window)

Circuit Breaker가 실패율을 계산하는 방식이다. 두 가지 타입이 있다.

- **COUNT_BASED**: 최근 N번의 호출 결과를 기준으로 실패율 계산
- **TIME_BASED**: 최근 N초 동안의 호출 결과를 기준으로 실패율 계산

예를 들어 `slidingWindowSize: 10`에 `failureRateThreshold: 50`이면, 최근 10번 중 5번 이상 실패하면 OPEN 상태로 전환된다. 단, 최소 호출 수(`minimumNumberOfCalls`)에 도달해야 실패율이 계산된다.

---

##  3. 설정 — api-gateway 기준

---

### 📌 build.gradle

```groovy
/**
 * Gateway는 WebFlux(비동기) 기반이라 일반 resilience4j 대신
 * Reactor 전용 구현체(reactor-resilience4j)가 필요하다.
 * recommendation-service 같은 일반 서비스는 non-reactive 스타터를 쓴다.
 */
dependencies {
    // Gateway용 — Reactor 전용 Circuit Breaker
    implementation 'org.springframework.cloud:spring-cloud-starter-circuitbreaker-reactor-resilience4j'

    // 일반 서비스용 (recommendation-service 등)
    implementation 'org.springframework.cloud:spring-cloud-starter-circuitbreaker-resilience4j'

    // Actuator (CB 상태 엔드포인트 노출)
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
}
```

### 📌 application.yml — 전체 CB 설정 분석

```yaml
resilience4j:
  circuitbreaker:
    configs:
      # 모든 CB 인스턴스의 공통 기본값
      default:
        sliding-window-type: COUNT_BASED    # 최근 N개 요청 기준
        sliding-window-size: 10             # 최근 10개 요청 분석
        failure-rate-threshold: 50          # 50% 이상 실패 시 OPEN
        minimum-number-of-calls: 5          # 실패율 계산 최소 호출 수
        wait-duration-in-open-state: 10s    # OPEN 유지 시간
        permitted-number-of-calls-in-half-open-state: 3  # HALF_OPEN에서 허용 수
        slow-call-rate-threshold: 80        # 느린 호출이 80% 초과 시도 OPEN
        slow-call-duration-threshold: 5s    # 5초 이상 = 느린 호출
        register-health-indicator: true     # Actuator에 CB 상태 노출
        record-exceptions:                  # 실패로 기록할 예외
          - java.io.IOException
          - java.util.concurrent.TimeoutException
          - org.springframework.cloud.gateway.support.NotFoundException
        ignore-exceptions:                  # 실패 카운트 제외 예외
          - com.seouldate.gateway.exception.ClientException
```

**`ignore-exceptions: ClientException`을 설정하는 이유**

`401 Unauthorized`, `404 Not Found` 같은 클라이언트 4xx 오류는 서비스 장애가 아니다. 클라이언트가 잘못된 토큰을 보낸 것이다. 이를 CB 실패 카운트에 포함시키면 서비스가 멀쩡한데 CB가 OPEN이 되는 **오탐**이 발생한다.

**`slow-call` 설정을 쓰는 이유**

서비스가 죽지는 않았지만 극도로 느린 경우도 장애로 간주해야 한다. 5초 이상 걸리는 응답이 80%를 초과하면 실패율과 동일하게 OPEN 상태로 전환된다.

### 📌 서비스별 CB 인스턴스 차별화

서비스 특성에 따라 CB 설정을 다르게 잡는다.

```yaml
resilience4j:
  circuitbreaker:
    instances:
      # userCB: 기본값 그대로 사용
      userCB:
        base-config: default

      # recCB: 추천 서비스 — 복잡한 처리라 복구 대기를 길게
      recCB:
        base-config: default
        wait-duration-in-open-state: 15s  # 10s → 15s
        permitted-number-of-calls-in-half-open-state: 2

      # aiCB: AI 서비스 — 비용 문제로 가장 엄격하게
      aiCB:
        base-config: default
        sliding-window-size: 5            # 5개만 봄 (LLM 비용 문제)
        failure-rate-threshold: 40        # 40% 실패해도 OPEN (더 민감)
        wait-duration-in-open-state: 30s  # 30초 차단 (LLM 복구 시간 필요)
        permitted-number-of-calls-in-half-open-state: 1  # 1개만 탐색

      # seoulDataCB: 공공 API — 간헐적 실패 잦아서 덜 엄격하게
      seoulDataCB:
        base-config: default
        failure-rate-threshold: 60
        wait-duration-in-open-state: 20s
```

| CB 인스턴스 | slidingWindowSize | failureRate | waitDuration | 이유 |
|---|---|---|---|---|
| userCB | 10 | 50% | 10s | 기본 |
| recCB | 10 | 50% | 15s | 복잡한 처리, 복구 대기 길게 |
| aiCB | 5 | 40% | 30s | LLM 비용·복구 시간 고려 |
| seoulDataCB | 10 | 60% | 20s | 공공 API 간헐적 실패 허용 |

### 📌 TimeLimiter — CB와 함께 동작

```yaml
resilience4j:
  timelimiter:
    configs:
      default:
        cancel-running-future: true   # 타임아웃 시 진행 중 요청 강제 취소
    instances:
      userCB:      timeout-duration: 5s
      placeCB:     timeout-duration: 3s
      recCB:       timeout-duration: 10s
      aiCB:        timeout-duration: 30s   # LLM 호출 최대 허용 시간
      seoulDataCB: timeout-duration: 5s
```

**TimeLimiter → CB 연동 흐름**

CB 인스턴스와 같은 이름을 공유한다. 타임아웃 발생 시 `TimeoutException`이 CB의 `record-exceptions`에 포함되어 실패 카운트로 누적된다.

```
요청 → place-service 전달
  │
  │ 3초 후 응답 없음
  │
  ▼
TimeLimiter: "타임아웃! TimeoutException 발생"
  │
  ▼
CircuitBreaker: "TimeoutException = record-exceptions에 포함 → 실패 카운트 +1"
  │
  ▼
(실패 5/10 = 50% 도달) → OPEN 전환
```

---

##  4. Fallback Controller

---

CB가 OPEN 상태이면 `fallbackUri: forward:/fallback/user`로 리다이렉트된다.

```java
/**
 * forward:/fallback/user는 Gateway 내부에서 포워딩한다.
 * 다운스트림 서비스에는 아예 요청이 가지 않으므로 추가 부하가 없다.
 */
@RestController
@RequestMapping("/fallback")
public class FallbackController {

    @GetMapping("/user")
    public ResponseEntity<Map<String, Object>> userFallback() {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(Map.of(
                        "error", "User Service Unavailable",
                        "message", "서비스가 일시적으로 불가합니다. 잠시 후 다시 시도해주세요.",
                        "timestamp", LocalDateTime.now()
                ));
    }

    @GetMapping("/ai")
    public ResponseEntity<Map<String, Object>> aiFallback() {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(Map.of(
                        "error", "AI Service Unavailable",
                        "message", "AI 서비스가 일시적으로 불가합니다.",
                        "timestamp", LocalDateTime.now()
                ));
    }
    // /fallback/place, /fallback/recommendation, /fallback/seoul-data 동일
}
```

---

##  5. Gateway CB vs 서비스 내부 CB — 2중 구조

---

Gateway에만 CB를 두는 것이 아니라, **서비스 내부에도 CB를 추가**해 독립적으로 장애를 격리할 수 있다.

```
클라이언트
  │
  ▼
[Gateway CB: recCB]           ← recommendation-service 전체 장애 감지
  │
  ▼
[recommendation-service]
  │
  ├─▶ [OpenFeign + aiCB]      ← ai-service만 느릴 때 독립 차단
  │       ai-service
  │
  └─▶ [OpenFeign + placeCB]   ← place-service만 장애일 때 독립 차단
          place-service
```

이렇게 2중 CB를 두면 ai-service만 느려도 recommendation-service 전체가 멈추지 않는다. Gateway CB는 서비스 전체 장애를, 서비스 내 CB는 개별 의존 서비스 장애를 각각 담당한다.

```yaml
# recommendation-service/application.yml
feign:
  circuitbreaker:
    enabled: true   # OpenFeign 호출에 CB 자동 적용

resilience4j:
  circuitbreaker:
    instances:
      place-service:
        sliding-window-size: 10
        failure-rate-threshold: 50
        wait-duration-in-open-state: 10s
      ai-service:
        sliding-window-size: 10
        failure-rate-threshold: 50
        wait-duration-in-open-state: 10s
  timelimiter:
    instances:
      ai-service:
        timeout-duration: 10s   # AI 호출 10초 제한
```

---

##  6. Eureka Heartbeat ↔ Circuit Breaker 관계

---

Eureka와 CB는 독립적으로 동작하지만 서로 보완한다.

**서비스 갑자기 크래시 시 각각의 동작**

```
T=0s   : user-service 크래시 (OOM)

[Eureka 시점]
T=0~30s : 아직 하트비트 만료 안 됨
           → Eureka 레지스트리에 여전히 user-service 존재
           → Gateway가 lb://user-service 요청 시 죽은 인스턴스로 연결 시도

[Circuit Breaker 시점]
T=0s    : 연결 실패 → IOException → CB 실패 카운트 +1
T=0s    : 연결 실패 → IOException → CB 실패 카운트 +1
...
T=몇초  : 10개 중 5개 실패 → CB OPEN
           → 이후 요청은 Eureka 조회 없이 즉시 Fallback으로 응답

[Eureka 정리 시점]
T=30s   : 하트비트 만료 → Eureka 레지스트리에서 user-service 제거
T=35s   : eviction-interval-timer(5초) 체크 → 완전 삭제
```

| 항목 | Eureka 하트비트 | Circuit Breaker |
|---|---|---|
| 감지 방식 | 하트비트 수신 여부 | 실제 요청 성공/실패 |
| 감지 속도 | 30초(만료) + 5초(정리) | 실패 5~10번 직후 (수초 내) |
| 역할 | 서비스 등록/제거 | 실패 요청 즉시 차단 |
| 장애 시 | 30초 후 목록 제거 | 수초 내 Fallback 응답 |

> 💡 CB가 Eureka보다 훨씬 빠르게 반응한다. Eureka가 서비스를 목록에서 제거하기 전 30초 동안도, CB는 수초 만에 장애를 감지하고 Fallback을 제공해 클라이언트를 보호한다.

**Eureka NotFoundException → CB 연동**

```yaml
record-exceptions:
  - org.springframework.cloud.gateway.support.NotFoundException
```

```
Eureka에서 user-service 인스턴스 제거
  │
  ▼
lb://user-service 요청 → 인스턴스 목록 없음
  │
  ▼
NotFoundException 발생
  │
  ▼
CB record-exceptions에 포함 → 실패 카운트 +1
  │ (누적되면)
  ▼
CB OPEN → Fallback 응답
```

이렇게 Eureka가 서비스를 제거한 이후에도 CB가 빠르게 Fallback을 제공해서 클라이언트는 빠른 에러 응답을 받는다.

---

##  7. ai-service 장애 — 전체 타임라인

---

실제 장애 상황을 타임라인으로 살펴보면 CB의 동작 방식을 이해하기 쉽다.

```
T=0s   : ai-service 과부하로 응답 지연 시작

[ai-service TimeLimiter: 30s]
T=30s  : 30초 초과 → TimeoutException

[aiCB — Gateway, sliding-window-size: 5, failure-rate-threshold: 40%]
실패1/5 = 20% → CLOSED
실패2/5 = 40% → OPEN! (임계치 도달)

T=30s~60s: /api/ai/** 요청 → aiCB OPEN → 즉시 Fallback 응답
           {"error": "AI Service Unavailable", ...}

[aiCB HALF_OPEN]
T=60s  : wait-duration 30초 경과 → HALF_OPEN
         1개 요청만 ai-service로 전달 (permitted: 1)
         성공 → CLOSED 복귀
         실패 → OPEN 재전환 (30초 더 대기)

[recommendation-service 내부 aiCB]
timeout-duration: 10s
→ ai-service 10초 응답 없으면 → Fallback 메서드 실행
→ recommendation-service는 AI 추천 없이 기본 추천 응답 제공 가능
```

---

##  8. FeignClient에 Circuit Breaker 적용

---

```yaml
spring:
  cloud:
    openfeign:
      circuitbreaker:
        enabled: true   # FeignClient에 CB 자동 적용
```

```java
/**
 * fallbackFactory를 사용하면 어떤 예외가 발생했는지 fallback 메서드에서 알 수 있다.
 * 단순 fallback(fallback = ...) 방식은 예외 정보를 받을 수 없다.
 */
@FeignClient(
    name = "place-service",
    fallbackFactory = PlaceServiceClientFallbackFactory.class
)
public interface PlaceServiceClient {

    @GetMapping("/places/{placeId}")
    PlaceResponse getPlace(@PathVariable Long placeId);

    @GetMapping("/places/batch")
    List<PlaceResponse> getPlaces(@RequestParam List<Long> ids);
}
```

```java
/**
 * FallbackFactory는 CB가 OPEN 상태일 때 또는 예외 발생 시 호출된다.
 * cause 파라미터로 어떤 예외인지 확인해 로깅하거나 다르게 처리할 수 있다.
 */
@Component
@Slf4j
public class PlaceServiceClientFallbackFactory
        implements FallbackFactory<PlaceServiceClient> {

    @Override
    public PlaceServiceClient create(Throwable cause) {
        return new PlaceServiceClient() {

            @Override
            public PlaceResponse getPlace(Long placeId) {
                log.warn("[CircuitBreaker] place-service 장애. placeId={}, cause={}",
                    placeId, cause.getMessage());
                return PlaceResponse.empty(placeId);
            }

            @Override
            public List<PlaceResponse> getPlaces(List<Long> ids) {
                log.warn("[CircuitBreaker] place-service batch 장애. count={}", ids.size());
                return Collections.emptyList();
            }
        };
    }
}
```

---

##  9. Actuator로 CB 상태 모니터링

---

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, info, metrics, gateway, circuitbreakers, prometheus
```

```bash
# CB 상태 조회 (Gateway 기준)
GET http://localhost:8080/actuator/circuitbreakers
```

```json
{
  "circuitBreakers": {
    "userCB":  { "state": "CLOSED", "failureRate": "10.0%" },
    "aiCB":    { "state": "OPEN",   "failureRate": "80.0%" },
    "placeCB": { "state": "CLOSED", "failureRate": "0.0%"  }
  }
}
```

`aiCB`가 OPEN 상태라면 `/api/ai/**` 요청이 즉시 차단되고 Fallback이 동작 중임을 의미한다.

```bash
# Gateway 라우팅 정보 확인
GET http://localhost:8080/actuator/gateway/routes
```

---

##  10. Resilience4j Aspect 실행 순서

---

Resilience4j는 여러 패턴을 함께 적용할 수 있다. 기본 실행 순서는 다음과 같다.

```
Retry
  └─ CircuitBreaker
       └─ RateLimiter
            └─ TimeLimiter
                 └─ Bulkhead
                      └─ 실제 메서드 호출
```

Retry가 가장 바깥 레이어다. CircuitBreaker가 OPEN 상태여서 `CallNotPermittedException`이 발생하면, Retry가 이를 캐치해 재시도한다. 이 순서를 이해하지 못하면 예상치 못한 동작이 발생할 수 있다.

---

##  11. 트러블슈팅

---

### 📌 Fallback이 호출되지 않음

원인: `spring.cloud.openfeign.circuitbreaker.enabled: true` 설정이 누락됐거나, FeignClient의 `name`이 Resilience4j 인스턴스 키와 다를 수 있다.

해결:
1. `spring.cloud.openfeign.circuitbreaker.enabled: true` 설정 확인
2. `@FeignClient(name = "place-service")`와 `resilience4j.circuitbreaker.instances.place-service` 이름 일치 확인

### 📌 "CallNotPermittedException" 자체가 Retry를 유발함

Retry의 `retry-exceptions`에 `CallNotPermittedException`이 포함되면 OPEN 상태에서도 계속 재시도하게 된다.

해결:

```yaml
resilience4j:
  retry:
    instances:
      ai-service:
        ignore-exceptions:
          - io.github.resilience4j.circuitbreaker.CallNotPermittedException
```

---

##  12. 정리

---

- Circuit Breaker는 **Cascade Failure(연쇄 장애)**를 막는 필수 패턴이다.
- CLOSED → OPEN → HALF_OPEN → CLOSED의 **상태 전이**로 장애 격리와 자동 복구를 처리한다.
- Spring Boot 3.x에서는 Hystrix 대신 **Resilience4j**를 사용해야 한다.
- `ignore-exceptions`에 `ClientException(4xx)`을 등록하면 **오탐을 방지**할 수 있다.
- `slow-call` 설정으로 죽지는 않았지만 **극도로 느린 서비스도 장애로 간주**한다.
- **Gateway CB + 서비스 내부 CB 2중 구조**로 개별 의존 서비스 장애를 독립적으로 격리한다.
- **Eureka(30초) vs CB(수초)** — CB가 훨씬 빠르게 장애를 감지하고 Fallback을 제공한다.

---

## 참고 자료

- Resilience4j 공식 문서 - CircuitBreaker: <https://resilience4j.readme.io/docs/circuitbreaker>
- Spring Cloud CircuitBreaker 공식 문서: <https://docs.spring.io/spring-cloud-circuitbreaker/docs/current/reference/html/>
- Resilience4j Spring Boot 설정 문서: <https://resilience4j.readme.io/docs/getting-started-3>
- Baeldung - Quick Guide to Spring Cloud Circuit Breaker: <https://www.baeldung.com/spring-cloud-circuit-breaker>
