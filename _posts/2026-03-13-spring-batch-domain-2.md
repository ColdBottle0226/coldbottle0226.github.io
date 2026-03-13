---
layout: post
title: "[Spring Batch] 도메인 언어 완전 정복 (2) — Step, Chunk, Tasklet"
date: 2026-03-13 09:30:00 +0900
categories: [Spring, Batch]
tags: [SpringBatch, Step, StepExecution, ExecutionContext, Chunk, Tasklet, ItemReader, ItemWriter]
---

## 📗 1. 개요

---

1편에서는 Job 계층의 도메인 개념(Job, JobInstance, JobExecution)을 정리했다. 이번 글에서는 실제 데이터 처리가 일어나는 Step 내부 구조를 깊이 파고든다. Chunk-oriented Processing이 왜 트랜잭션을 chunk 단위로 관리하는지, Tasklet과 언제 무엇을 선택해야 하는지를 중심으로 설명한다.

### 📌 이번 글에서 다루는 개념

| 개념 | 한 줄 정의 |
|---|---|
| `Step` | Job 내부의 독립적인 순차적 배치 단계 |
| `StepExecution` | Step을 한 번 실행하려는 시도 |
| `ExecutionContext` | 재시작을 위한 key-value 영속 상태 저장소 |
| `Chunk-oriented` | N건 단위로 읽고 처리하고 한 번에 쓰는 처리 방식 |
| `Tasklet` | 단일 로직을 실행하는 Step 구현 방식 |
| `ItemReader` | 데이터를 한 건씩 읽는 추상화 |
| `ItemProcessor` | 비즈니스 변환/검증 로직 추상화 |
| `ItemWriter` | chunk 단위로 일괄 쓰는 추상화 |

---

## 📗 2. Step

---

Step은 배치 Job의 독립적이고 순차적인 단계(phase)를 캡슐화하는 도메인 객체다. 모든 Job은 하나 이상의 Step으로 구성된다. Step에는 실제 배치 처리를 정의하고 제어하는 데 필요한 모든 정보가 담겨 있다.

Step의 구현 방식은 개발자가 결정한다. 파일에서 DB로 데이터를 적재하는 단순한 Step도 있고, 복잡한 비즈니스 규칙을 적용하는 Step도 있다. Step이 어떤 내용을 담을지는 개발자의 재량에 달려 있다.

### 📌 Step 두 가지 구현 방식

```
Step
├── Chunk-oriented Step  → ItemReader + ItemProcessor + ItemWriter
└── TaskletStep          → Tasklet (단일 execute() 메서드)
```

---

## 📗 3. StepExecution

---

StepExecution은 Step을 한 번 실행하려는 시도를 나타낸다. Step이 실행될 때마다 새로운 StepExecution이 생성된다. 단, 앞선 Step이 실패해서 해당 Step이 아예 시작조차 하지 못하면, StepExecution은 영속화되지 않는다.

> 💡 StepExecution은 Step이 "실제로 시작"됐을 때만 생성된다. Job이 3개의 Step을 가질 때, Step 2가 실패하면 Step 3의 StepExecution은 아예 만들어지지 않는다.

### 📌 StepExecution의 주요 프로퍼티

| 프로퍼티 | 설명 |
|---|---|
| `status` | `STARTED` / `FAILED` / `COMPLETED` |
| `startTime` / `endTime` | 시작/종료 시각 |
| `readCount` | 성공적으로 읽은 아이템 수 |
| `writeCount` | 성공적으로 쓴 아이템 수 |
| `commitCount` | 커밋된 트랜잭션 수 |
| `rollbackCount` | 롤백 횟수 |
| `readSkipCount` | read 실패로 스킵된 아이템 수 |
| `processSkipCount` | process 실패로 스킵된 아이템 수 |
| `filterCount` | ItemProcessor가 null 반환으로 필터링한 아이템 수 |
| `writeSkipCount` | write 실패로 스킵된 아이템 수 |

이 수치들은 배치 모니터링에서 핵심 지표가 된다. 예를 들어 `readSkipCount`가 높다면 소스 데이터 품질 문제를 의심할 수 있다.

---

## 📗 4. ExecutionContext — 재시작의 핵심

---

