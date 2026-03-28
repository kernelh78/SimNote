# Tools

이 폴더에는 실제 작업을 실행하는 Python 파일들이 들어갑니다.

## 규칙

- Tool 하나 = 기능 하나
- 새 Tool 만들기 전에 기존 것부터 확인
- API 키는 절대 여기 넣지 말고 `.env`에서 불러올 것
- 각 Tool은 단독으로 테스트 가능해야 함

## 사용 방법

```python
# .env 불러오는 기본 패턴
from dotenv import load_dotenv
import os

load_dotenv()
API_KEY = os.getenv("MY_API_KEY")
```
