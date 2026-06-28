# AWS Streaming Flight Radar — Observabilidade (Repo 3)

Dashboard CloudWatch e alarmes para monitoramento do pipeline de ingestão de voos.

## Visão Geral

Este repositório **não cria** infraestrutura de dados — ele consome recursos existentes (criados pelos Repos 1 e 2) via **data sources** do Terraform e monta um dashboard unificado de observabilidade.

### Data Sources Utilizados

**Do Repo 2 (Ingestion Pipeline):**

| Recurso | Data Source |
|---|---|
| Kinesis Stream `flights` | `data.aws_kinesis_stream.flights` |
| Kinesis Stream `flights_rt` (enriquecido) | `data.aws_kinesis_stream.flights_rt` |
| Lambda `flights-raw` | `data.aws_lambda_function.flights_raw` |
| Lambda `flights-authorizer` | `data.aws_lambda_function.flights_authorizer` |
| SQS DLQ `flights-dlq` | `data.aws_sqs_queue.flights_dlq` |
| API Gateway `flights-api` | `data.aws_api_gateway_rest_api.flights` |

**Do Repo 1 (Data Infrastructure):**

| Recurso | Data Source |
|---|---|
| Aurora Cluster | `data.aws_rds_cluster.aurora` |

## Dashboard — Seções

O dashboard CloudWatch (`{project}-{env}-streaming-pipeline`) exibe:

- **🌐 API Gateway** — Requests, erros 4xx/5xx, latência (p95)
- **⚡ Lambda** — Invocações, erros, duração (p95), throttles
- **📊 Kinesis Stream `flights`** — Records, bytes, iterator age, throttling
- **📊 Kinesis Stream `flights_rt`** — Records, bytes, iterator age, throttling
- **🧮 Kinesis Data Analytics (Flink)** — KPU utilization, messages in/out, millisBehindLatest
- **🗄️ Aurora Serverless v2** — Conexões ativas, IOPS, latência, volume do cluster
- **🔄 DMS Serverless** — CDC incoming, latency, erros, full load metrics
- **📬 SQS DLQ** — Messages sent/received, age of oldest message
- **💾 S3 Landing** — Bucket size, number of objects

## Estrutura do Projeto

```
.
├── infra/
│   ├── data.tf              # Data sources dos recursos monitorados
│   ├── main.tf              # Módulo cloudwatch_monitoring
│   ├── locals.tf             # Buckets com account-id + aurora writer ID
│   ├── variables.tf          # Variáveis de entrada
│   ├── outputs.tf            # Outputs do dashboard
│   ├── providers.tf          # Provider AWS
│   └── modules/
│       └── cloudwatch_monitoring/   # Dashboard + alarmes (widgets)
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           ├── data.tf
│           └── locals.tf
├── setup-env.sh              # Deploy automatizado
├── rollback-setup.sh         # Destrói recursos de observabilidade
└── README.md
```

## Deploy

### Pré-requisitos

- Conta AWS com os recursos dos Repos 1 e 2 já criados
- Credenciais AWS configuradas (`aws configure` ou SSO)
- Terraform >= 1.1.0

### Passos

```bash
# 1. Exportar variáveis de ambiente (opcional)
export AWS_REGION=us-east-1

# 2. Executar setup
./setup-env.sh
```

### Opções

| Flag | Descrição |
|---|---|
| `--skip-apply` | Apenas `init`, `validate` e `plan` |
| `--no-verify` | Pula verificação pós-deploy |

### Rollback

```bash
./rollback-setup.sh
```

## Variáveis obrigatórias (tfvars)

| Variável | Descrição |
|---|---|
| `project_name` | Nome do projeto (ex: `flight-radar-stream`) |
| `aws_region` | Região AWS |
| `environment` | Ambiente (ex: `production`) |
| `buckets` | Mapa com nomes base dos buckets S3 |
| `alerts_email` | Email para notificações de alarme |

## Outputs

| Output | Descrição |
|---|---|
| `dashboard_name` | Nome do dashboard CloudWatch |
| `dashboard_arn` | ARN do dashboard |
| `dashboard_url` | URL direta para o dashboard no console AWS |