ExecutionContext는 프레임워크가 영속화하고 관리하는 key-value 쌍의 컬렉션이다. `StepExecution` 또는 `JobExecution` 범위에서 개발자가 영속 상태를 저장할 수 있는 공간이다. 가장 중요한 사용 사례는 재시작(restart) 지원이다.

### 📌 재시작 지원 구현 예시

파일을 처리하다가 오류가 발생해도, 다음 실행 시 중단 지점부터 이어서 처리할 수 있다.

```java
/**
 * ItemReader가 읽은 위치를 ExecutionContext에 저장한다.
 * 커밋 시점마다 프레임워크가 이 값을 DB에 저장하므로,
 * 장애 발생 후 재시작해도 40,321번째 줄부터 이어서 읽을 수 있다.
 */
executionContext.putLong(getKey(LINES_READ_COUNT), reader.getPosition());
```

```java
/**
 * 재시작 시 ItemReader 초기화 로직.
 * ExecutionContext에 이전 실행 기록이 있으면 그 위치부터 시작하고,
 * 없으면 처음부터 시작한다.
 */
if (executionContext.containsKey(getKey(LINES_READ_COUNT))) {
    long lineCount = executionContext.getLong(getKey(LINES_READ_COUNT));
    LineReader reader = getReader();
    // lineCount 위치까지 읽어서 skip
    while (reader.getPosition() < lineCount) {
        readLine();
    }
}
```

**BATCH_STEP_EXECUTION_CONTEXT** 테이블에는 이런 형태로 저장된다.

| STEP_EXEC_ID | SHORT_CONTEXT |
|---|---|
| 1 | {"piece.count": 40321} |

### 📌 두 개의 ExecutionContext

ExecutionContext는 StepExecution과 JobExecution 각각에 독립적으로 존재한다.

```java
ExecutionContext ecStep = stepExecution.getExecutionContext();
ExecutionContext ecJob  = jobExecution.getExecutionContext();
// ecStep != ecJob — 완전히 별개의 객체

// Step 범위: 각 commit 시점마다 저장
// Job 범위: 각 Step 실행 사이에 저장
```

> 💡 ExecutionContext에 저장하는 모든 non-transient 항목은 반드시 `Serializable`이어야 한다. 직렬화가 불가능하면 실패한 Job을 복구할 수 없게 된다.

---

## 📗 5. Chunk-oriented Processing

---

Spring Batch의 가장 핵심적인 처리 방식이다. 데이터를 한 건씩 읽어서 chunk(묶음)를 만들고, chunk 단위로 트랜잭션을 관리한다.

### 📌 처리 흐름

아래 다이어그램은 Chunk-oriented Processing의 전체 흐름을 나타낸다. ItemReader가 1건씩 읽고, ItemProcessor가 변환하며, chunk-size에 도달하면 ItemWriter가 N건을 일괄 쓰고 커밋한다.

![Chunk-oriented Processing 흐름도](/assets/images/spring-batch/chunk-processing-flow.svg)

트랜잭션은 Writer의 write() + commit() 단위로 관리된다. 예를 들어 chunk-size=100이면, 100건을 읽고 처리한 후 한 번에 쓰고 커밋한다. 커밋 전에 오류가 발생하면 해당 chunk 전체가 롤백된다.

### 📌 ItemReader

데이터를 한 건씩 읽는 추상화다. 더 이상 제공할 아이템이 없으면 `null`을 반환해 읽기 완료를 알린다.

```java
/**
 * JdbcCursorItemReader: DB 커서를 사용해 대용량 데이터를 스트리밍으로 읽는다.
 * - fetchSize: DB에서 한 번에 가져오는 행 수 (네트워크 라운드트립 최소화)
 * - rowMapper: ResultSet → 도메인 객체 변환
 * saveState = true로 설정하면 읽은 위치가 ExecutionContext에 저장돼
 * 재시작 시 중단 지점부터 이어서 읽는다.
 */
@Bean
public JdbcCursorItemReader<Customer> customerItemReader(DataSource dataSource) {
    return new JdbcCursorItemReaderBuilder<Customer>()
        .name("customerItemReader")
        .dataSource(dataSource)
        .sql("SELECT id, name, email FROM customers WHERE processed = false")
        .fetchSize(1000)  // 1000건씩 DB에서 가져옴
        .rowMapper(new BeanPropertyRowMapper<>(Customer.class))
        .saveState(true)  // ExecutionContext에 읽은 위치 저장 → 재시작 지원
        .build();
}
```

