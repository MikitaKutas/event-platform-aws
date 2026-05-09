#!/usr/bin/env bash
# Сборка и деплой Lambda + API Gateway + DynamoDB через AWS SAM.
#
# Что делает:
#   1) Подгружает .env (AWS_REGION, SAM_STACK_NAME)
#   2) `sam build` — собирает функции
#   3) `sam deploy` — разворачивает/обновляет CloudFormation стек
#   4) Печатает ApiBaseUrl из Outputs стека

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

cd "$SCRIPT_DIR"

echo ">>> sam build"
sam build

echo ">>> sam deploy --stack-name $SAM_STACK_NAME --region $AWS_REGION"
sam deploy \
    --stack-name "$SAM_STACK_NAME" \
    --region "$AWS_REGION" \
    --capabilities CAPABILITY_IAM \
    --resolve-s3 \
    --no-confirm-changeset \
    --no-fail-on-empty-changeset

API_BASE_URL=$(aws cloudformation describe-stacks \
    --stack-name "$SAM_STACK_NAME" \
    --region "$AWS_REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='ApiBaseUrl'].OutputValue | [0]" \
    --output text)

echo ""
echo ">>> Готово."
echo "    API base URL: $API_BASE_URL"
echo ""
echo "    Положи это значение в .env:"
echo "    API_BASE_URL=$API_BASE_URL"
