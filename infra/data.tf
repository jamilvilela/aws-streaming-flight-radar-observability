data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ===========================================================================
# DATA SOURCES — Importa recursos criados em outros repositórios
# ===========================================================================

# --- Do Repo 2 (Ingestion Pipeline) ---

data "aws_kinesis_stream" "flights" {
  name = "flight-radar-stream-flights"
}

data "aws_kinesis_stream" "flights_rt" {
  name = "${var.project_name}-stream-flights-rt"
}

data "aws_lambda_function" "flights_raw" {
  function_name = "flight-radar-stream-flights-raw"
}

data "aws_lambda_function" "flights_authorizer" {
  function_name = "flight-radar-stream-flights-authorizer"
}

data "aws_sqs_queue" "flights_dlq" {
  name = "flight-radar-stream-flights-dlq"
}

data "aws_api_gateway_rest_api" "flights" {
  name = "flight-radar-stream-flights-api"
}

# --- Do Repo 1 (Data Infrastructure) ---

data "aws_rds_cluster" "aurora" {
  cluster_identifier = "${var.project_name}-aurora"
}