### 📌 ItemProcessor

한 건의 비즈니스 처리 로직을 담당한다. `null`을 반환하면 해당 아이템은 write 대상에서 제외(필터)된다.

```java
/**
 * ItemProcessor는 단일 아이템에 대한 변환/검증 로직을 담는다.
 * null 반환 = 해당 아이템을 write하지 않음 (필터링).
 * filterCount가 StepExecution에 기록된다.
 *
 * CompositeItemProcessor를 쓰면 여러 Processor를 체이닝할 수 있다.
 */
@Bean
public ItemProcessor<Customer, Customer> customerItemProcessor() {
    return customer -> {
        // 이메일이 없는 고객은 처리 대상에서 제외
        if (customer.getEmail() == null || customer.getEmail().isBlank()) {
            return null; // → filterCount 증가
        }
        // 이름 정규화 처리
        customer.setName(customer.getName().trim().toUpperCase());
        return customer;
    };
}
```

### 📌 ItemWriter

chunk 단위로 일괄 처리하는 추상화다. 한 번의 write() 호출에 N건의 아이템 리스트가 전달된다.

```java
/**
 * JdbcBatchItemWriter: JDBC batch insert/update를 사용해 N건을 한 번에 처리한다.
 * 개별 INSERT를 N번 실행하는 것보다 훨씬 빠르다.
 * assertUpdates = true: 업데이트된 행 수가 예상과 다르면 예외 발생
 */
@Bean
public JdbcBatchItemWriter<Customer> customerItemWriter(DataSource dataSource) {
    return new JdbcBatchItemWriterBuilder<Customer>()
        .dataSource(dataSource)
        .sql("INSERT INTO processed_customers (id, name, email) " +
             "VALUES (:id, :name, :email) " +
             "ON DUPLICATE KEY UPDATE name = :name, email = :email")
        .beanMapped()      // Customer 객체의 필드를 :name 파라미터에 자동 매핑
        .assertUpdates(true)
        .build();
}
```

### 📌 전체 Chunk Step 조립

```java
/**
 * Chunk-oriented Step 설정.
 * chunk(100): 100건마다 write + commit
 * faultTolerant(): skip/retry 기능 활성화
 * skipLimit(10): 최대 10건까지 DataFormatException을 skip 허용
 *   → skip된 아이템은 readSkipCount/processSkipCount/writeSkipCount에 기록
 * retryLimit(3): TransientException 발생 시 최대 3회 재시도
 */
@Bean
public Step chunkStep(JobRepository jobRepository,
                      PlatformTransactionManager transactionManager) {
    return new StepBuilder("chunkStep", jobRepository)
        .<Customer, Customer>chunk(100, transactionManager)
        .reader(customerItemReader(dataSource))
        .processor(customerItemProcessor())
        .writer(customerItemWriter(dataSource))
        .faultTolerant()
        .skipLimit(10)
        .skip(DataFormatException.class)
        .retryLimit(3)
        .retry(TransientDataAccessException.class)
        .build();
}
```

---

## 📗 6. Tasklet

---

Tasklet은 ItemReader/ItemWriter 구조 없이 단일 로직을 실행하는 Step 구현 방식이다. `execute()` 메서드 하나로 구성되며, `RepeatStatus`를 반환해 Step의 계속 여부를 제어한다.

```java
/**
 * Tasklet의 두 가지 반환값:
 * - RepeatStatus.FINISHED: Step 완료. 다음 Step으로 넘어감.
 * - RepeatStatus.CONTINUABLE: execute()를 다시 호출.
 *   → 일반적으로는 FINISHED를 반환하고,
 *      특수한 polling 작업에서만 CONTINUABLE을 사용한다.
 */
@Bean
public Step fileCleanupStep(JobRepository jobRepository,
                            PlatformTransactionManager transactionManager) {
    return new StepBuilder("fileCleanupStep", jobRepository)
        .tasklet((contribution, chunkContext) -> {
            Path tempDir = Paths.get("/tmp/batch-work");
            Files.walk(tempDir)
                .sorted(Comparator.reverseOrder())
                .map(Path::toFile)
                .forEach(File::delete);

            log.info("임시 파일 정리 완료: {}", tempDir);
            return RepeatStatus.FINISHED;
        }, transactionManager)
        .build();
}
```

