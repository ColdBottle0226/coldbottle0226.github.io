---
title: "AI 에이전트는 이렇게 만든다 - LangChain 01~02장 정리"
date: 2026-03-15 10:00:00 +0900
categories: [LangChain]
tags: [LangChain, LangSmith, Python, AI에이전트, OpenAI, StructuredOutput, Memory]
---

## 📗 1. 개요

---

AI 에이전트를 처음 공부하려면 어디서 시작해야 할지 막막하다. 위키독스의 "AI 에이전트는 이렇게 만든다 (랭체인부터 랭그래프까지)" 책을 읽으며 01~02장까지의 핵심 내용을 정리한다. 이 글에서는 AI 에이전트의 개념, 랭체인의 기초 설정, 모델 호출 방식, 구조화된 출력, 메모리 관리 전략, 그리고 랭스미스 연동까지 단계별로 정리한다.

### 📌 전체 구조

| 챕터 | 내용 | 핵심 개념 |
| --- | --- | --- |
| 01장 시작하며 | AI 에이전트 개요 + 책의 로드맵 | LLM → AI Agent 패러다임 전환 |
| 1-1 사전 준비 | OpenAI API 키 발급 + 첫 호출 | Reasoning effort 설정 |
| 2-1 랭체인 시작하기 | langchain 패키지 설치 + init_chat_model | AIMessage, usage_metadata |
| 2-2 Model | 모델 호출 방식 3종 | invoke / stream / batch |
| 2-3 구조화된 답변 | JSON 형태로 응답 받기 | Pydantic, JSON Schema |
| 2-4 Memory | 대화 컨텍스트 누적 + 관리 전략 | trim_messages, 5가지 메모리 전략 |
| 2-5 랭스미스 | 실행 추적 + 모니터링 | LANGCHAIN_TRACING_V2 |

---

## 📗 2. AI 에이전트란 무엇인가

---

### 📌 패러다임의 전환: 대화에서 행동으로

생성형 AI 초창기에는 묻는 말에 대답만 잘해도 혁신이라 불렸다. 이제 실무 현장의 기준은 그 너머를 향하고 있다. 지금 필요한 것은 단순히 말을 잘하는 비서가 아니라, 업무를 실질적으로 끝내주는 해결사다.

진정한 실무형 AI라면 친절한 답변을 넘어 다음과 같은 능력이 필요하다.

- 사내 문서나 웹을 탐색해 필요한 정보를 스스로 찾아내고
- API 호출이나 파일 생성 같은 도구를 직접 다룰 줄 알며
- 결과에 오류가 없는지 스스로 검증하고 보정하는 과정을 거쳐
- 최종 보고서 작성이나 코드 수정까지 완결된 결과물을 내놓는 것

이 모든 업무 흐름을 스스로 판단하고 실행하는 핵심이 바로 'AI 에이전트'다. 거대한 언어 모델(LLM)이라는 '두뇌'에 다양한 도구라는 '손과 발'을 달아 현실 세계의 업무를 직접 해결하는 구조다.

### 📌 글로벌 빅테크의 흐름

글로벌 기업들이 AI 에이전트를 '업무 자동화의 기본 단위'로 정의하고 있다는 점에서 이 흐름은 더욱 명확해진다.

- Salesforce: 'Agentforce'를 통해 사람과 데이터, 에이전트가 유기적으로 협업하는 생태계 구축
- AWS: 베드록(Bedrock)에 멀티 에이전트 협업 기능 도입
- Microsoft: 코파일럿 스튜디오를 통해 정책 관리와 모니터링 강조
- IBM: 왓슨엑스(watsonx)로 에이전트와 도구, 사람까지 연결하는 라우팅 역량 강조

이제 핵심은 단순히 에이전트를 '만드는 것'을 넘어, 어떻게 '운영하고 통제할 것인가'로 옮겨가고 있다.

### 📌 책의 학습 로드맵

이 책은 크게 두 파트로 나뉜다.

**[상편] 랭체인 파트 (1~5장): 단일 에이전트 & 거버넌스**

- 오리엔테이션 및 환경 설정
- 기초 다지기: 랭체인의 기초 문법 학습
- 에이전트 입문: 도구 사용법, 실행 루프 구성, 미들웨어 적용
- 고급 에이전트: 컨텍스트 엔지니어링과 가드레일을 통한 신뢰성/안전성 확보
- RAG와 결합: 사내/개인 데이터를 활용해 스스로 답을 찾는 실무형 에이전트 구축

**[하편] 랭그래프 파트 (6~10장): 완벽한 통제와 멀티 에이전트 시스템**

- 랭그래프 개념과 설계 철학: 그래프(State, Node, Edge) 기반 흐름 제어
- 랭그래프 기초: 랭그래프를 활용한 견고한 에이전트 개발 패턴
- 상태 제어와 마법의 기능: 메모리와 타임 트래블(Time Travel), 인터럽트(Interrupt)
- 멀티 에이전트(Multi-Agent) 구축: 서브그래프, 중앙 집중형(Supervisor), 핸드오프(Hand-off)

