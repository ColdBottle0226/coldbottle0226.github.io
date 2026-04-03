---
title: "[Spring Batch] 도메인 언어 완전 정복 (1) — Job, JobInstance, JobExecution"
date: 2026-03-13 09:00:00 +0900
categories: [Spring, Batch]
tags: [SpringBatch, Job, JobInstance, JobExecution, JobParameters, BatchDomain]
---

## 📗 1. 개요

---

Spring Batch를 처음 접하면 Job, JobInstance, JobExecution이 헷갈린다. 이름이 비슷하고 계층 구조도 명확하게 보이지 않기 때문이다. 이번 글에서는 Spring Batch 공식 문서(6.0 기준)를 바탕으로 Job 계층의 도메인 개념을 전부 정리한다.

> 💡 Spring Batch는 수십 년간 메인프레임(COBOL), Unix(C), Java 환경에서 검증된 배치 아키텍처를 물리적으로 구현한 프레임워크다. 도메인 언어를 이해하면 이 구조가 왜 이렇게 설계됐는지 자연스럽게 납득이 된다.

### 📌 전체 구조 한눈에 보기

아래 다이어그램은 Spring Batch의 전체 도메인 구조를 보여준다. Job이 여러 Step을 포함하고, 실행 추적 계층(JobInstance → JobExecution → StepExecution)이 JobRepository를 통해 영속화된다.

[![image](/assets/images/spring-batch/architecture-overview.svg)](/assets/images/spring-batch/architecture-overview.svg)

| 개념 | 한 줄 정의 |
|---|---|
| `Job` | 전체 배치 프로세스의 설계도. Step들의 컨테이너 |
| `JobInstance` | Job을 "언제, 어떤 파라미터로" 실행하는지의 논리적 실행 단위 |
| `JobParameters` | JobInstance를 구분하는 식별 키 집합 |
| `JobExecution` | JobInstance를 실제로 한 번 실행하려는 시도 |
| `JobRepository` | 위 모든 도메인 객체를 DB에 영속화하는 인프라 컴포넌트 |
| `JobOperator` | Job을 시작/중단/재시작하는 인터페이스 |

---

## 📗 2. Job

---

Job은 전체 배치 프로세스를 감싸는 최상위 엔티티다. Spring Batch에서 Job은 단순히 Step 인스턴스들의 컨테이너 역할을 한다. 논리적으로 함께 묶이는 여러 Step을 하나의 흐름으로 결합하고, 재시작 가능 여부처럼 모든 Step에 공통 적용되는 설정을 담는다.

### 📌 Job 설정의 세 가지 핵심

- Job의 이름
- Step 인스턴스들의 정의 및 순서
- 재시작 가능 여부 (restartability)

```java
/**
 * JobBuilder를 사용해 Job을 구성하는 가장 기본적인 패턴.
 * start() → next() 체인으로 Step 실행 순서를 정의한다.
 * JobRepository는 실행 메타데이터 영속화에 사용된다.
 */
@Bean
public Job footballJob(JobRepository jobRepository) {
    return new JobBuilder("footballJob", jobRepository)
        .start(playerLoad())         // 첫 번째 Step
        .next(gameLoad())            // 두 번째 Step
        .next(playerSummarization()) // 세 번째 Step
        .build();
}
```

---

## 📗 3. JobInstance

---

JobInstance는 논리적인 Job 실행(run) 개념을 말한다. 예를 들어 매일 자정에 실행되는 `EndOfDay` Job이 있다고 하자. Job 자체는 하나지만, 1월 1일 실행분과 1월 2일 실행분은 각각 별도로 추적해야 한다. 이처럼 하루에 하나씩 생성되는 논리적 실행 단위가 JobInstance다.

### 📌 핵심 동작 원리

- 1월 1일 실행이 처음에 실패해서 다음 날 재실행하더라도, 여전히 "1월 1일 JobInstance"다.
- 동일한 JobInstance를 사용하면 이전 실행의 `ExecutionContext` 상태를 이어받아 멈춘 곳부터 재시작한다.
- 새로운 JobInstance를 생성하면 처음부터 다시 시작한다.

> 💡 JobInstance 정의 자체는 어떤 데이터를 처리할지와 무관하다. 어떤 데이터를 읽을지는 전적으로 `ItemReader` 구현에 달려 있다. "1월 1일 데이터"를 읽는 것은 ItemReader의 결정이지, JobInstance의 속성이 아니다.

### 📌 다른 JobInstance와 어떻게 구분하나?