### 📌 MethodInvokingTaskletAdapter — 기존 서비스 재사용

기존 Service 빈을 Tasklet으로 감싸서 사용할 수 있다.

```java
/**
 * 이미 잘 동작하는 Service 메서드를 배치 Step으로 재사용하고 싶을 때.
 * Tasklet 코드를 새로 작성하지 않고, 기존 빈의 메서드를 위임한다.
 */
@Bean
public Step reportGenerationStep(JobRepository jobRepository,
                                 PlatformTransactionManager transactionManager) {
    MethodInvokingTaskletAdapter adapter = new MethodInvokingTaskletAdapter();
    adapter.setTargetObject(reportService);       // 기존 Service 빈
    adapter.setTargetMethod("generateDailyReport"); // 실행할 메서드
    adapter.setArguments(new Object[]{ LocalDate.now() }); // 인자

    return new StepBuilder("reportGenerationStep", jobRepository)
        .tasklet(adapter, transactionManager)
        .build();
}
```

---

## 📗 7. Chunk vs Tasklet 선택 기준

---

| 상황 | 권장 방식 |
|---|---|
| 대량 데이터를 건건이 읽고 변환/저장해야 할 때 | Chunk-oriented |
| 재시작 시 중단 지점부터 이어가야 할 때 | Chunk-oriented |
| skip/retry 정책이 필요할 때 | Chunk-oriented |
| 파일 이동/삭제, 알림 발송처럼 단순 1회성 작업 | Tasklet |
| DB 저장 프로시저 호출, 집계 쿼리 실행 | Tasklet |
| 기존 Service 메서드를 Step으로 재사용할 때 | Tasklet (MethodInvokingTaskletAdapter) |

> 💡 실무에서 자주 만나는 패턴: 데이터 이관 Job은 Chunk Step으로, 이관 전 테이블 초기화나 이관 후 알림 발송은 Tasklet Step으로 구성하는 혼합 방식이 일반적이다.

---

## 📗 8. 전체 흐름 정리

---

Spring Batch 도메인 개념 전체를 관계로 정리하면 아래 다이어그램과 같다.

![Spring Batch 도메인 관계 요약](/assets/images/spring-batch/relationship-summary.svg)

```
Job (설계도)
 └─ 1:N ─→ JobInstance (Job + 식별 파라미터)
             └─ 1:N ─→ JobExecution (실행 시도)
                         └─ 1:N ─→ StepExecution (Step 실행 시도)
                                     └─ 1:1 ─→ ExecutionContext (재시작 상태)

Step
 ├─ Chunk-oriented: ItemReader → ItemProcessor → ItemWriter (N건 단위 트랜잭션)
 └─ Tasklet: execute() → RepeatStatus

JobRepository: 위 모든 객체의 CRUD 담당 (BATCH_* 테이블)
JobOperator:   start / stop / restart / abandon
```

---

## 📗 9. 정리

---

- `Step`은 Job 내부의 독립적인 배치 단계다. Chunk-oriented 또는 Tasklet으로 구현한다.
- `StepExecution`은 Step 실행 시도를 추적하며, readCount/writeCount/skipCount 등 처리 통계를 저장한다.
- `ExecutionContext`는 commit마다 DB에 저장되어 재시작 시 중단 지점 복구를 가능하게 한다.
- Chunk-oriented는 `Read 1건 → Process 1건 → buffer 누적 → chunk-size 도달 시 Write + commit` 사이클로 동작한다.
- `ItemProcessor`가 `null`을 반환하면 해당 아이템은 write되지 않고 filterCount가 증가한다.
- `Tasklet`은 RepeatStatus.FINISHED를 반환할 때까지 execute()를 반복 호출한다.

---

## 참고 자료

- Spring Batch 공식 문서 - The Domain Language of Batch: <https://docs.spring.io/spring-batch/reference/domain.html>
- Spring Batch 공식 문서 - Chunk-oriented Processing: <https://docs.spring.io/spring-batch/reference/step/chunk-oriented-processing.html>
- Spring Batch 공식 문서 - TaskletStep: <https://docs.spring.io/spring-batch/reference/step/tasklet.html>
- Spring Batch 공식 문서 - ItemReaders and ItemWriters: <https://docs.spring.io/spring-batch/reference/readersAndWriters.html>
