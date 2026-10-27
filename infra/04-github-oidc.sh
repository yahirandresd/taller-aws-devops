#!/usr/bin/env bash
# Rol IAM que GitHub Actions asume por OIDC (sin access keys guardadas en GitHub).
# Al terminar, copie el ARN impreso en GitHub > Settings > Secrets and variables >
# Actions > Variables como AWS_ROLE_ARN.
source "$(dirname "$0")/config.sh"

PROVIDER_ARN="arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$PROVIDER_ARN" >/dev/null 2>&1; then
  log "Proveedor OIDC de GitHub"
  aws iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 >/dev/null
fi

TRUST="$(printf '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Federated":"%s"},"Action":"sts:AssumeRoleWithWebIdentity","Condition":{"StringEquals":{"token.actions.githubusercontent.com:aud":"sts.amazonaws.com"},"StringLike":{"token.actions.githubusercontent.com:sub":"repo:%s:*"}}}]}' \
  "$PROVIDER_ARN" "$GITHUB_REPO")"

if aws iam get-role --role-name "$ROLE_GITHUB" >/dev/null 2>&1; then
  aws iam update-assume-role-policy --role-name "$ROLE_GITHUB" --policy-document "$TRUST"
else
  log "Rol $ROLE_GITHUB (solo repo $GITHUB_REPO)"
  aws iam create-role --role-name "$ROLE_GITHUB" --assume-role-policy-document "$TRUST" >/dev/null
fi

# Mínimo privilegio: publicar en el repo ECR del proyecto y desplegar/consultar App Runner.
aws iam put-role-policy --role-name "$ROLE_GITHUB" --policy-name despliegue-observatorio --policy-document "$(printf '{
  "Version":"2012-10-17",
  "Statement":[
    {"Effect":"Allow","Action":"ecr:GetAuthorizationToken","Resource":"*"},
    {"Effect":"Allow","Action":["ecr:BatchCheckLayerAvailability","ecr:BatchGetImage","ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload","ecr:UploadLayerPart","ecr:CompleteLayerUpload","ecr:PutImage","ecr:DescribeImages"],
     "Resource":"arn:aws:ecr:%s:%s:repository/%s"},
    {"Effect":"Allow","Action":["apprunner:ListServices","apprunner:ListOperations"],"Resource":"*"},
    {"Effect":"Allow","Action":["apprunner:StartDeployment","apprunner:DescribeService"],
     "Resource":"arn:aws:apprunner:%s:%s:service/%s-api-*/*"}
  ]}' "$AWS_REGION" "$ACCOUNT_ID" "$ECR_REPO" "$AWS_REGION" "$ACCOUNT_ID" "$PROJECT")"

log "AWS_ROLE_ARN = $(aws iam get-role --role-name "$ROLE_GITHUB" --query Role.Arn --output text)"