JobInstance를 구분하는 것은 JobParameters다. 아래 공식이 핵심이다.

```
JobInstance = Job + 식별 JobParameters
```

---

## 📗 4. JobParameters

---

JobParameters 객체는 배치 Job을 시작할 때 사용하는 파라미터 집합을 담는다. 식별(identification) 용도로도 쓰이고, 실행 중 참조 데이터(reference data)로도 활용할 수 있다.

```java
/**
 * 1월 1일과 1월 2일 각각에 대해 JobInstance가 생성된다.
 * 동일한 Job이지만 파라미터가 다르므로 → 다른 JobInstance.
 *
 * 세 번째 인자 true/false: identifying 여부
 *  - true  → JobInstance 식별에 기여
 *  - false → 참조 데이터로만 사용 (non-identifying)
 */
JobParameters jan1 = new JobParametersBuilder()
    .addLocalDate("schedule.Date", LocalDate.of(2017, 1, 1), true)
    .toJobParameters();

JobParameters jan2 = new JobParametersBuilder()
    .addLocalDate("schedule.Date", LocalDate.of(2017, 1, 2), true)
    .toJobParameters();

// → jan1과 jan2는 다른 JobInstance를 만든다
jobOperator.start(endOfDayJob, jan1);
jobOperator.start(endOfDayJob, jan2);
```

### 📌 identifying vs non-identifying

파라미터 중 일부는 JobInstance 식별에 기여하지 않도록(non-identifying) 설정할 수 있다.

```java
JobParameters params = new JobParametersBuilder()
    .addLocalDate("schedule.Date", LocalDate.of(2017, 1, 1), true)  // identifying
    .addString("operator", "batch-admin", false)                     // non-identifying
    .toJobParameters();
```

---

## 📗 5. JobExecution

---

JobExecution은 Job을 한 번 실행하려는 시도(attempt)의 기술적 개념이다. 실행이 실패로 끝나든 성공으로 끝나든, 해당 실행이 성공적으로 완료되지 않으면 그에 대응하는 JobInstance는 완료된 것으로 간주하지 않는다.

### 📌 JobInstance와 JobExecution의 관계

하나의 JobInstance에 대해 여러 개의 JobExecution이 존재할 수 있다. 아래 다이어그램은 동일한 JobInstance에서 첫 번째 실행이 실패하고, 두 번째 실행이 성공하는 흐름을 보여준다.

[![image](/assets/images/spring-batch/jobexecution-restart.svg)](/assets/images/spring-batch/jobexecution-restart.svg)

- `01-01-2017` 파라미터로 실행한 Job이 실패 → JobExecution #1 생성 (FAILED)
- 동일한 파라미터로 다시 실행 → JobExecution #2 생성 (COMPLETED)
- JobInstance는 여전히 하나

### 📌 JobExecution의 주요 프로퍼티

| 프로퍼티 | 설명 |
|---|---|
| `status` | 실행 중 `STARTED`, 실패 `FAILED`, 성공 `COMPLETED` |
| `startTime` / `endTime` | 시작/종료 시각 (`LocalDateTime`) |
| `exitStatus` | 호출자에게 반환되는 종료 코드 |
| `createTime` | JobExecution이 처음 영속화된 시각 (시작 전에도 존재) |
| `lastUpdated` | 마지막으로 DB에 업데이트된 시각 |
| `executionContext` | 실행 간 유지해야 하는 사용자 데이터 저장소 |
| `failureExceptions` | 실행 중 발생한 예외 목록 |

> 💡 `createTime`이 `startTime`보다 먼저 생성될 수 있다. 프레임워크는 Job이 시작되기 전에 Job 레벨 `ExecutionContext`를 관리하기 위해 JobExecution을 먼저 DB에 저장한다.

---

## 📗 6. 메타데이터 테이블로 이해하기

---

Spring Batch는 모든 실행 정보를 DB 메타데이터 테이블에 저장한다. 도메인 객체와 테이블의 매핑은 아래와 같다.

| Java 객체 | DB 테이블 |
|---|---|
| `JobInstance` | `BATCH_JOB_INSTANCE` |
| `JobExecution` | `BATCH_JOB_EXECUTION` |
| `JobParameters` | `BATCH_JOB_EXECUTION_PARAMS` |
| `StepExecution` | `BATCH_STEP_EXECUTION` |
| `ExecutionContext` | `BATCH_JOB_EXECUTION_CONTEXT` / `BATCH_STEP_EXECUTION_CONTEXT` |

