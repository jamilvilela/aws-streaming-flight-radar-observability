#!/bin/bash
# setup-env.sh - Deploy CloudWatch Dashboard + Alarmes de Observabilidade
#
# Usage:   ./setup-env.sh
# Aliases: ./setup-env.sh --skip-apply   # init/validate/plan only
#          ./setup-env.sh --no-verify    # skip post-deploy checks
#
# Exit codes:
#   0  success
#   1  prerequisites missing (env, tfvars, credentials)
#   2  terraform step failed
#   3  post-deploy verification found missing resources

set -a  # export everything we `source`

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# CLI flags
# ---------------------------------------------------------------------------
SKIP_APPLY=0
NO_VERIFY=0
for arg in "$@"; do
  case "$arg" in
    --skip-apply) SKIP_APPLY=1 ;;
    --no-verify)  NO_VERIFY=1 ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
section() { echo -e "\n${BOLD}${BLUE}== $* ==${NC}"; }
ok()      { echo -e "  ${GREEN}✅ $*${NC}"; }
warn()    { echo -e "  ${YELLOW}⚠️  $*${NC}"; }
fail()    { echo -e "  ${RED}❌ $*${NC}"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { fail "Comando obrigatório ausente: $1"; exit 1; }
}

# ---------------------------------------------------------------------------
# STEP 1: Load .env
# ---------------------------------------------------------------------------
section "STEP 1 — Carregando .env"

if [ ! -f .env ]; then
  fail "Arquivo .env não encontrado na raiz do projeto."
  echo "   Copie .env.example para .env e preencha com seus valores"
  echo "   cp .env.example .env"
  exit 1
fi
source .env
ok "Variáveis de .env carregadas"

if [ -n "$AWS_REGION" ]; then
  export TF_VAR_aws_region="$AWS_REGION"
fi

# Observability repo — no RDS credentials needed

# ---------------------------------------------------------------------------
# STEP 2: AWS credentials sanity check (warn only, do not block)
# ---------------------------------------------------------------------------
section "STEP 2 — Verificando credenciais AWS"

CREDENTIALS_FOUND=0

# Check 1: environment variables
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
  CREDENTIALS_FOUND=1
  ok "Credenciais AWS via environment variables"
fi

# Check 2: aws configure (default profile)
if [ "$CREDENTIALS_FOUND" -eq 0 ] && [ -f "$HOME/.aws/credentials" ]; then
  if grep -q "aws_access_key_id" "$HOME/.aws/credentials" 2>/dev/null; then
    CREDENTIALS_FOUND=1
    ok "Credenciais AWS via aws configure (default profile)"
  fi
fi

# Check 3: try sts get-caller-identity (covers SSO, instance profile, etc.)
if [ "$CREDENTIALS_FOUND" -eq 0 ]; then
  if aws sts get-caller-identity &>/dev/null; then
    CREDENTIALS_FOUND=1
    ok "Credenciais AWS ativas (SSO / instance profile / environment)"
  fi
fi

if [ "$CREDENTIALS_FOUND" -eq 0 ]; then
  warn "Nenhuma credencial AWS encontrada."
  echo "   Configure com 'aws configure', exporte AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY,"
  echo "   ou use uma role/SSO via 'aws sso login'."
  echo "   Continuando (pode falhar no terraform apply se não houver credenciais)."
fi

# ---------------------------------------------------------------------------
# STEP 3: Move into infra/
# ---------------------------------------------------------------------------
section "STEP 3 — Acessando diretório infra/"

if [ ! -d "infra" ]; then
  fail "Diretório infra/ não encontrado. Execute este script da raiz do projeto."
  exit 1
fi
cd infra || exit 1
ok "Diretório atual: $(pwd)"

set +a  # done auto-exporting

TFVARS_FILE="tfvars/terraform.tfvars"
if [ ! -f "$TFVARS_FILE" ]; then
  fail "Arquivo de variáveis '$TFVARS_FILE' não encontrado."
  echo "   Crie a partir do template: cp tfvars/terraform.tfvars.example tfvars/terraform.tfvars"
  exit 1
fi

