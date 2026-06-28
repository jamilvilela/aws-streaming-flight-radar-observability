variable "project_name" {
  description = "Nome do projeto para prefixar recursos"
  type        = string
}

variable "aws_region" {
  description = "Região AWS onde os recursos estão implantados"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "alerts_email" {
  description = "Email para receber notificações de alarme"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.alerts_email : can(regex("^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$", email))
    ])
    error_message = "Todos os emails devem ser válidos."
  }
}

variable "tags" {
  description = "Tags para recursos"
  type        = map(string)
  default     = {}
}

variable "buckets" {
  description = "Mapa de nomes base dos buckets S3 (account-id é concatenado via locals)"
  type        = map(string)
}

variable "api_gateway_stage_name" {
  description = "Nome do stage do API Gateway para o dashboard"
  type        = string
  default     = "v1"
}

variable "kda_application_name" {
  description = "Nome da aplicação Kinesis Data Analytics (Flink) para métricas no dashboard"
  type        = string
  default     = ""
}

variable "dms_serverless_config_id" {
  description = "Identificador da configuração DMS Serverless para métricas no dashboard"
  type        = string
  default     = ""
}

variable "alarm_thresholds" {
  description = "Thresholds personalizáveis para alarmes CloudWatch"
  type = object({
    kinesis_iterator_age_ms           = number
    kinesis_no_records_minutes        = number
    kinesis_write_throttle_percent    = number
    kinesis_read_throttle_percent     = number
    firehose_delivery_failure_percent = number
    firehose_incoming_records_low     = number
    lambda_error_percent              = number
    lambda_duration_p95_ms            = number
    lambda_throttle_count             = number
  })

  default = {
    kinesis_iterator_age_ms           = 60000
    kinesis_no_records_minutes        = 10
    kinesis_write_throttle_percent    = 5
    kinesis_read_throttle_percent     = 5
    firehose_delivery_failure_percent = 10
    firehose_incoming_records_low     = 1
    lambda_error_percent              = 5
    lambda_duration_p95_ms            = 5000
    lambda_throttle_count             = 10
  }

  validation {
    condition     = var.alarm_thresholds.kinesis_iterator_age_ms >= 0 && var.alarm_thresholds.kinesis_iterator_age_ms <= 3600000
    error_message = "kinesis_iterator_age_ms must be between 0 and 3600000 (1 hour)."
  }

  validation {
    condition     = var.alarm_thresholds.kinesis_no_records_minutes >= 1 && var.alarm_thresholds.kinesis_no_records_minutes <= 60
    error_message = "kinesis_no_records_minutes must be between 1 and 60."
  }

  validation {
    condition     = var.alarm_thresholds.firehose_delivery_failure_percent >= 0 && var.alarm_thresholds.firehose_delivery_failure_percent <= 100
    error_message = "firehose_delivery_failure_percent must be between 0 and 100."
  }

  validation {
    condition     = var.alarm_thresholds.lambda_duration_p95_ms >= 0 && var.alarm_thresholds.lambda_duration_p95_ms <= 900000
    error_message = "lambda_duration_p95_ms must be between 0 and 900000 (15 minutes)."
  }
}
