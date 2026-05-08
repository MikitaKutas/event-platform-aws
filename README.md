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
