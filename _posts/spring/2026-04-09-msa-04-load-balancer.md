---
title: "스프링 클라우드 기반 MSA 구성 - Load Balancer"
date: 2026-04-09 09:30:00 +0900
categories: [Spring, MSA]
tags: [SpringCloud, MSA, LoadBalancer, SpringCloudLoadBalancer, Ribbon, FeignClient, ClientSideLB]
---

## 📗 1. 개요

---

서비스가 스케일 아웃되면 동일한 서비스의 인스턴스가 여러 개 뜬다. `place-service`가 3개 떠 있다면, `recommendation-service`는 어떤 인스턴스로 요청을 보내야 할까?

이 역할을 **Load Balancer(로드 밸런서)**가 담당한다. 여러 인스턴스에 요청을 고르게 분산시켜 특정 인스턴스에 부하가 집중되지 않도록 한다.

### 📌 Server-Side LB vs Client-Side LB

| 구분 | Server-Side LB | Client-Side LB |
|---|---|---|
| 방식 | 중앙 LB 장비/서버가 분배 결정 | **클라이언트(서비스) 자신이** 분배 결정 |
| 예시 | AWS ALB, Nginx, HAProxy | Spring Cloud LoadBalancer, Ribbon |
| 장점 | 클라이언트가 신경 안 써도 됨 | 별도 LB 서버 불필요, 레이턴시 낮음 |
| 단점 | LB 서버가 단일 장애점, 네트워크 홉 추가 | 클라이언트가 서비스 목록을 알아야 함 |

Spring Cloud는 **Client-Side LB**를 사용한다. Eureka에서 조회한 인스턴스 목록을 클라이언트가 직접 들고 있다가, 요청 시 내부에서 분배 결정을 내린다.

### 📌 Ribbon → Spring Cloud LoadBalancer

과거 Spring Cloud는 Netflix Ribbon을 기본 로드 밸런서로 사용했다. 하지만 Netflix가 Ribbon을 공식 deprecated 처리했고, Spring Cloud도 2020년 이후 Ribbon을 제거하고 **Spring Cloud LoadBalancer**를 공식 대체재로 채택했다.