---

## 📗 3. 사전 준비 (1-1)

---

### 📌 OpenAI API 키 발급

에이전트의 두뇌 역할을 할 LLM이 필요하다. 이 책에서는 OpenAI의 GPT 계열 모델을 기준으로 실습한다.

발급 순서는 다음과 같다.

1. OpenAI 플랫폼(platform.openai.com)에 접속해 회원가입
2. 'Organization(조직)'을 생성하고 API Key 발급 페이지로 이동
3. 새로운 API Key를 생성하고 복사
4. 결제 수단을 등록하고 크레딧을 충전

> 💡 API 키 보안 원칙
>
> API 키가 유출되면 다른 사람의 사용량이 내 계정에 과금될 수 있다. 다음 원칙을 반드시 지킨다.
> - 메신저, 이메일, 공개된 GitHub 저장소에 절대 올리지 말 것
> - 노트북 파일(.ipynb)에 키를 직접 입력(하드코딩)했다면, 타인에게 공유하기 전에 반드시 삭제
> - 키가 노출된 것 같다면, 즉시 OpenAI 플랫폼에서 해당 키를 삭제

### 📌 OpenAI SDK 설치

```bash
!pip install openai
```

Colab에서는 셸(Shell) 명령어 실행 시 앞에 `!`를 붙인다. 로컬 환경이라면 `pip install openai`만 입력하면 된다.

### 📌 OPENAI_API_KEY 환경변수 설정

코드에 API 키를 직접 적어 넣으면 코드가 지저분해지고 유출 위험도 커진다. 환경변수를 통해 키를 주입하는 방식을 기본으로 사용한다.

```python
import os
os.environ["OPENAI_API_KEY"] = "sk-proj-xxx"
```

### 📌 API 호출로 동작 확인

```python
from openai import OpenAI

client = OpenAI()

response = client.responses.create(
    model="gpt-5-nano",
    input="안녕하세요! 만나서 반가워요!"
)

print(response.output_text)
```

```
안녕하세요! 만나서 반가워요. 무엇을 도와드릴까요?
- 번역이나 요약
- 정보 찾기나 자료 정리
- 코딩이나 기술 문제 해결
...
```

`output_text` 속성을 호출하면 전체 응답 객체가 아닌 텍스트 내용만 빠르게 확인할 수 있다.

### 📌 Reasoning(추론) 맛보기

최근 등장한 추론 특화 모델들은 답변을 내놓기 전에 내부적으로 고민하고 논리를 전개하는 '생각할 시간'을 가진다. 복잡한 수학 문제나 코딩 오류를 해결할 때, 사람이 단계별로 문제의 원인을 쪼개어 생각(Chain of Thought)하는 것과 같은 원리다.

`reasoning` 파라미터 내부의 `effort` 값으로 모델의 추론 깊이를 제어할 수 있다.

| effort 값 | 설명 | 적합한 상황 |
| --- | --- | --- |
| low | 빠르고 직관적인 답변 | 일상적인 대화, 단순 요약 |
| medium | 속도와 품질의 균형 | 일반적인 문제 해결 (기본값) |
| high | 고도의 논리적 연산 | 복잡한 아키텍처 설계, 난해한 코딩 문제 |

```python
prompt = """
앵무새의 털 색상이 여러 개인 이유가 뭐야?
"""

response = client.responses.create(
    model="gpt-5-nano",
    reasoning={"effort": "medium"},  # 추론의 깊이를 설정하는 부분
    input=[
        {
            "role": "user",
            "content": prompt
        }
    ]
)

print(response.output_text)
```

```
짧게 말하면, 앵무새의 털 색이 여러 가지인 이유는 색소와 구조색이 섞여 작용하고,
식이와 생태적 역할이 끼어들며 진화적으로 발달했기 때문입니다.

주요 요인들:
- 멜라닌: 검정/회색 계열을 만듭니다.
- 카로티노이드: 식이에서 얻어 노랑/주황/빨강 계열 색을 냅니다.
- psittacofulvins: 앵무새 고유 색소로 빨강/주황/노랑 색에 기여합니다.
- 구조색: 파란색이나 푸른 빛은 깃털의 나노구조 때문입니다.
...
```

> 💡 Reasoning effort를 무조건 high로 설정하는 게 정답은 아니다. 에이전트를 설계할 때는 주어진 상황과 태스크에 맞춰 비용, 응답 대기 시간, 결과물의 품질 간의 균형을 잡는 것이 핵심이다.

---

## 📗 4. 랭체인 시작하기 (2-1)

---

### 📌 패키지 설치

```bash
!pip install -U langchain
!pip install -U langchain-openai
```

`-U`는 이미 설치된 패키지가 있더라도 최신 버전으로 업그레이드하여 설치하겠다는 의미다. 이 책은 "1.x" 라인을 기준으로 진행한다.

### 📌 모델 초기화: init_chat_model()

```python
from langchain.chat_models import init_chat_model

model = init_chat_model("gpt-5-nano")
```

`init_chat_model()`로 채팅 모델을 초기화한 뒤, `invoke()` 메서드로 호출한다.

