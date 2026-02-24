---
title: "Dockerfile 작성 완벽 가이드 - Spring Boot 애플리케이션 이미지 만들기"
date: 2026-02-12 01:00:00 +0900
categories: [DevOps, Docker]
tags: [docker, dockerfile, spring-boot, image-build]
---

## Dockerfile이란

지금까지 우리는 '이미지'를 가지고 컨테이너를 실행한다고 배웠는데, 그렇다면 그 이미지는 도대체 어떻게 만들까?

바로 여기서 **Dockerfile**이 등장한다.

Dockerfile은 이미지를 만들기 위한 **설명서(스크립트)**다. 요리로 비유하면 아주 딱 들어맞는다.

- **Dockerfile**: 요리 레시피 (조리법)
- **Docker Build**: 요리하는 과정
- **Image**: 완성된 냉동 식품 (언제든 데워 먹을 수 있음)
- **Container**: 실제로 데워서 먹는 음식

## 핵심 명령어 3가지

가장 자주 쓰이는 핵심 명령어 3가지만 알면 웬만한 이미지는 다 만들 수 있다.

### FROM - 베이스 이미지

```dockerfile
FROM openjdk:17-jdk
```

베이스 이미지를 가져온다. 운영체제나 언어 환경을 지정한다. 여기서는 Java 17 환경을 가져왔다.

### RUN - 이미지 빌드 시 실행

```dockerfile
RUN pip install flask
```

이미지를 만들 때 실행된다. 라이브러리 설치 등의 작업을 수행한다. 이 명령어는 **이미지를 빌드할 때 딱 한 번 실행**되어 그 결과가 이미지 안에 박제된다.

### CMD - 컨테이너 시작 시 실행

```dockerfile
CMD ["python", "app.py"]
```

컨테이너가 시작될 때 실행된다. 애플리케이션을 실행하는 명령어를 지정한다.

## RUN vs CMD의 중요한 차이

만약 제가 이 이미지를 빌드해서 컨테이너를 100개를 실행한다고 가정해보자.

**pip install flask** (RUN)는 몇 번 실행될까?

정답은 **1번**이다.

다시 요리(냉동 식품) 비유로 생각해보자.

- **RUN** (조리 과정): 공장에서 냉동 피자를 만들 때 치즈를 뿌리고 햄을 올리는 단계다. 이 과정은 공장에서 제품(이미지)을 만들 때 딱 한 번 일어난다.

- **CMD** (먹는 과정): 우리가 집에서 피자를 전자레인지에 데우는 단계다. 이때 치즈를 다시 뿌리나? 아니다! 이미 뿌려져 있는 상태 그대로 데워지기만 한다.

즉, pip install flask(RUN)는 이미지를 빌드할 때 한 번 실행되어 이미지 안에 박제된다. 그래서 컨테이너를 100개를 실행해도 라이브러리를 다시 설치할 필요 없이 바로 실행된다. 이게 도커가 엄청나게 효율적인 이유다!

## Spring Boot Dockerfile 실전

이제 Spring Boot 애플리케이션을 위한 Dockerfile을 실제로 작성해보자.

### 4단계 구조

1. **베이스 깔기 (FROM)**: 어떤 환경에서 시작할지 정하기
2. **준비하기 (COPY)**: 작업 폴더를 만들고 내 코드를 컨테이너 안으로 복사하기
3. **실행하기 (CMD)**: 컨테이너가 켜질 때 실행할 명령어 정하기

### 완성된 Dockerfile

```dockerfile
# 1. 베이스 이미지 (공식 OpenJDK 17 버전)
FROM openjdk:17-jdk

# 2. 파일 복사 (내 컴퓨터의 빌드된 jar 파일을 컨테이너의 app.jar로 복사)
COPY build/libs/*.jar app.jar

# 3. 실행 명령어 (리스트 형식으로 작성)
CMD ["java", "-jar", "app.jar"]
```

### 주요 포인트

**FROM 명령어**: `openjdk:17-jdk`는 Docker Hub의 공식 이미지 이름이다. 이미 Java가 설치된 환경을 가져온다.

**COPY 명령어**: `build/libs/*.jar app.jar`는 Gradle로 빌드한 jar 파일을 컨테이너 내부로 복사한다. 와일드카드(`*.jar`)를 사용하면 파일 이름이 달라도 자동으로 찾아준다.

**CMD 명령어**: 리스트 형식(`["java", "-jar", "app.jar"]`)으로 작성하는 것이 권장된다.

## 이미지 빌드하기

Dockerfile을 작성했다면 이제 이미지를 만들 차례다.

```bash
docker build -t my-spring-app:1.0 .
```

- `-t`: 이미지에 태그(이름)을 붙인다
- `.`: 현재 디렉토리의 Dockerfile을 사용한다

## 이미지 배포 과정

개발자가 웹 사이트의 문구를 "Hello"에서 "Welcome"으로 수정했다면, 이 변경 사항을 서버에 반영하려면 어떻게 해야 할까?

서버에 접속해서 코드를 고치고 라이브러리를 다시 설치할 필요가 없다. 그냥 **docker build를 다시 실행**하면 된다!

1. **Build** (포장하기): 내 컴퓨터에서 `docker build`로 소스 코드와 라이브러리가 포함된 이미지를 만든다.
2. **Push** (업로드): 만든 이미지를 **이미지 저장소(Registry)**라는 클라우드 창고(예: Docker Hub)에 올린다.
3. **Pull & Run** (다운로드 및 실행): 서버에서 저장소에 있는 이미지를 다운(pull)받고 실행(run)한다.

이미지 안에 라이브러리, 설정 파일, 코드가 전부 들어있기 때문에, 서버에는 Java조차 설치되어 있을 필요가 없다. 그냥 도커만 깔려 있으면 된다!

---

## 참고

- 공식 문서: https://docs.docker.com/engine/reference/builder/
