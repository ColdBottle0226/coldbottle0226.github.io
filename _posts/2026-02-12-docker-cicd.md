---
title: "도커로 배포 자동화하기 - CI/CD 파이프라인과 Jenkins 활용"
date: 2026-02-12 02:00:00 +0900
categories: [DevOps, Docker]
tags: [docker, cicd, jenkins, deployment, automation]
---

## 도커 이미지 배포 방식

개발자가 로컬에서 이미지를 만들면, 이를 다른 서버에 배포하는 과정이 필요하다. 일반적으로 다음 3단계를 따른다.

### 1. Build (포장하기)

`docker build`로 이미지를 생성한다. 소스 코드와 라이브러리가 모두 포함된 이미지가 만들어진다.

```bash
docker build -t my-repo/spring-server:latest .
```

### 2. Push (업로드)

이미지 저장소(Registry)에 업로드한다. Docker Hub가 가장 대표적이지만, 사내 프라이빗 레지스트리를 사용할 수도 있다.

```bash
docker login -u [아이디] -p [비밀번호]
docker push my-repo/spring-server:latest
```

### 3. Pull & Run (다운로드 및 실행)

서버에서 저장소에 있는 이미지를 다운받고 실행한다.

```bash
docker pull my-repo/spring-server:latest
docker run -d --name spring-server my-repo/spring-server:latest
```

## CI/CD 파이프라인 구성

### 역할 분담

실무에서는 보통 다음과 같이 역할을 나눈다.

**개발자 (Developer)**
- 책임: 애플리케이션 코드 작성, Dockerfile 작성 및 관리
- 목표: "내 코드가 컨테이너 환경에서도 문제없이 잘 돌아가는가?"
- 액션: 코드를 Git에 올리기(Push)까지만 신경 쓴다

**CI/CD 시스템 (Automated Pipeline)**
- CI (지속적 통합): 개발자가 코드를 올리면 자동으로 감지해서 테스트하고, `docker build`로 이미지를 만들고, `docker push`로 저장소에 올린다
- CD (지속적 배포): 저장소에 새 이미지가 올라오면, 실제 서버에 접속해서 새 컨테이너를 실행한다

## Jenkins를 이용한 배포 자동화

### 전체 프로세스

1. **개발자**: 코드 수정 후 Git의 `develop` 브랜치에 Push
2. **Jenkins**: 
   - Git에서 코드를 가져와 테스트 및 빌드 (Jar 생성)
   - `docker build`로 이미지를 생성
   - `docker push`로 Docker Hub(또는 사내 저장소)에 업로드
   - SSH를 통해 배포 서버에 접속하여 배포 스크립트 실행
3. **배포 서버**: 기존 컨테이너 중지/삭제 후 새 이미지를 받아 실행

### Jenkins 서버에서 실행되는 명령어

```bash
# 1. 도커 이미지 빌드 (태그는 보통 빌드 번호나 latest 사용)
docker build -t my-repo/spring-server:latest .

# 2. 도커 레지스트리(저장소) 로그인
docker login -u [아이디] -p [비밀번호]

# 3. 이미지 업로드
docker push my-repo/spring-server:latest
```

### 배포 서버에서 실행되는 스크립트

Jenkins가 SSH로 배포 서버에 접속해서 실행하는 최종 스크립트다.

```bash
# 1. 기존 컨테이너 중지 (에러 무시)
docker stop spring-server || true

# 2. 기존 컨테이너 삭제 (에러 무시)
docker rm spring-server || true

# 3. 기존 이미지 삭제 (선택 사항: 디스크 공간 확보를 위해)
docker rmi my-repo/spring-server:latest || true

# 4. 최신 이미지 다운로드
docker pull my-repo/spring-server:latest

# 5. 새 컨테이너 실행
docker run -d \
  --name spring-server \
  -p 80:8080 \
  --restart always \
  my-repo/spring-server:latest
```

## 핵심 명령어 설명

### docker run 옵션

**-d (Detached)**: 백그라운드 모드로 실행한다. 이 옵션이 없으면 Jenkins는 로그를 계속 보고 있느라 배포가 끝나지 않고 멈춘다.

**--name spring-server**: 컨테이너에 고정된 이름을 부여한다. 이 이름이 있어야 다음 배포 때 `docker stop spring-server`로 찾아서 멈출 수 있다.

**-p 80:8080**: 외부의 80번 포트로 들어온 요청을 컨테이너 내부의 8080번(스프링 부트 기본 포트)으로 연결한다.

**--restart always**: 서버가 재부팅되거나 도커 데몬이 재시작될 때, 컨테이너도 자동으로 다시 시작되도록 한다. 운영 환경에서 필수적인 옵션이다.

### 에러 처리

**|| true**: `stop`이나 `rm` 명령어 뒤에 붙인 이 부분은 "실패해도 넘어가라"는 뜻이다. 처음 배포할 때는 멈출 컨테이너가 없어서 에러가 발생하는데, 이 때문에 전체 배포가 중단되는 것을 막아준다.

## 배포 흐름 요약

```
Git Push (develop) 
    ↓
Jenkins 감지
    ↓
1. 코드 Pull
2. 테스트 실행
3. Gradle Build (jar 생성)
4. Docker Build (이미지 생성)
5. Docker Push (레지스트리 업로드)
    ↓
SSH로 배포 서버 접속
    ↓
1. 기존 컨테이너 정리
2. 새 이미지 Pull
3. 새 컨테이너 Run
    ↓
배포 완료
```

이렇게 자동화된 파이프라인을 구축하면 개발자는 코드만 Push하면 되고, 나머지 과정은 모두 자동으로 처리된다.

---

## 참고

- Jenkins 공식 문서: https://www.jenkins.io/doc/
- Docker Hub: https://hub.docker.com/