```python
response = model.invoke("안녕하세요. 당신은 누구입니까?")
print(response)
```

```
content='안녕하세요! 저는 ChatGPT라고 합니다. OpenAI가 만든 대화형 인공지능으로...'
additional_kwargs={'refusal': None}
response_metadata={'token_usage': {'completion_tokens': 708, 'prompt_tokens': 15, 'total_tokens': 723, ...}}
id='lc_run--f1273290-9724-40b5-b689-8b0361d3124f-0'
usage_metadata={'input_tokens': 15, 'output_tokens': 708, 'total_tokens': 723, ...}
```

응답으로 `AIMessage` 객체가 반환된다. 이 중 `content`와 `usage_metadata` 속성을 가장 자주 확인한다.

### 📌 response.content

```python
print(response.content)
```

```
안녕하세요! 저는 OpenAI가 만든 대화형 인공지능, ChatGPT입니다.
텍스트로 질문에 답하고, 글쓰기나 번역, 요약, 코딩 도움, 아이디어 뽑기 등
다양한 작업을 도와드립니다.
...
```

`response.content`는 복잡한 `AIMessage` 객체 중에서 실제 AI가 생성한 순수한 텍스트 답변만을 추출하는 속성이다. 이후 에이전트나 애플리케이션을 만들 때는 이 `content` 값만 뽑아서 사용자에게 보여주거나 다음 작업의 입력값으로 활용한다.

### 📌 response.usage_metadata

```python
print(response.usage_metadata)
```

```
{'input_tokens': 15, 'output_tokens': 888, 'total_tokens': 903,
 'input_token_details': {'audio': 0, 'cache_read': 0},
 'output_token_details': {'audio': 0, 'reasoning': 704}}
```

`usage_metadata`는 이번 한 번의 모델 호출에 토큰이 얼마나 사용되었는지 보여주는 핵심 지표다. 토큰은 API 사용 시 과금(비용)과 직결되기 때문에 에이전트 개발자라면 반드시 눈여겨봐야 한다.

| 필드 | 의미 |
| --- | --- |
| input_tokens (15개) | 내가 모델에게 보낸 질문이 내부적으로 변환된 토큰 수 |
| output_tokens (888개) | 모델이 답변을 생성하는 데 사용한 전체 토큰 수 |
| output_token_details.reasoning (704개) | 추론(Reasoning) 과정에서 사용된 토큰 수 |

> 💡 모델의 추론 깊이를 높게 설정할수록 더 똑똑한 답변을 얻을 수 있지만, 그만큼 숨겨진 토큰 사용량(Reasoning 토큰)이 늘어나 비용과 대기 시간이 증가한다. 이 'Reasoning 토큰'도 전체 output_tokens에 포함되어 비용으로 청구된다.

---

## 📗 5. Model (2-2)

---

### 📌 모델의 역할

LLM 모델은 단순히 텍스트를 만들어주는 도구가 아니라, 상황에 따라 다양한 역할을 수행한다.

| 역할 | 설명 |
| --- | --- |
| 텍스트 생성 | 질문/지시를 받아 자연어 응답을 생성 |
| 구조화된 출력 | JSON, 리스트처럼 후처리가 쉬운 형태로 답변 생성 |
| 멀티모달 | 텍스트 외 이미지/음성 등 다양한 입출력으로 확장 |
| 추론 + 도구 호출 | 바로 답하지 않고 필요한 도구를 호출해 결과를 종합 |

이번 장에서는 가장 기본이 되는 텍스트 생성을 기준으로 랭체인에서 모델을 다루는 방법을 익힌다.

### 📌 1) 단일 호출: invoke()

가장 기본이 되는 호출 방식이다. 입력(질문/지시)을 넣으면 전체 생성이 끝난 후 응답 객체가 돌아온다.

```python
response = model.invoke("안녕하세요. 당신은 누구입니까?")
print(response.content)
```

```
안녕하세요! 저는 ChatGPT라고 합니다. OpenAI가 만든 대화형 인공지능으로...
```

### 📌 2) 호출 파라미터: temperature, timeout, max_tokens

모델은 똑같은 질문을 받아도 설정된 파라미터에 따라 전혀 다른 뉘앙스의 출력을 내놓을 수 있다.

| 파라미터 | 범위 | 설명 |
| --- | --- | --- |
| temperature | 0.0 ~ 2.0 | 답변의 무작위성과 창의성 조절. 0에 가까울수록 일관성, 높을수록 창의성 |
| timeout | 초 단위 | 모델 호출 후 응답을 얼마나 기다릴지 설정 |
| max_tokens | 정수 | 모델이 생성할 수 있는 응답의 최대 길이(토큰 수) 제한 |

```python
# Temperature가 0일 때 (보수적, 일관성 위주)
model_temp_0 = init_chat_model("gpt-5-nano", temperature=0.0)
print("[Temperature 0.0]")
print(model_temp_0.invoke("사과의 매력을 한 문장으로 표현해줘.").content)

# Temperature가 1.0일 때 (창의적, 무작위성 위주)
model_temp_1 = init_chat_model("gpt-5-nano", temperature=1.0)
print("\n[Temperature 1.0]")
print(model_temp_1.invoke("사과의 매력을 한 문장으로 표현해줘.").content)
```