> 출처: [DZone - Spring Cloud LoadBalancer vs Netflix Ribbon](https://dzone.com/articles/spring-cloud-load-balancer-vs-netflix-ribbon)

| 구분 | Netflix Ribbon | Spring Cloud LoadBalancer |
|---|---|---|
| 유지보수 주체 | Netflix (deprecated) | Spring 팀 (현재 활발히 개발 중) |
| Spring Boot 3 호환 | ❌ | ✅ |
| Reactive 지원 | 제한적 | ✅ (WebFlux 네이티브) |
| 기본 알고리즘 | 다양 (RoundRobin, WeightedResponseTime 등) | RoundRobin, Random |
| Caffeine 캐시 통합 | ❌ | ✅ |

---

## 📗 2. 핵심 개념

---

### 📌 동작 원리

```
recommendation-service가 place-service 호출 시

1. FeignClient (name="place-service")
     ↓ 인스턴스 목록 요청
2. Spring Cloud LoadBalancer
     ↓ 로컬 캐시에서 place-service 인스턴스 목록 조회
     → [172.17.0.5:8082, 172.17.0.6:8082, 172.17.0.7:8082]
     ↓ RoundRobin으로 인스턴스 선택
     → 172.17.0.6:8082
3. 실제 HTTP 요청: http://172.17.0.6:8082/places/123
```

### 📌 ServiceInstanceListSupplier

Spring Cloud LoadBalancer의 핵심 인터페이스다. 어떤 인스턴스 목록을 LB에 제공할지 결정한다.

공식 문서에서 설명하는 주요 구현체:

| 구현체 | 설명 |
|---|---|
| `DiscoveryClientServiceInstanceListSupplier` | Eureka 등 DiscoveryClient에서 인스턴스 목록 조회 |
| `CachingServiceInstanceListSupplier` | 인스턴스 목록을 로컬에 캐싱 (Caffeine 사용) |
| `HealthCheckServiceInstanceListSupplier` | 헬스체크를 통과한 인스턴스만 사용 |
| `SameInstancePreferenceServiceInstanceListSupplier` | 이전에 성공한 인스턴스를 우선 선택 |

### 📌 기본 로드 밸런싱 알고리즘

Spring Cloud LoadBalancer가 제공하는 기본 알고리즘은 두 가지다.

- **RoundRobinLoadBalancer** (기본): 인스턴스를 순서대로 돌아가며 선택
- **RandomLoadBalancer**: 인스턴스를 무작위로 선택

---

## 📗 3. 설정

---

### 📌 build.gradle

```groovy
/**
 * spring-cloud-starter-loadbalancer는 Spring Cloud LoadBalancer와
 * Caffeine 캐시를 포함한 통합 스타터다.
 *
 * FeignClient와 함께 사용하려면 openfeign도 같이 추가한다.
 * Caffeine은 인스턴스 목록 캐시 성능을 향상시킨다.
 */
dependencies {
    // ...기존 코드

    implementation 'org.springframework.cloud:spring-cloud-starter-loadbalancer'
    implementation 'org.springframework.cloud:spring-cloud-starter-openfeign'

    // LoadBalancer 캐시 성능 향상 (없어도 동작하지만, 있으면 Caffeine 캐시 자동 사용)
    implementation 'com.github.ben-manes.caffeine:caffeine'
}
```

### 📌 application.yml

```yaml
spring:
  cloud:
    loadbalancer:
      # Ribbon이 classpath에 있다면 비활성화 (Spring Boot 2.x 마이그레이션 시)
      ribbon:
        enabled: false

      # 인스턴스 목록 로컬 캐싱 설정
      cache:
        enabled: true
        ttl: 30s         # 캐시 유효 시간
        capacity: 256    # 최대 캐시 항목 수

      # 헬스체크 통과한 인스턴스만 LB 목록에 포함
      health-check:
        initial-delay: 0
        interval: 25s
```

### 📌 FeignClient와 연동

FeignClient는 `name`에 명시한 서비스명을 Spring Cloud LoadBalancer에 위임해서 실제 인스턴스 주소를 해석한다. IP를 직접 쓰지 않는다.

```java
/**
 * @FeignClient의 name은 Eureka에 등록된 서비스명과 일치해야 한다.
 * Spring Cloud LoadBalancer가 자동으로 Eureka 레지스트리를 조회해
 * 실제 인스턴스 IP:Port로 변환한다.
 *
 * FeignClient 활성화를 위해 메인 클래스에 @EnableFeignClients가 필요하다.
 */
@FeignClient(name = "place-service")
public interface PlaceServiceClient {

    @GetMapping("/places/{placeId}")
    PlaceResponse getPlace(@PathVariable Long placeId);

    @GetMapping("/places/batch")
    List<PlaceResponse> getPlaces(@RequestParam List<Long> ids);
}
```

```java
// 메인 클래스에 추가
@SpringBootApplication
@EnableFeignClients  // FeignClient 스캔 활성화
public class RecommendationServiceApplication {
    ...
}
```

### 📌 @LoadBalanced RestTemplate

FeignClient 대신 RestTemplate를 사용한다면 `@LoadBalanced` 어노테이션을 붙이면 된다.

```java
/**
 * @LoadBalanced 어노테이션을 붙인 RestTemplate은
 * http://서비스명/경로 형식의 URL을 실제 IP:Port로 자동 변환한다.
 * Ribbon이 deprecated됐으므로 Spring Cloud LoadBalancer가 대신 처리한다.
 */
@Configuration
public class RestTemplateConfig {

    @Bean
    @LoadBalanced
    public RestTemplate restTemplate() {
        return new RestTemplate();
    }
}

// 사용 예시
@Service
@RequiredArgsConstructor
public class SomeService {

    private final RestTemplate restTemplate;

    public PlaceResponse getPlace(Long placeId) {
        // "place-service"는 IP가 아닌 Eureka 서비스명
        return restTemplate.getForObject(
            "http://place-service/places/" + placeId,
            PlaceResponse.class
        );
    }
}
```

---

## 📗 4. 커스텀 로드 밸런싱 알고리즘

---

기본 RoundRobin 외에 커스텀 알고리즘이 필요한 경우 `ReactorServiceInstanceLoadBalancer`를 구현한다.

```java
/**
 * place-service에 대해 Random 로드 밸런싱을 적용하는 예시.
 * 서비스별로 다른 알고리즘을 적용하고 싶을 때 사용한다.
 *
 * @LoadBalancerClient는 특정 서비스에만 설정을 적용한다.
 * @LoadBalancerClients는 여러 서비스에 동시에 설정을 적용한다.
 */
@Configuration
@LoadBalancerClient(name = "place-service", configuration = PlaceLBConfig.class)
public class PlaceLBConfig {

    @Bean
    public ReactorLoadBalancer<ServiceInstance> randomLoadBalancer(
            Environment environment,
            LoadBalancerClientFactory factory) {
        String name = environment.getProperty(LoadBalancerClientFactory.PROPERTY_NAME);
        return new RandomLoadBalancer(
            factory.getLazyProvider(name, ServiceInstanceListSupplier.class),
            name
        );
    }
}
```

---

## 📗 5. 트러블슈팅

---

### 📌 "No instances available for place-service"

LoadBalancer가 Eureka에서 인스턴스 목록을 가져왔지만 사용 가능한 인스턴스가 없을 때 발생한다.

원인 및 해결:

1. Eureka 대시보드(`http://localhost:8761`)에서 해당 서비스가 UP 상태인지 확인
2. Eureka Client 캐시가 갱신되지 않았을 수 있음 → `registry-fetch-interval-seconds`를 줄임
3. 헬스체크가 실패해서 인스턴스가 제외됐을 수 있음 → `/actuator/health` 직접 확인

### 📌 Ribbon과 Spring Cloud LoadBalancer 충돌

Spring Boot 2.x 프로젝트를 3.x로 마이그레이션할 때 발생할 수 있다.

```yaml
spring:
  cloud:
    loadbalancer:
      ribbon:
        enabled: false   # Ribbon 완전 비활성화
```

---

## 📗 6. 정리

---

- Spring Cloud LoadBalancer는 **Netflix Ribbon의 공식 대체재**로, Spring Boot 3.x 환경에서 사용해야 한다.
- `lb://서비스명` 또는 `@FeignClient(name="서비스명")` 형식으로 Eureka + LB 연동이 **자동으로** 이뤄진다.
- 기본 알고리즘은 **RoundRobin**이며, 서비스별로 커스텀 알고리즘을 적용할 수 있다.
- Caffeine 캐시를 함께 쓰면 인스턴스 목록 조회 성능이 향상된다.
- `@LoadBalanced` RestTemplate 또는 FeignClient 중 하나를 선택해서 사용하면 된다.

---

## 참고 자료

- Spring Cloud LoadBalancer 공식 문서: <https://docs.spring.io/spring-cloud-commons/docs/current/reference/html/#spring-cloud-loadbalancer>
- Spring Blog - Spring Tips: Spring Cloud Loadbalancer: <https://spring.io/blog/2020/03/25/spring-tips-spring-cloud-loadbalancer/>
- DZone - Spring Cloud LoadBalancer vs Netflix Ribbon: <https://dzone.com/articles/spring-cloud-load-balancer-vs-netflix-ribbon>
- Piotr's TechBlog - A Deep Dive Into Spring Cloud Load Balancer: <https://piotrminkowski.com/2020/05/13/a-deep-dive-into-spring-cloud-load-balancer/>
