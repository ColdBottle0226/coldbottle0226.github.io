---
title: "스프링 클라우드 기반 MSA 구성 - Config Server"
date: 2026-04-09 09:50:00 +0900
categories: [Spring, MSA]
tags: [SpringCloud, MSA, ConfigServer, ExternalizedConfiguration, SpringCloudConfig, RefreshScope, GitBackend]
---

## 📗 1. 개요

---

MSA 프로젝트에 서비스가 5개라면, `application.yml` 파일도 5개다. DB 주소가 바뀌거나 Redis 비밀번호가 바뀌면 5개 파일을 모두 수정하고, 서비스를 재배포해야 한다. 서비스가 10개, 20개가 되면 이 작업은 점점 고통스러워진다.

**Spring Cloud Config Server**는 이 문제를 해결하는 **중앙화된 설정 관리 서버**다.

> 💡 Spring Cloud Config 공식 문서는 다음과 같이 설명한다: "Spring Cloud Config provides server-side and client-side support for externalized configuration in a distributed system. With the Config Server, you have a central place to manage external properties for applications across all environments."
> 출처: [docs.spring.io/spring-cloud-config](https://docs.spring.io/spring-cloud-config/reference/index.html)

모든 서비스의 설정을 **하나의 Git 레포지토리**에서 관리하고, Config Server가 이를 각 서비스에 제공한다. 설정이 바뀌어도 서비스를 재배포하지 않고 `@RefreshScope`로 반영할 수 있다.

### 📌 전체 구조

```
Git 레포 (seoul-date-config)
  application.yml          ← 모든 서비스 공통 설정
  user-service/
    application.yml        ← user-service 전용 설정
    application-prod.yml   ← user-service 프로덕션 설정
  place-service/
    application.yml
  ...

         ↑ clone / fetch
  Config Server (8888)
         ↑ 기동 시 설정 요청
  user-service, place-service, recommendation-service, ...
```

### 📌 왜 Git을 백엔드로 쓰는가?

> 공식 문서: "The default implementation of the server storage backend uses git, so it easily supports labelled versions of configuration environments as well as being accessible to a wide range of tooling for managing the content."

Git 백엔드를 쓰면 설정 변경 내역이 커밋 히스토리로 남아 **감사(Audit) 추적**이 가능하고, PR 리뷰로 설정 변경을 통제할 수 있다. 또한 브랜치/태그로 환경(dev/staging/prod)별 설정을 분리할 수 있다.

---

## 📗 2. 핵심 개념

---

### 📌 설정 파일 조회 규칙

Config Server는 다음 URL 패턴으로 설정을 제공한다.

```
/{application}/{profile}[/{label}]
/{application}-{profile}.properties
/{label}/{application}-{profile}.properties
/{application}-{profile}.yml
/{label}/{application}-{profile}.yml
```

- `application`: `spring.application.name` 값
- `profile`: `spring.profiles.active` 값
- `label`: Git 브랜치/태그/커밋 (기본값: `main`)

예를 들어 `user-service`가 `local` 프로파일로 기동되면, Config Server는 다음 순서로 설정을 조합한다.

```
1. application.yml          (모든 서비스 공통)
2. application-local.yml    (local 프로파일 공통)
3. user-service/application.yml         (user-service 전용)
4. user-service/application-local.yml   (user-service local 전용)
```

뒤에 올수록 우선순위가 높다.

### 📌 @RefreshScope — 재배포 없이 설정 반영

`@RefreshScope`가 붙은 Bean은 `/actuator/refresh` 엔드포인트 호출 시 설정을 다시 읽어 재초기화된다.

```java
@RestController
@RefreshScope              // ← 이 Bean은 refresh 시 재초기화됨
@RequiredArgsConstructor
public class SomeController {

    @Value("${feature.recommendation.enabled:true}")
    private boolean recommendationEnabled;  // refresh 후 새 값으로 갱신
}
```

```bash
# 설정 변경 후 재배포 없이 반영
curl -X POST http://recommendation-service:8083/actuator/refresh
```

---

## 📗 3. 서비스 생성 및 기초 설정

---

### 📌 디렉토리 구조

```
services/config-server/
  ├── build.gradle
  ├── settings.gradle
  ├── Dockerfile
  └── src/main/
      ├── java/com/seouldate/config/
      │   └── ConfigServerApplication.java
      └── resources/
          └── application.yml
```

### 📌 build.gradle

```groovy
/**
 * Config Server는 별도의 Spring Boot 애플리케이션이다.
 * spring-cloud-config-server 의존성 하나로 서버가 구성된다.
 *
 * Eureka Client를 추가하면 Config Server 자신도 레지스트리에 등록되어
 * 클라이언트들이 Eureka를 통해 Config Server 주소를 동적으로 조회할 수 있다.
 */
plugins {
    id 'java'
    id 'org.springframework.boot' version '3.2.5'
    id 'io.spring.dependency-management' version '1.1.4'
}

group = 'com.seouldate'
version = '0.0.1-SNAPSHOT'

java {
    sourceCompatibility = JavaVersion.VERSION_21
}

ext {
    set('springCloudVersion', "2023.0.1")
}

dependencies {
    // Config Server 핵심 의존성
    implementation 'org.springframework.cloud:spring-cloud-config-server'
    // Eureka Client (Config Server도 레지스트리에 등록)
    implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'

    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}

dependencyManagement {
    imports {
        mavenBom "org.springframework.cloud:spring-cloud-dependencies:${springCloudVersion}"
    }
}

tasks.named('test') {
    useJUnitPlatform()
}
```

### 📌 ConfigServerApplication.java

```java
package com.seouldate.config;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.config.server.EnableConfigServer;

/**
 * @EnableConfigServer 어노테이션 하나로 이 애플리케이션이
 * Config Server로 동작하게 된다.
 * Eureka Client 의존성이 classpath에 있으면 자동으로 Eureka에도 등록된다.
 */
@SpringBootApplication
@EnableConfigServer
public class ConfigServerApplication {

    public static void main(String[] args) {
        SpringApplication.run(ConfigServerApplication.class, args);
    }
}
```

### 📌 application.yml

```yaml
server:
  port: 8888   # Config Server의 관례적인 기본 포트

spring:
  application:
    name: config-server

  cloud:
    config:
      server:
        git:
          # 설정 전용 private Git 레포지토리 URI
          uri: https://github.com/your-org/seoul-date-config

          # 기본 브랜치
          default-label: main

          # 서비스명 폴더 구조로 설정 파일 탐색
          search-paths: '{application}'

          # 서버 기동 시 레포지토리 미리 클론 (첫 요청 지연 방지)
          clone-on-start: true

          # Private 레포일 경우 인증 설정
          username: ${GIT_USERNAME}
          password: ${GIT_PASSWORD}   # GitHub Personal Access Token

        # 로컬 개발 환경용: Git 대신 로컬 파일 시스템 사용
        # native:
        #   search-locations: file:${user.home}/config-repo/{application}

# Eureka에 Config Server를 등록
eureka:
  client:
    service-url:
      defaultZone: http://eureka-server:8761/eureka/
  instance:
    prefer-ip-address: true

management:
  endpoints:
    web:
      exposure:
        include: health, info, refresh, env
```

> 💡 로컬 개발 초기에는 Git 레포 구성이 번거로울 수 있다. 이럴 때는 `spring.profiles.active: native`와 `native.search-locations`를 사용해 로컬 파일 시스템에서 설정을 읽어오는 방식으로 빠르게 시작할 수 있다.

---

## 📗 4. 설정 레포지토리 구조

---

### 📌 Git 레포 구성

```
seoul-date-config/               ← 설정 전용 private 레포
  application.yml                ← 모든 서비스 공통 설정
  application-local.yml          ← 로컬 프로파일 공통 설정
  application-prod.yml           ← 프로덕션 프로파일 공통 설정

  user-service/
    application.yml              ← user-service 전용
    application-local.yml        ← user-service 로컬 전용
    application-prod.yml         ← user-service 프로덕션 전용

  place-service/
    application.yml
    application-local.yml

  recommendation-service/
    application.yml
    application-local.yml

  ai-service/
    application.yml
    application-local.yml

  seoul-data-service/
    application.yml
    application-local.yml
```

### 📌 공통 application.yml 예시

```yaml
# 모든 서비스에 공통으로 적용되는 설정 (Eureka, Kafka, 로깅 등)
eureka:
  client:
    service-url:
      defaultZone: http://eureka-server:8761/eureka/
  instance:
    prefer-ip-address: true
    lease-renewal-interval-in-seconds: 10
    lease-expiration-duration-in-seconds: 30

spring:
  kafka:
    bootstrap-servers: kafka:9092
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer

management:
  endpoints:
    web:
      exposure:
        include: health, info, metrics, prometheus, refresh
  tracing:
    sampling:
      probability: 1.0

logging:
  level:
    com.seouldate: DEBUG
```

---

## 📗 5. 각 서비스에서 Config Server 연동

---

### 📌 build.gradle에 Config Client 추가

```groovy
dependencies {
    // ...기존 코드

    // Config Client — Config Server에서 설정 가져오기
    implementation 'org.springframework.cloud:spring-cloud-starter-config'
}
```

### 📌 application.yml 변경

Spring Boot 2.x에서는 `bootstrap.yml`에 Config Server 주소를 설정했지만, Spring Boot 3.x에서는 `application.yml`의 `spring.config.import`를 사용한다.

```yaml
# 각 서비스의 application.yml
spring:
  application:
    name: user-service  # Config Server에서 이 이름으로 설정 파일을 찾음

  profiles:
    active: local       # local 프로파일로 기동

  config:
    # optional: 붙이면 Config Server 연결 실패 시에도 기동 가능 (로컬 개발 편의)
    # optional: 없으면 Config Server 연결 실패 시 기동 중단
    import: "optional:configserver:http://config-server:8888"

  cloud:
    config:
      fail-fast: false    # true로 설정하면 Config Server 연결 실패 시 기동 중단
      retry:
        max-attempts: 5
        initial-interval: 1000
```

> 💡 공식 문서에 따르면: "Removing the optional: prefix will cause the Config Client to fail if it is unable to connect to Config Server."

개발 초기에는 `optional:`을 붙여두고, 프로덕션에서는 제거해서 Config Server 연결을 필수로 만드는 것이 좋다.

---

## 📗 6. 설정 조회 테스트

---

Config Server가 올라간 후, curl로 설정이 제대로 제공되는지 확인한다.

```bash
# user-service의 local 프로파일 설정 조회
curl http://localhost:8888/user-service/local

# 응답 예시
{
  "name": "user-service",
  "profiles": ["local"],
  "label": "main",
  "version": "abc1234",
  "propertySources": [
    {
      "name": "https://github.com/your-org/seoul-date-config/user-service/application-local.yml",
      "source": {
        "spring.datasource.url": "jdbc:mysql://mysql-user:3306/user_db",
        "server.port": 8081
      }
    },
    {
      "name": "https://github.com/your-org/seoul-date-config/application.yml",
      "source": {
        "eureka.client.service-url.defaultZone": "http://eureka-server:8761/eureka/"
      }
    }
  ]
}
```

---

## 📗 7. Docker Compose 추가

---

```yaml
  config-server:
    build:
      context: ./services/config-server
      dockerfile: Dockerfile
    container_name: date-config-server
    restart: unless-stopped
    ports:
      - "8888:8888"
    environment:
      GIT_USERNAME: ${GIT_USERNAME}
      GIT_PASSWORD: ${GIT_PASSWORD}
    depends_on:
      eureka-server:
        condition: service_healthy
    networks:
      - date-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8888/actuator/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 40s
```

기동 순서:

```
인프라 (MySQL, Redis, Kafka, ...) → Eureka Server → Config Server → 각 서비스
```

---

## 📗 8. 트러블슈팅

---

### 📌 "Could not resolve placeholder '${...}'"

Config Server에서 설정을 가져왔지만, 특정 속성을 못 찾는 경우다.

원인: Git 레포의 설정 파일 경로가 잘못됐거나, `spring.application.name`이 폴더명과 다르게 설정됐을 수 있다.

해결: `curl http://config-server:8888/{서비스명}/{프로파일}`로 실제 Config Server가 어떤 설정을 내려주는지 확인한다.

### 📌 Config Server 연결 실패로 서비스 기동 불가

```
Could not locate PropertySource: I/O error on GET request for "http://config-server:8888/..."
```

원인: Config Server가 아직 기동 중이거나, 네트워크가 연결되지 않은 상태에서 서비스가 먼저 기동됐다.

해결:

```yaml
spring:
  cloud:
    config:
      fail-fast: true
      retry:
        max-attempts: 6
        initial-interval: 1500
        multiplier: 1.5
        max-interval: 5000
```

재시도 설정을 추가하면 Config Server 기동을 기다리며 최대 6번 재시도한다.

---

## 📗 9. 정리

---

- Config Server는 모든 서비스의 설정을 **Git 레포 한 곳에서 중앙 관리**한다.
- `application.yml`(공통) → `{서비스명}/application.yml`(전용) → `{서비스명}/application-{profile}.yml`(프로파일 전용) 순서로 **우선순위**가 높아진다.
- Spring Boot 3.x에서는 `spring.config.import: "configserver:..."` 방식으로 연동한다.
- `@RefreshScope`와 `/actuator/refresh`를 조합하면 **재배포 없이** 설정 변경을 반영할 수 있다.
- 민감한 정보(비밀번호, API 키)는 Config Server의 **Encrypt/Decrypt 기능**이나 외부 Vault로 관리해야 한다.

---

## 참고 자료

- Spring Cloud Config 공식 문서: <https://docs.spring.io/spring-cloud-config/reference/index.html>
- Spring Cloud Config Server 레퍼런스: <https://docs.spring.io/spring-cloud-config/reference/server.html>
- Spring Cloud Config Client 레퍼런스: <https://docs.spring.io/spring-cloud-config/reference/client.html>
- GitHub - spring-cloud/spring-cloud-config: <https://github.com/spring-cloud/spring-cloud-config>
- Baeldung - Spring Cloud Configuration: <https://www.baeldung.com/spring-cloud-configuration>
