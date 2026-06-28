# ---------------------------------------------------------------------------
# CloudWatch Dashboard + Alarmes — Observabilidade do Pipeline
# ---------------------------------------------------------------------------
module "cloudwatch_monitoring" {
  source = "./modules/cloudwatch_monitoring"

  project_name = var.project_name
  aws_region   = var.aws_region
  environment  = var.environment
  tags         = var.tags

  api_gateway_stage = var.api_gateway_stage_name

  lambda_functions = [
    {
      name = data.aws_lambda_function.flights_raw.function_name
      arn  = data.aws_lambda_function.flights_raw.arn
    },
    {
      name = data.aws_lambda_function.flights_authorizer.function_name
      arn  = data.aws_lambda_function.flights_authorizer.arn
    },
  ]

  kinesis_stream_name    = data.aws_kinesis_stream.flights.name
  kinesis_stream_name_rt = data.aws_kinesis_stream.flights_rt.name

  kda_application_name = var.kda_application_name

  sqs_queue_name = data.aws_sqs_queue.flights_dlq.name

  aurora_instance_identifier = local.aurora_writer_instance_id
  aurora_cluster_identifier  = data.aws_rds_cluster.aurora.cluster_identifier
  dms_serverless_config_id   = var.dms_serverless_config_id

  s3_landing_bucket_name = local.buckets.landing
}
