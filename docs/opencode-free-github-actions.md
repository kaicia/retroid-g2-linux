# OpenCode 무료 GitHub Actions 환경 기록

## 목적

이 문서는 Retroid Pocket G2 SteamOS/Linux 포팅 프로젝트에서 사용하는 **OpenCode + GitHub Actions + OpenRouter 무료 모델** 환경을 다시 구성할 수 있도록 설정과 시행착오를 기록한다.

문제가 재발하면 이 문서를 기준점으로 삼아 현재 환경을 먼저 복구/검증한 뒤 프로젝트 작업을 재개한다.

## 현재 성공한 구성

```text
GitHub PR / Issue comment
        |
        | /opencode 또는 /oc
        v
GitHub Actions
        |
        v
anomalyco/opencode/github@latest
        |
        | OPENROUTER_API_KEY
        v
OpenRouter
        |
        v
cohere/north-mini-code:free
```

현재 workflow 파일:

`.github/workflows/opencode.yml`

현재 핵심 설정:

```yaml
permissions:
  id-token: write
  contents: write
  pull-requests: write
  issues: write

- name: Run OpenCode with OpenRouter free tool-capable coding model
  uses: anomalyco/opencode/github@latest
  env:
    OPENROUTER_API_KEY: ${{ secrets.OPENROUTER_API_KEY }}
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    model: openrouter/cohere/north-mini-code:free
    use_github_token: true
```

## GitHub Secret

Repository Settings → Secrets and variables → Actions에 다음 Secret을 등록한다.

```text
OPENROUTER_API_KEY
```

API Key 자체는 절대로 이 문서나 GitHub 파일에 기록하지 않는다.

## 실행 방법

PR 또는 Issue의 댓글에 다음과 같이 입력한다.

```text
/opencode
```

또는

```text
/oc
```

현재 workflow는 `issue_comment`와 `pull_request_review_comment`의 created 이벤트를 감시한다.

## 권한

OpenCode가 실제 프로젝트 파일을 수정하고 commit/push할 수 있도록 workflow에 다음 권한이 필요하다.

- `contents: write`
- `pull-requests: write`
- `issues: write`

또한 OpenCode Action에 `GITHUB_TOKEN`을 전달하고 `use_github_token: true`를 사용한다.

## 중요한 테스트 이력

### 실패 1 — DeepSeek V4 Flash Free

사용 시도:

```text
openrouter/deepseek/deepseek-v4-flash:free
```

결과:

```text
Model not found / model unavailable for free
```

원인: 당시 OpenRouter에서 해당 모델의 무료 제공이 더 이상 가능하지 않았음.

### 실패 2 — Qwen3 Coder Free

사용 시도:

```text
openrouter/qwen/qwen3-coder:free
```

결과:

```text
This model is unavailable for free
```

원인: 당시 OpenRouter에서 해당 모델의 무료 제공이 더 이상 가능하지 않았음.

### 실패 3 — openrouter/free

사용 시도:

```text
openrouter/free
```

결과: OpenCode에서 동적 무료 라우터를 모델로 처리하는 과정에서 `Model not found` 문제가 발생하여 고정 모델 방식으로 전환.

### 실패 4 — GPT-OSS 20B Free

사용 시도:

```text
openrouter/openai/gpt-oss-20b:free
```

모델 자체는 무료였지만 당시 provider들이 모두 capacity 부족 상태가 되어:

```text
HTTP 502
provider_unavailable
all providers for model ... are at capacity
queue timeout
```

이 발생함.

### 성공 — Cohere North Mini Code Free

현재 사용:

```text
openrouter/cohere/north-mini-code:free
```

이 모델로 실행한 OpenCode GitHub Actions 테스트가 **Run #7에서 성공**했다.

따라서 현재까지 확인된 사실은:

- GitHub Actions workflow 실행 가능
- `OPENROUTER_API_KEY` Secret 전달 가능
- OpenCode GitHub Action 실행 가능
- OpenRouter 인증/호출 가능
- 무료 tool-capable coding model로 OpenCode 실행 가능

## 현재 성공 테스트의 한계

Run #7은 **읽기 전용 연결 테스트**였다. 즉 파일 수정/commit/push를 금지한 테스트였기 때문에, Run #7 성공만으로 실제 프로젝트 파일을 수정하고 원격 branch에 push하는 전체 작업 흐름이 성공했다고 판단하면 안 된다.

실제 Phase 0 작업에서는 다음을 별도로 검증한다.

1. OpenCode가 저장소를 읽는다.
2. 필요한 문서를 작성/수정한다.
3. `git status`와 `git diff`를 확인한다.
4. task 관련 파일만 commit한다.
5. GitHub PR branch에 실제 push한다.
6. commit SHA를 보고한다.
7. GitHub에서 실제 파일과 commit이 존재하는지 확인한다.

## 프로젝트 작업 원칙

실제 G2 작업에서는 OpenCode에게 다음을 명확히 지시한다.

- 물리 G2에 접근하지 않는 조사 단계와 실제 ADB 단계는 구분한다.
- bootloader unlock, flashing, partition 변경 등 파괴적 작업을 자동으로 실행하지 않는다.
- private user data를 수집하지 않는다.
- 공개 자료와 실제 G2에서 확인해야 할 정보를 구분한다.
- 작업 완료 보고만 믿지 말고 GitHub의 실제 commit/diff를 확인한다.

## 재발 시 복구 순서

무료 OpenCode 환경이 다시 작동하지 않으면 다음 순서로 확인한다.

1. `.github/workflows/opencode.yml` 확인
2. `OPENROUTER_API_KEY` Secret 존재 여부 확인
3. `contents: write`, `pull-requests: write`, `issues: write` 확인
4. `GITHUB_TOKEN` 및 `use_github_token: true` 확인
5. 현재 OpenRouter에서 `cohere/north-mini-code:free`가 실제 무료인지 확인
6. 무료 모델이 변경되었다면 OpenRouter의 현재 tool-capable 무료 모델을 확인
7. 연결 테스트는 먼저 읽기 전용으로 실행
8. 성공 후 실제 파일 수정/commit/push 테스트 실행
9. Actions 성공 여부와 별개로 GitHub branch/PR의 실제 diff와 commit을 확인

## 주의

OpenRouter 무료 모델의 이름, 무료 제공 여부, provider capacity는 변경될 수 있다. 따라서 이 문서의 모델명을 영구적인 사실로 간주하지 말고 **재시작 시 현재 OpenRouter 상태를 다시 검증**한다.

API Key, 개인 토큰, 비밀값은 이 문서에 저장하지 않는다.