# ---------------------------------------------------------------------------
# STEP 4-7: Terraform init/validate/plan/apply
# ---------------------------------------------------------------------------
section "STEP 4 — terraform init"
terraform init
[ $? -ne 0 ] && { fail "terraform init falhou"; exit 2; }
ok "init concluído"

section "STEP 5 — terraform validate"
terraform validate
[ $? -ne 0 ] && { fail "terraform validate falhou"; exit 2; }
ok "validate concluído"

section "STEP 6 — terraform plan"
terraform plan -var-file="$TFVARS_FILE" -out=tfplan
[ $? -ne 0 ] && { fail "terraform plan falhou"; exit 2; }
ok "plan concluido (salvo em tfplan)"

if [ "$SKIP_APPLY" -eq 1 ]; then
  warn "--skip-apply informado; apply nao sera executado."
else
  section "STEP 7 — terraform apply"
  terraform apply -var-file="$TFVARS_FILE" -auto-approve tfplan
  [ $? -ne 0 ] && { fail "terraform apply falhou"; exit 2; }
  ok "apply concluido"

fi

# ---------------------------------------------------------------------------
# STEP 8: Show Terraform outputs
# ---------------------------------------------------------------------------
section "STEP 8 — Outputs do Terraform"

require_cmd terraform

echo -e "  ${BLUE}-- CloudWatch Dashboard --${NC}"
terraform output dashboard_name 2>/dev/null && echo "" || warn "dashboard_name ausente"
terraform output dashboard_arn 2>/dev/null && echo "" || warn "dashboard_arn ausente"
terraform output dashboard_url 2>/dev/null && echo "" || warn "dashboard_url ausente"

# ---------------------------------------------------------------------------
# STEP 9: Post-deploy verification — CloudWatch Dashboard
# ---------------------------------------------------------------------------
if [ "$NO_VERIFY" -eq 1 ]; then
  warn "--no-verify informado; pulando checagens pós-deploy."
  exit 0
fi

section "STEP 9 — Verificação pós-deployment"

require_cmd aws
require_cmd jq

REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${TF_VAR_project_name:-$(grep -E '^project_name' "$TFVARS_FILE" | head -1 | cut -d= -f2 | tr -d ' \"')}"
PROJECT_NAME="${PROJECT_NAME//$'\r'}"
if [ -z "$PROJECT_NAME" ]; then
  fail "Não foi possível determinar project_name; defina TF_VAR_project_name ou edite o tfvars"
  exit 3
fi
ok "Projeto detectado: $PROJECT_NAME (region: $REGION)"

# Verifica se o dashboard foi criado
DASHBOARD_NAME="${PROJECT_NAME}-production-streaming-pipeline"
DASHBOARD=$(aws cloudwatch get-dashboard --dashboard-name "$DASHBOARD_NAME" --region "$REGION" 2>/dev/null)
if [ -z "$DASHBOARD" ]; then
  fail "Dashboard '$DASHBOARD_NAME' não encontrado no CloudWatch"
  MISSING=1
else
  ok "Dashboard '$DASHBOARD_NAME' existe no CloudWatch"
fi

# ---------------------------------------------------------------------------
# STEP 10: Final summary
# ---------------------------------------------------------------------------
section "STEP 10 — Resumo final"

DASH_URL=$(terraform output -raw dashboard_url 2>/dev/null || echo "<missing>")
DASH_NAME=$(terraform output -raw dashboard_name 2>/dev/null || echo "<missing>")

echo ""
echo -e "${BOLD}CloudWatch Dashboard:${NC}"
echo -e "  ${BOLD}Nome${NC}      = ${GREEN}${DASH_NAME}${NC}"
echo -e "  ${BOLD}URL${NC}       = ${DASH_URL}"
echo ""

if [ "${MISSING:-0}" = "1" ]; then
  fail "Verificação pós-deployment encontrou recursos faltando (ver acima)."
  exit 3
fi

echo -e "${GREEN}${BOLD}🎉 Dashboard de observabilidade implantado com sucesso!${NC}"
echo ""
echo -e "${BOLD}Próximos passos:${NC}"
echo "  1. Acesse o dashboard no CloudWatch Console"
echo "  2. Verifique as métricas dos pipelines de ingestão"
echo ""
exit 0
