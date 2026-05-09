## Структура

```
event-platform-aws/
├── task1-web-s3/          # 1) Статический веб-интерфейс на S3
├── task2-api/             # 2) REST API на API Gateway + Lambda + DynamoDB
├── task3-flask-nginx/     # 3) Балансировка: Flask × 2 + Nginx через Docker Compose
├── task4-spark/           # 4) PySpark батч — популярность мероприятий
├── task5-flink-kinesis/   # 5) PyFlink + Kinesis — активные пользователи онлайн
├── task6-ml-ludwig/       # 6) Ludwig модель + OpenSearch поиск по TF-IDF
├── .env.example           # Шаблон переменных окружения
└── README.md
```

## Настройка окружения

```bash
cp .env.example .env
source .env
```

Инструкции по запуску каждого задания добавляются в этот README по мере их выполнения.

---

## Task 1

Папка: `task1-web-s3/`

- форма создания мероприятий (название, дата, описание) — `POST /event`
- бар-чарт регистраций по мероприятиям — `GET /stats`

API_BASE_URL подставляется в `config.js` скриптом `deploy.sh` из значения `.env`. На этапе Task 1 API ещё не существует, поэтому форма будет показывать ошибку — это нормально, реальный API появится в Task 2.

### Структура

```
task1-web-s3/
├── index.html
├── style.css
├── app.js
├── config.example.js   ← шаблон (коммитится)
├── config.js           ← генерируется deploy.sh (не коммитится)
└── deploy.sh
```

### Запуск

Заполнить `.env` (как минимум `AWS_REGION`, `S3_WEB_BUCKET`, `API_BASE_URL`). Бакет в `S3_WEB_BUCKET` должен быть глобально уникальным — например `event-platform-web-<логин>`.

```bash
cd task1-web-s3
./deploy.sh
```

Скрипт:

1. Сгенерирует `config.js` с реальным `API_BASE_URL`
2. Создаст S3 бакет (если его нет), выключит block-public-access и навесит публичную read-policy
3. Включит S3 static website hosting
4. Зальёт `index.html`, `style.css`, `app.js`, `config.js`
5. Распечатает публичный website endpoint вида `http://<bucket>.s3-website.<region>.amazonaws.com`

---

## Task 2 — REST API (API Gateway + Lambda + DynamoDB)

Папка: `task2-api/`

Контракт описан в `openapi.yaml`. Инфраструктура — AWS SAM (`template.yaml`).

Эндпоинты:
- `POST /event` → Lambda `create-event` → пишет в DynamoDB `Events`
- `POST /register` → Lambda `register-user` → пишет в `Registrations` + атомарно увеличивает счётчик `registrations` в `Events`
- `GET /stats` → Lambda `get-stats` → возвращает список мероприятий с количеством регистраций

CORS включён через API Gateway (`AllowOrigin: *`) — фронтенд из Task 1 ходит сюда напрямую.

### Структура
```
task2-api/
├── openapi.yaml                # OpenAPI 3.0 спека
├── template.yaml               # AWS SAM (Lambda + API Gateway + DynamoDB)
├── deploy.sh                   # sam build + sam deploy
├── teardown.sh                 # удаление стека и log-групп
├── smoke-test.sh               # 4 curl-проверки
└── lambdas/
    ├── create-event/index.mjs
    ├── register-user/index.mjs
    └── get-stats/index.mjs
```

### Требования
- AWS SAM CLI: `brew install aws-sam-cli`
- Docker (нужен только если будешь использовать `sam local invoke`/`sam local start-api`)
- `jq` для smoke-test: `brew install jq`

### Запуск

```bash
# из корня репо: убедись, что .env заполнен (SAM_STACK_NAME, AWS_REGION)
cd task2-api
./deploy.sh
```

Скрипт соберёт функции, развернёт стек CloudFormation и распечатает `API_BASE_URL` вида:
```
https://abcd1234.execute-api.eu-north-1.amazonaws.com/Prod
```

Это значение нужно положить в `.env` как `API_BASE_URL`, после чего пере-задеплоить Task 1 (`./task1-web-s3/deploy.sh`), чтобы фронтенд начал ходить в реальный API.

### Проверка

```bash
./smoke-test.sh
# создаст мероприятие, зарегистрирует двух участников, прочитает /stats
```

Или открой задеплоенный сайт из Task 1 — форма создания и обновление чарта должны работать.

### Удаление

```bash
./teardown.sh
# удалит стек, обе DynamoDB таблицы, Lambda функции и их CloudWatch log-группы
```
