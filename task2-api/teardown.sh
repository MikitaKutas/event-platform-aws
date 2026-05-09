#!/usr/bin/env bash
# Полностью удаляет стек: Lambda функции, API Gateway, DynamoDB таблицы и логи.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$ROOT_DIR/.env"
    set +a
fi

: "${AWS_REGION:?AWS_REGION не задан (см. .env)}"
: "${SAM_STACK_NAME:?SAM_STACK_NAME не задан (см. .env)}"

echo ">>> Удаляю стек $SAM_STACK_NAME в $AWS_REGION"
aws cloudformation delete-stack --stack-name "$SAM_STACK_NAME" --region "$AWS_REGION"

echo ">>> Жду завершения удаления..."
aws cloudformation wait stack-delete-complete --stack-name "$SAM_STACK_NAME" --region "$AWS_REGION"
echo ">>> Стек удалён."

# CloudWatch log-группы Lambda не удаляются вместе со стеком, чистим вручную
for fn in event-platform-create-event event-platform-register-user event-platform-get-stats; do
    aws logs delete-log-group --log-group-name "/aws/lambda/$fn" --region "$AWS_REGION" 2>/dev/null \
        && echo "    log group /aws/lambda/$fn удалён" \
        || echo "    log group /aws/lambda/$fn уже нет"
done

echo ">>> Готово. Проверь, что таблиц нет:"
aws dynamodb list-tables --region "$AWS_REGION" --query 'TableNames'