### 📌 실패 → 재실행 → 다음 날 실행 시나리오

`EndOfDay` Job이 2017-01-01에 실패하고, 다음 날 재실행 성공, 그리고 2017-01-02 실행까지 이뤄진 시나리오다.

**BATCH_JOB_INSTANCE**

| JOB_INST_ID | JOB_NAME |
|---|---|
| 1 | EndOfDayJob |
| 2 | EndOfDayJob |

**BATCH_JOB_EXECUTION_PARAMS**

| JOB_EXECUTION_ID | KEY_NAME | DATE_VAL | IDENTIFYING |
|---|---|---|---|
| 1 | schedule.Date | 2017-01-01 | TRUE |
| 2 | schedule.Date | 2017-01-01 | TRUE |
| 3 | schedule.Date | 2017-01-02 | TRUE |

**BATCH_JOB_EXECUTION**

| JOB_EXEC_ID | JOB_INST_ID | START_TIME | END_TIME | STATUS |
|---|---|---|---|---|
| 1 | 1 | 2017-01-01 21:00 | 2017-01-01 21:30 | FAILED |
| 2 | 1 | 2017-01-02 21:00 | 2017-01-02 21:30 | COMPLETED |
| 3 | 2 | 2017-01-02 21:31 | 2017-01-02 22:29 | COMPLETED |

JOB_INST_ID 1에 대해 JOB_EXEC_ID 1(실패)과 2(성공) 두 개의 JobExecution이 존재한다. JobInstance는 두 번째 실행이 성공했을 때 비로소 "완료"로 간주된다. JOB_INST_ID 2는 2017-01-02 파라미터를 가진 완전히 다른 JobInstance다.

---

## 📗 7. JobRepository와 JobOperator

---

### 📌 JobRepository

JobRepository는 앞서 설명한 모든 도메인 객체의 영속화 메커니즘이다. `JobOperator`, `Job`, `Step` 구현체를 위한 CRUD 연산을 제공한다. Job이 처음 실행될 때 JobExecution이 Repository에서 생성되고, 실행 과정 내내 StepExecution과 JobExecution이 Repository를 통해 업데이트된다.

Spring Boot + `@EnableBatchProcessing`을 사용하면 `JobRepository`가 자동 설정된다.

### 📌 JobOperator

JobOperator는 Job의 시작, 중단, 재시작, abandon을 담당하는 인터페이스다.

```java
/**
 * Spring Batch 6.x에서 JobLauncher 역할이 JobOperator로 통합됐다.
 * start()  : 새 JobExecution 생성 후 실행
 * restart(): 실패한 JobExecution의 마지막 상태에서 이어서 실행
 * stop()   : 실행 중인 Job에 종료 신호 전송
 * abandon(): 더 이상 재시작하지 않을 JobExecution을 ABANDONED 상태로 마킹
 */
public interface JobOperator {
    JobExecution start(Job job, JobParameters jobParameters) throws Exception;
    JobExecution startNextInstance(Job job) throws Exception;
    boolean stop(JobExecution jobExecution) throws Exception;
    JobExecution restart(JobExecution jobExecution) throws Exception;
    JobExecution abandon(JobExecution jobExecution) throws Exception;
}
```

---

## 📗 8. 전체 개념 관계 정리

---

도메인 개념들 사이의 관계를 한눈에 보면 아래와 같다.

[![image](/assets/images/spring-batch/relationship-summary.svg)](/assets/images/spring-batch/relationship-summary.svg)

---

## 📗 9. 정리

---

- `Job`은 배치 프로세스의 설계도이고, Step들의 순서와 재시작 정책을 정의한다.
- `JobInstance = Job + 식별 JobParameters`다. 같은 Job을 다른 파라미터로 실행하면 다른 JobInstance가 생성된다.
- `JobExecution`은 JobInstance를 실행하려는 개별 시도다. 실패한 JobInstance를 재실행하면 동일 JobInstance에 새로운 JobExecution이 추가된다.
- 모든 메타데이터는 `JobRepository`가 `BATCH_*` 테이블에 자동 영속화한다.
- 재시작 시 ExecutionContext를 통해 이전 실행 상태를 복구한다 (2편에서 상세 설명).

---

## 참고 자료

- Spring Batch 공식 문서 - The Domain Language of Batch: <https://docs.spring.io/spring-batch/reference/domain.html>
- Spring Batch 공식 문서 - Meta-Data Schema: <https://docs.spring.io/spring-batch/reference/schema-appendix.html>