```
[Temperature 0.0]
사과는 아삭한 식감과 새콤달콤한 맛을 동시에 즐길 수 있는 영양가 높은 과일입니다.

[Temperature 1.0]
한 입 베어 무는 순간 경쾌하게 부서지는 붉은 껍질 너머로, 입안 가득 팡팡 터지는 새콤달콤한 과즙의 마법!
```

> 💡 실전 에이전트 개발을 위한 엔지니어링 팁
>
> - RAG, 데이터 추출, 코드 생성: temperature를 0.0~0.1로 낮춰라. 모델의 창의성은 곧 '환각(Hallucination)'으로 이어진다.
> - 마케팅 카피라이팅, 브레인스토밍, 페르소나 챗봇: temperature를 0.7~1.0 사이로 두어 모델의 상상력을 적극 활용하라.
> - timeout은 장애 방지용: timeout=30처럼 명시적인 제한을 두어 빠른 실패를 유도하고 재시도 로직을 태우는 것이 안전하다.
> - max_tokens로 비용 제한: 프롬프트 인젝션이나 모델의 무한 반복 오류로 인한 불필요하게 긴 답변 생성을 막는 최소한의 비용 방어막이다.

### 📌 3) 스트리밍: stream()

`invoke()`는 모델이 답변 생성을 모두 완료할 때까지 기다렸다가 한 번에 결과 객체를 반환한다. 답변이 길어서 생성에 10초가 걸린다면, 사용자는 10초 동안 멈춰있는 빈 화면만 보게 된다.

반면 `stream()`은 모델이 답변을 생성하는 즉시 말뭉치 조각(Chunk) 단위로 결과를 반환한다. TTFT(Time To First Token)를 획기적으로 줄여 사용자 경험(UX)이 극적으로 개선된다.

```python
# stream()은 chunk들의 제너레이터(generator)를 반환한다.
for chunk in model.stream("AI Agent란 무엇인지 1000자 이상으로 설명해 주세요"):
    # chunk는 AIMessageChunk 객체이므로 .content로 텍스트를 추출한다.
    print(chunk.content, end="", flush=True)
```

```
AI 에이전트란 무엇인가를 이해하려면, 먼저 "에이전트(agent)"의 기본 아이디어를 알아야 합니다.
간단히 말해 에이전트는 주변 세계를 감지하고...
(타이핑되듯 순차적으로 출력됨)
```

에이전트 시스템이나 챗봇 UI(Streamlit, Gradio 등)를 구축할 때, 실시간으로 텍스트가 타이핑되는 효과를 구현하려면 이 `stream()` 메서드를 사용한다.

### 📌 4) 배치 호출: batch()

여러 개의 질문을 처리해야 할 때, for 반복문 안에 `invoke()`를 넣고 실행하면 앞선 질문이 끝나야 다음 질문이 실행되는 '직렬 처리'가 일어난다. 질문 하나당 5초가 걸린다면, 10개의 질문을 처리하는 데 총 50초가 소요된다.

`batch()`는 여러 개의 입력을 병렬로 동시에 처리한다. 랭체인이 내부적으로 스레드 풀 등을 활용해 동시에 API 요청을 보내므로, 10개의 질문을 처리하더라도 대략 5~10초 내외로 모든 응답을 받을 수 있다.

```python
inputs = [
    "과적합(Overfitting)이 뭔가요? 한 줄로 요약해줘.",
    "앵무새의 털 색상이 화려한 이유를 한 줄로 요약해줘.",
    "AI Agent의 핵심 특징 한 가지는?"
]

# 한 번의 호출로 3개의 질문을 병렬 처리
responses = model.batch(inputs)

for i, response in enumerate(responses):
    print(f"[{i+1}번 답변] {response.content}")
```

```
[1번 답변] 기계 학습 모델이 훈련 데이터에 너무 과하게 맞춰져서, 새로운 데이터에 대한 예측 성능이 떨어지는 현상입니다.
[2번 답변] 포식자를 피하기 위한 위장, 짝짓기를 위한 시각적 구애, 그리고 종 간 식별을 위해 진화한 결과입니다.
[3번 답변] 환경을 관측하고 스스로 판단하여 목표 달성을 위한 도구를 능동적으로 실행하는 '자율성'입니다.
```

수십, 수백 개의 데이터를 한 번에 `batch()`로 넘기면 API Rate Limit 초과 에러가 발생할 수 있다. `config` 파라미터로 동시 실행 수를 제어한다.

```python
# 최대 5개씩만 동시에 처리하도록 제한 (Rate Limit 방어)
responses = model.batch(inputs, config={"max_concurrency": 5})
```

---

## 📗 6. 구조화된 답변 (2-3)

---

### 📌 왜 구조화된 출력이 필요한가

