---
layout: post
title:  "[Spring Batch] 핵심 구성 요소와 아키텍처 총정리"
date:   2026-02-05
categories: [Spring, Batch]
tags: [Spring Batch, Job, Step, Chunk]
---

# 📗 1. Spring Batch 계층 구조

---

스프링 배치는 작업을 효율적으로 관리하기 위해 **Job, Step, Execution**으로 이어지는 계층적인 도메인 모델을 가진다.

> 📌 **구조** > **Job (1) : Step (N)** > **Job (1) : JobInstance (N)**


### 📌 주요 개념

### 1️⃣ Job (작업)

- 배치 처리의 **최상위 개념**
- 여러 개의 **Step**으로 구성 가능하며, 스프링 빈(Bean)으로 관리된다.

### 2️⃣ JobInstance (논리적 실행 단위)

- **Job이 실행될 때 생성**되는 논리적인 실행 단위이다.
- `Job` + `JobParameter` = `JobInstance`
  - *예: '일일 정산' Job이 1월 1일, 1월 2일 각각 실행되면 2개의 Instance가 생성됨*

### 3️⃣ JobExecution (실제 실행)

- JobInstance의 **실제 실행 시도**를 의미한다.
- 실패 후 재실행 시 `JobInstance`는 동일하지만, `JobExecution`은 새로 생성된다.

---

# 📗 2. 작업의 단위: Step & Flow

---

**Step**은 Job 내부에서 실제 비즈니스 로직을 수행하는 단계이다.  
처리 방식에 따라 **Tasklet**과 **Chunk** 방식으로 나뉜다.

## 📌 Step 처리 방식

### 1️⃣ Tasklet

- 단순한 작업, 단일 로직 처리에 사용
- 파일 삭제, 단순 프로시저 호출 등

### 2️⃣ Chunk-Oriented

- **대용량 데이터**를 읽고(Read), 가공하고(Process), 쓰는(Write) 구조적 처리에 사용
- 트랜잭션 관리가 용이함

---

## 📌 Flow (흐름 제어)

단순히 `next()`로 연결하는 것을 넘어, **조건부 흐름(분기 처리)**을 제어하는 컨테이너이다.

> 💡 **Flow 시나리오 예시**
> - **Step A 성공 시** → Step B 실행
> - **Step A 실패 시** → Step C 실행

```java
// 흐름 제어 의사 코드(Pseudo Code)
.start(stepA)
    .on("FAILED").to(stepC)
    .from(stepA).on("*").to(stepB)
.end()