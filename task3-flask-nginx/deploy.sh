#!/usr/bin/env bash
# Деплой Task 3 на ECS on EC2.
#
# Шаги:
#   1) Создаёт два приватных ECR-репо (если не существуют)
#   2) Билдит и пушит образы Flask и Nginx
#   3) Узнаёт default VPC и одну public subnet с auto-assign public IP
#   4) sam/cfn deploy: ECS cluster, EC2, Task Def, Service
#   5) Печатает публичный URL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# подгружаем .env
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
CLUSTER_NAME="${TASK3_CLUSTER_NAME:-event-platform-task3}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo ">>> Account:  $ACCOUNT_ID"
echo ">>> Region:   $AWS_REGION"
echo ">>> Stack:    $STACK_NAME"
echo ""

# ---- 1) ECR repos ----
for repo in "$ECR_FLASK_REPO" "$ECR_NGINX_REPO"; do
    if ! aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1; then
        echo ">>> Создаю ECR repo: $repo"
        aws ecr create-repository --repository-name "$repo" --region "$AWS_REGION" >/dev/null
    fi
done

# ---- 2) build & push ----
echo ">>> docker login -> $ECR_REGISTRY"
aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "$ECR_REGISTRY"

FLASK_IMAGE="${ECR_REGISTRY}/${ECR_FLASK_REPO}:latest"
NGINX_IMAGE="${ECR_REGISTRY}/${ECR_NGINX_REPO}:latest"

echo ">>> docker build flask"
docker build --platform linux/amd64 -t "$FLASK_IMAGE" -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"

echo ">>> docker build nginx"
docker build --platform linux/amd64 -t "$NGINX_IMAGE" -f "$SCRIPT_DIR/Dockerfile.nginx" "$SCRIPT_DIR"

echo ">>> docker push flask"
docker push "$FLASK_IMAGE"

echo ">>> docker push nginx"
docker push "$NGINX_IMAGE"

# ---- 3) default VPC + public subnet ----
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=is-default,Values=true" \
    --region "$AWS_REGION" \
    --query "Vpcs[0].VpcId" --output text)

if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
    echo "ERROR: нет default VPC в регионе $AWS_REGION. Создай руками или укажи существующий."
    exit 1
fi

SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=true" \
    --region "$AWS_REGION" \
    --query "Subnets[0].SubnetId" --output text)

if [[ -z "$SUBNET_ID" || "$SUBNET_ID" == "None" ]]; then
    echo "ERROR: в default VPC нет публичной subnet."
    exit 1
fi

echo ">>> VPC:    $VPC_ID"
echo ">>> Subnet: $SUBNET_ID"

# ---- 4) CloudFormation deploy ----
echo ">>> cfn deploy $STACK_NAME"
aws cloudformation deploy \
    --template-file "$SCRIPT_DIR/template.yaml" \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --capabilities CAPABILITY_IAM \
    --parameter-overrides \
        ClusterName="$CLUSTER_NAME" \
        VpcId="$VPC_ID" \
        SubnetId="$SUBNET_ID" \
        FlaskImageUri="$FLASK_IMAGE" \
        NginxImageUri="$NGINX_IMAGE"

# заставляем сервис подтянуть свежие образы (если CFN ничего не поменял в TaskDef)
aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service flask-nginx \
    --force-new-deployment \
    --region "$AWS_REGION" >/dev/null || true

# ---- 5) public URL ----
PUBLIC_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='PublicUrl'].OutputValue | [0]" \
    --output text)

echo ""
echo ">>> Готово."
echo "    Сервис запускается ~30-60 сек, после чего:"
echo "    $PUBLIC_URL/events"
echo "    $PUBLIC_URL/health"
echo ""
echo "    Проверь статус task'а:"
echo "    aws ecs list-tasks --cluster $CLUSTER_NAME --region $AWS_REGION"