에이전트의 역할은 단순히 말을 잘하는 것에서 끝나지 않는다. 에이전트가 내린 판단은 대개 데이터베이스 저장, API 호출, 알림 발송 같은 '다음 작업'으로 이어져야 한다.

보안 로그 분석 에이전트를 예로 들어보자. 만약 모델이 서술형 문장만 내놓는다면, 사람이 직접 읽고 판단하거나 불안정한 정규표현식으로 텍스트를 억지로 파싱해야 하는 비효율이 발생한다.

반면 에이전트가 처음부터 후속 시스템이 즉시 해석할 수 있는 JSON으로 결과를 내려준다면 이야기가 달라진다.

```json
{
  "severity": "high",
  "summary": "5분 동안 로그인 실패 1,000회 이상 발생. 다수 계정 대상 brute force 및 /admin 스캔 징후.",
  "action_items": [
    "의심 IP를 즉시 차단하고 30분 모니터링",
    "영향 받은 계정(잠금/비밀번호 변경) 후보를 추출",
    "로그인 엔드포인트에 속도 제한(rate limit) 적용"
  ],
  "blocked_ips": ["203.0.113.10", "198.51.100.23"],
  "title": "[INC] 로그인 brute force 의심 탐지",
  "assignee": "sec-oncall",
  "due_date": "2026-03-02"
}
```

이 JSON 하나로 긴급 알림 발송, 공격 IP 자동 차단, 보안 티켓 발행까지 이어지는 완전 자동화된 대응 체계를 구축할 수 있다.

### 📌 데이터 스키마(Data Schema)란

데이터 스키마란 데이터의 구조, 타입, 제약 조건을 명시해 둔 일종의 '설계도'이자 '표준 규격서'다.

단순히 "JSON 형태로 답해줘"라고 모호하게 지시하면, 모델은 키(Key) 이름을 바꾸거나, 숫자가 올 자리에 문자를 넣고, 꼭 필요한 정보를 슬쩍 누락하는 등 제멋대로 행동한다. 이는 곧 시스템 에러로 직결된다.

따라서 모델에게 명확한 스키마를 제공하는 것은, 모델과 시스템 사이에 "반드시 이 필드명과 데이터 타입을 준수하고, 필수 여부 규칙에 맞춰 데이터를 생성하라"는 엄격한 계약을 맺는 것과 같다.

### 📌 방법 1) Pydantic

파이썬 환경에서 에이전트를 개발한다면 압도적으로 추천하는 방식이다. 클래스 형태로 구조를 잡기 때문에 코드가 깔끔하고, IDE의 자동완성 지원을 받을 수 있다.

**1.1 스키마 정의**

```python
from pydantic import BaseModel, Field
from typing import Optional, Literal

class Movie(BaseModel):
    """상세한 영화 정보."""
    title: str = Field(description="영화의 제목 (예: 인셉션)")
    year: Optional[int] = Field(default=None, description="개봉 연도. 정보를 알 수 없다면 None.")
    genre: Literal["액션", "로맨스", "SF", "코미디", "기타"] = Field(description="영화의 장르")
    director: str = Field(description="영화 감독 이름")
    rating: float = Field(description="영화 평점 (10점 만점 기준)")
```

이 스키마의 설계 의도는 다음과 같다.

- 타입 강제: `title`과 `director`는 반드시 `str`로, `rating`은 소수점이 포함된 `float`으로 받는다.
- Optional (선택적 필드): `year`는 모르면 `None`을 반환하도록 Optional을 주어 할루시네이션을 방지한다.
- Literal (선택지 제한): `genre`는 우리가 정한 5가지 카테고리 안에서만 답을 고르도록 강제한다.

> 💡 Pydantic 스키마 설계 시 주의할 점
>
> `Field(description="...")`의 텍스트는 단순한 주석이 아니다. LLM은 이 텍스트를 읽고 어떤 값을 넣을지 판단한다. 예시(예: 인셉션)나 제약 조건(10점 만점 기준)을 구체적으로 적어주면 정확도가 크게 올라간다.

**1.2 구조화 출력 모델 만들기 + 결과 분석**

```python
# 1. 스키마를 전달하여 구조화된 모델 생성
model_with_structure = model.with_structured_output(Movie)

# 2. 자연어 프롬프트로 호출
response = model_with_structure.invoke("영화 인셉션에 대해 설명해 주세요")

# 3. 결과 확인
print(response)
```

```
title='인셉션' year=2010 genre='SF' director='크리스토퍼 놀란' rating=8.8
```

단순한 줄글 텍스트가 아니라, 우리가 정의한 `Movie` 클래스의 인스턴스가 완벽하게 만들어져 반환된다.

```python
print(f"제목: {response.title} (타입: {type(response.title)})")
print(f"평점: {response.rating} (타입: {type(response.rating)})")
```

```
제목: 인셉션 (타입: <class 'str'>)
평점: 8.8 (타입: <class 'float'>)
```

`response.title`처럼 점(`.`)을 찍어 즉시 데이터에 접근할 수 있으며, 평점(8.8)은 연산이 가능한 실수형(`float`)으로 안전하게 타입 캐스팅된다. 바로 데이터베이스에 저장하거나 다음 로직에 태우기 완벽한 상태가 된 것이다.

