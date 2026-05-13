#!/usr/bin/env bash

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

STACK_NAME="${TASK3_STACK_NAME:-event-platform-task3}"
ECR_FLASK_REPO="${TASK3_ECR_FLASK_REPO:-event-platform/flask}"
ECR_NGINX_REPO="${TASK3_ECR_NGINX_REPO:-event-platform/nginx}"

# ---- 1) Снять все задачи с сервиса ----
CLUSTER_NAME="${TASK3_CLUSTER_NAME:-event-platform-task3}"
echo ">>> Останавливаю service flask-nginx"
aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service flask-nginx \
    --desired-count 0 \
    --region "$AWS_REGION" >/dev/null 2>&1 || echo "    service отсутствует"

# ---- 2) Дерегистрировать container instances (EC2 в кластере) ----
echo ">>> Дерегистрирую container instances"
for arn in $(aws ecs list-container-instances \
        --cluster "$CLUSTER_NAME" \
        --region "$AWS_REGION" \
        --query 'containerInstanceArns[]' --output text 2>/dev/null); do
    [[ -n "$arn" && "$arn" != "None" ]] || continue
    echo "    $arn"
    aws ecs deregister-container-instance \
        --cluster "$CLUSTER_NAME" \
        --container-instance "$arn" \
        --force \
        --region "$AWS_REGION" >/dev/null 2>&1 || true
done

# ---- 3) CFN delete-stack ----
echo ">>> Удаляю CFN стек $STACK_NAME"
aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION"
echo ">>> Жду..."
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$AWS_REGION"
echo ">>> Стек удалён."

# ---- 4) ECR удалить (с образами) ----
for repo in "$ECR_FLASK_REPO" "$ECR_NGINX_REPO"; do
    if aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1; then
        echo ">>> Удаляю ECR repo $repo"
        aws ecr delete-repository --repository-name "$repo" --force --region "$AWS_REGION" >/dev/null
    fi
done

echo ""
echo ">>> Готово. Проверь:"
echo "    aws ec2 describe-instances --filters 'Name=tag:Name,Values=${CLUSTER_NAME}-ec2' \\"
echo "      --query 'Reservations[].Instances[?State.Name!=\`terminated\`].[InstanceId]' --output text"
