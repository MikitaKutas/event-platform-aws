#!/usr/bin/env bash
# Deploy статического сайта на S3.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# подгружаем .env если он есть
if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a
    source "$ROOT_DIR/.env"
    set +a
fi

: "${AWS_REGION:?AWS_REGION не задан (см. .env)}"
: "${S3_WEB_BUCKET:?S3_WEB_BUCKET не задан (см. .env)}"
: "${API_BASE_URL:?API_BASE_URL не задан (см. .env)}"

echo ">>> Бакет:        $S3_WEB_BUCKET"
echo ">>> Регион:       $AWS_REGION"
echo ">>> API base url: $API_BASE_URL"

# 1) генерируем config.js (НЕ коммитится — он в .gitignore)
cat > "$SCRIPT_DIR/config.js" <<EOF

window.__CONFIG__ = {
    API_BASE_URL: "$API_BASE_URL"
};
EOF

# 2) создаём бакет, если его нет
if ! aws s3api head-bucket --bucket "$S3_WEB_BUCKET" 2>/dev/null; then
    echo ">>> Создаю бакет $S3_WEB_BUCKET"
    if [[ "$AWS_REGION" == "us-east-1" ]]; then
        aws s3api create-bucket --bucket "$S3_WEB_BUCKET" --region "$AWS_REGION"
    else
        aws s3api create-bucket \
            --bucket "$S3_WEB_BUCKET" \
            --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
fi

# 3) выключаем block-public-access и навешиваем bucket policy на public read
aws s3api put-public-access-block \
    --bucket "$S3_WEB_BUCKET" \
    --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

cat > /tmp/bucket-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "PublicReadGetObject",
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::$S3_WEB_BUCKET/*"
  }]
}
EOF
aws s3api put-bucket-policy --bucket "$S3_WEB_BUCKET" --policy file:///tmp/bucket-policy.json

# 4) включаем static website hosting
aws s3 website "s3://$S3_WEB_BUCKET/" --index-document index.html --error-document index.html

# 5) загружаем статику
aws s3 cp "$SCRIPT_DIR/index.html"  "s3://$S3_WEB_BUCKET/index.html"  --content-type "text/html;charset=utf-8"
aws s3 cp "$SCRIPT_DIR/style.css"   "s3://$S3_WEB_BUCKET/style.css"   --content-type "text/css;charset=utf-8"
aws s3 cp "$SCRIPT_DIR/app.js"      "s3://$S3_WEB_BUCKET/app.js"      --content-type "application/javascript;charset=utf-8"
aws s3 cp "$SCRIPT_DIR/config.js"   "s3://$S3_WEB_BUCKET/config.js"   --content-type "application/javascript;charset=utf-8"

WEBSITE_URL="http://${S3_WEB_BUCKET}.s3-website.${AWS_REGION}.amazonaws.com"
echo ""
echo ">>> Сайт доступен по адресу:"
echo "    $WEBSITE_URL"