### 📌 방법 2) JSON Schema

JSON Schema는 스키마를 딕셔너리로 정의하는 방식이다. 파이썬에 종속되지 않기 때문에 언어 중립적인 스키마를 만들 때 유용하다.

**2.1 JSON Schema 정의**

```python
import json

json_schema = {
    "title": "Movie",
    "description": "A movie with details",
    "type": "object",
    "properties": {
        "title": {
            "type": "string",
            "description": "The title of the movie"
        },
        "year": {
            "type": "integer",
            "description": "The year the movie was released"
        },
        "director": {
            "type": "string",
            "description": "The director of the movie"
        },
        "rating": {
            "type": "number",
            "description": "The movie's rating out of 10"
        }
    },
    "required": ["title", "director", "rating"]
    # year를 required에서 제외 → Optional과 동일한 효과
}
```

**2.2 구조화 출력 모델 만들기 + 결과 분석**

```python
# 1. JSON 스키마를 전달
model_with_structure = model.with_structured_output(json_schema)

# 2. 호출
response = model_with_structure.invoke("영화 인터스텔라에 대해서 소개해 주세요")

# 3. 결과 확인
print(response)
```

```
{'title': '인터스텔라', 'year': 2014, 'director': '크리스토퍼 놀란', 'rating': 8.6}
```

Pydantic 객체가 아닌 파이썬 딕셔너리(Dictionary) 형태로 파싱되어 돌아온다.

```python
print(response['title'])    # 인터스텔라
print(response['director']) # 크리스토퍼 놀란
```

### 📌 실무에서는 어떤 방식을 써야 할까?

| 상황 | 추천 방식 |
| --- | --- |
| 파이썬 환경, 타입 안전성 필요 | Pydantic (압도적 추천) |
| IDE 자동완성 및 객체 지향적 접근 | Pydantic |
| DB/외부 파일에서 스키마를 동적으로 로드 | JSON Schema |
| TypeScript 등 다른 언어와 스키마 공유 | JSON Schema |

---

## 📗 7. Memory (2-4)

---

### 📌 랭체인의 메모리 원리

랭체인에서 대화 맥락을 유지하는 원리는 의외로 단순하다. 지금까지 주고받은 메시지 전체를 누적하여 모델의 입력으로 다시 제공하는 것이다.

여기서 말하는 '메모리'는 데이터를 영구적으로 보관하는 장기 저장소라기보다, 현재 대화의 앞뒤 흐름을 파악할 수 있도록 돕는 실시간 단기 컨텍스트에 가깝다.

### 📌 메시지 종류

랭체인에는 대표적으로 3개의 메시지가 있다.

| 메시지 종류 | 역할 | 예시 |
| --- | --- | --- |
| SystemMessage | 개발자가 부여하는 역할 및 규칙 프롬프트 | "당신은 유능한 로켓 전문가입니다." |
| HumanMessage | 사용자가 입력하는 질문이나 지시사항 | "추진 방식 차이를 설명해 주세요" |
| AIMessage | 모델이 생성한 답변 | "로켓 관련 무엇이든 물어보세요." |

이 메시지들은 발생한 순서대로 누적되며, 언어 모델은 이 전체 리스트를 읽고 다음 답변을 생성한다.

### 📌 방법 1) 메시지 객체 활용

```python
from langchain.messages import HumanMessage, AIMessage, SystemMessage

system_msg = SystemMessage("당신은 유능한 로켓 전문가입니다.")
human_msg = HumanMessage("안녕하세요. 궁금한 게 있어요!")

messages = [system_msg, human_msg]
response = model.invoke(messages)
print(response.content)
```

```
좋아요. 추진 방식은 크게 에너지원과 연소/가속 방식에 따라 나뉘어요....
```

이때 모델은 사용자의 질문뿐만 아니라 시스템 메시지까지 함께 읽고 답변을 구성하므로, "로켓 전문가"라는 페르소나를 안정적으로 유지할 수 있다.

더 많은 메시지를 쌓아서 전달하면 모델은 과거의 대화를 기억하고 있는 것처럼 정확하게 답변한다.

```python
messages = [
    SystemMessage("당신은 친절한 조교입니다."),
    HumanMessage("안녕하세요. 저는 Jay라고 합니다."),
    AIMessage("안녕하세요 Jay님, 반갑습니다. 무엇을 도와드릴까요?"),
    HumanMessage("제가 방금 제 이름을 뭐라고 했죠?"),
]
response = model.invoke(messages)
print(response.content)
```

```
Jay라고 하셨어요.
```

> 💡 챗봇의 "기억력"은 실제 저장소에서 나오는 것이 아니라, 입력으로 다시 제공되는 과거 메시지 리스트를 기반으로 구현된다.

### 📌 방법 2) 딕셔너리 활용

메시지를 반드시 클래스 객체로만 생성할 필요는 없다. 파이썬의 기본 딕셔너리 형태로 `role`과 `content`를 지정해도 모델 호출 시 내부적으로 적절히 처리된다.

```python
messages = [
    {"role": "system", "content": "당신은 유능한 로켓 전문가입니다."},
    {"role": "human", "content": "안녕하세요. 궁금한 게 있어요!"},
    {"role": "ai", "content": "로켓 관련 무엇이든 물어보세요."},
    {"role": "human", "content": "추진 방식 차이를 설명해 주세요"},
]
response = model.invoke(messages)
```

이 방식의 가장 큰 장점은 데이터의 직렬화와 전송이 쉽다는 것이다. 데이터베이스에 대화 기록을 JSON 형태로 저장해 두었다가, 필요할 때 조회하여 바로 `messages` 리스트에 밀어 넣기 유리하다.

### 📌 메모리 관리 전략 5가지

대화가 길어진다고 해서 모든 메시지를 끝없이 누적해 전달할 수는 없다. 메시지가 지나치게 쌓이면 다음과 같은 치명적인 문제가 발생한다.

- 비용 및 지연 시간 증가: 입력 토큰이 늘어날수록 API 호출 비용이 상승하고 응답 속도가 현저히 느려진다.
- 컨텍스트 윈도우 초과: 모델이 한 번에 처리할 수 있는 입력 한계를 넘어가면, 정보가 잘리거나 누락되어 에러가 발생한다.
- 어텐션 분산: 초기에 설정한 핵심 규칙이 방대한 과거 대화에 밀려 모델의 지시 수행 능력이 떨어질 수 있다.
- 할루시네이션 및 정보 충돌: 너무 오래된 정보와 최신 정보가 혼재하면, 모델이 임의로 정보를 섞거나 잘못된 결론을 내린다.

실무에서의 메모리 관리란 단순히 대화를 저장하는 것이 아니라, 한정된 토큰 예산 내에서 모델의 입력으로 제공할 핵심 정보를 선별하는 최적화 작업이다.

**전략 1) 슬라이딩 윈도우 (최근 N턴만 유지)**

일반적인 챗봇처럼 '가장 최근의 대화 맥락'이 제일 중요할 때 사용한다.

- 장점: 구현이 가장 직관적이고, 비용과 지연 시간을 쉽게 예측할 수 있다.
- 단점: 대화 초반에 설정한 중요한 제약사항이나 사용자의 이름을 쉽게 잃어버릴 수 있다.

**전략 2) 토큰 예산 기반 트리밍 (권장 기본값)**

대화 턴 수보다 실제 사용되는 토큰 수를 엄격히 제한해야 할 때 적합하다. 랭체인의 `trim_messages`를 사용하면 정교한 통제가 가능하다.

```python
from langchain_core.messages.utils import trim_messages, count_tokens_approximately

trimmed_messages = trim_messages(
    messages,
    strategy="last",            # 오래된 대화를 버리고 최근 대화를 유지
    token_counter=count_tokens_approximately,
    max_tokens=2000,
    include_system=True,        # 시스템 메시지는 잘려나가지 않도록 고정(핀)
    start_on="human",           # 잘라냈을 때 첫 시작이 무조건 사람의 질문이 되도록 보장
    end_on=("human", "tool"),
)

response = model.invoke(trimmed_messages)
```

**전략 3) 요약(Summary) + 최근 대화 유지 (하이브리드)**

대화는 매우 길어지지만 전체적인 흐름과 결정 사항은 유지해야 할 때 사용한다. 언어 모델을 이용해 과거 대화를 주기적으로 하나의 요약본으로 압축 생성해 토큰을 크게 절약하는 방법이다. 실무에서는 보통 '요약본 1개 + 최근 원문 대화 N개'의 하이브리드 방식을 많이 사용하며, 요약본은 시스템 메시지 쪽에 고정해 둔다.

**전략 4) 상태(State) 분리 및 구조화**

사용자의 프로필, 달성 목표, 제약 조건 등 대화 내내 절대 누락되어서는 안 되는 사실들을 대화 원문에서 추출해 별도의 '상태(State)'로 관리한다. 이를 통해 프롬프트 충돌을 막고 답변의 일관성을 비약적으로 높일 수 있다. (랭그래프에서 배운다)

**전략 5) 검색 기반 메모리 (RAG 활용)**

대화 기록이 방대하여 필요할 때만 과거 정보를 찾아 써야 하는 경우에 활용한다. 전체 대화를 주입하는 대신, 질문과 연관성 높은 과거 조각만 검색해 프롬프트에 끼워 넣는다.

| 전략 | 특징 | 적합한 상황 |
| --- | --- | --- |
| 슬라이딩 윈도우 | 가장 단순, 예측 가능 | 일반 챗봇, 짧은 대화 |
| 토큰 예산 기반 트리밍 | 정교한 토큰 통제 | 비용 중요, 프로덕션 기본값 |
| 요약 + 최근 대화 하이브리드 | 흐름 유지 + 토큰 절약 | 긴 대화, 결정 사항 유지 필요 |
| 상태(State) 분리 | 핵심 정보 누락 방지 | 복잡한 에이전트, 랭그래프 |
| 검색 기반 메모리 (RAG) | 필요한 과거만 선별 | 방대한 히스토리, 장기 메모리 |

---

## 📗 8. 랭스미스 (2-5)

---

### 📌 랭스미스를 왜 쓰나

랭체인/랭그래프로 만든 애플리케이션을 추적하고, 결과를 평가하고, 운영 단계에서 모니터링하는 데 도움이 되는 도구다. 에이전트가 고도화될수록 내부 동작이 복잡해지는데, 이때 "어디서 어떤 입력으로 무엇이 실행됐는지"를 눈으로 확인할 수 있어야 디버깅과 품질 개선이 쉬워진다.

랭스미스를 연결하면 다음 작업이 쉬워진다.

- 모델 호출이 어떤 순서로 일어났는지, 어떤 입력/출력으로 흘렀는지 실행 경로를 추적할 수 있다.
- 특정 프롬프트/체인/에이전트가 테스트 데이터에서 잘 동작하는지 평가할 수 있다.
- 운영 시점에 토큰 사용량, 레이턴시, 에러 같은 지표를 확인해 모니터링할 수 있다.

즉, "잘 만들었다"를 넘어서 "운영 가능한 수준으로 관리한다"는 관점에서 도움이 된다.

### 📌 랭스미스 계정과 API 키 준비

1. 랭스미스 사이트(smith.langchain.com)에서 계정 생성
2. 화면 좌측 하단 설정(Settings)에서 API Key를 발급
3. 발급 받은 키를 실행 환경(Colab/로컬)의 환경변수로 설정

### 📌 환경변수 설정

LangSmith 추적을 켜려면, 모델을 임포트/초기화하기 전에 설정을 먼저 잡아둬야 한다.

```python
import os

# 1) 랭스미스 추적 기능 켜기
os.environ["LANGCHAIN_TRACING_V2"] = "true"

# 2) 랭스미스 API 키 설정
os.environ["LANGCHAIN_API_KEY"] = "ls__xxx"

# 3) 프로젝트 생성(또는 선택)
os.environ["LANGCHAIN_PROJECT"] = "My_First_Agent"
```

`LANGCHAIN_PROJECT`는 "실행 로그를 묶는 단위"다. 실습 단계에서는 "My_First_Agent"처럼 간단한 이름으로 시작하면 충분하다.

### 📌 실행 및 확인

```python
from langchain.chat_models import init_chat_model

model = init_chat_model("gpt-5-nano")
response = model.invoke("랭스미스가 무엇인지 한 문장으로 설명해줘.")
print(f"답변: {response.content}")
```

```
답변: 랭스미스는 랭체인이 제공하는 LLM 애플리케이션의 테스트와 모니터링, 디버깅을 돕는 도구이자 플랫폼이다.
```

LangSmith 대시보드의 프로젝트 화면으로 이동하면 방금 실행한 호출이 기록되어 있다. 다음 정보를 함께 확인할 수 있다.

| 확인 항목 | 설명 |
| --- | --- |
| 입력과 출력 | 프롬프트/응답 내용 |
| 실행 시간 | 시작/종료 시각, 레이턴시 |
| 토큰 사용량 | 입력/출력/총합 토큰 수 |
| 상태 | 성공/실패 여부 |

---

## 📗 9. 정리

---

01~02장에서 배운 핵심 내용을 한 줄씩 요약하면 다음과 같다.

- AI 에이전트는 LLM이라는 두뇌에 도구라는 손발을 달아 현실 업무를 직접 해결하는 시스템이다.
- `init_chat_model()`로 모델을 초기화하고, `invoke()` / `stream()` / `batch()`로 상황에 맞게 호출한다.
- `temperature`는 창의성 vs 일관성 트레이드오프이므로, RAG/코드 생성은 0.0~0.1, 창작은 0.7~1.0으로 설정한다.
- 구조화된 출력은 후처리 자동화의 핵심이다. 파이썬 환경이라면 Pydantic을 기본으로, 크로스 언어 공유가 필요하면 JSON Schema를 사용한다.
- 메모리는 과거 메시지 리스트를 다시 주입하는 방식으로 구현되며, 프로덕션에서는 토큰 예산 기반 트리밍을 기본값으로 사용한다.
- 랭스미스는 `LANGCHAIN_TRACING_V2=true` 환경변수 하나로 즉시 연결되며, 실행 경로 추적과 토큰 사용량 모니터링이 가능해진다.

---

## 참고 자료

- 위키독스 - AI 에이전트는 이렇게 만든다 (랭체인부터 랭그래프까지): <https://wikidocs.net/book/19240>
- LangChain 공식 문서 - Messages: <https://python.langchain.com/docs/concepts/messages/>
- LangChain 공식 문서 - trim_messages: <https://python.langchain.com/api_reference/core/messages/langchain_core.messages.utils.trim_messages.html>
- LangSmith 공식 사이트: <https://smith.langchain.com>
- OpenAI Platform - Models: <https://platform.openai.com/docs/models>
