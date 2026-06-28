locals {
  # Extrai o identificador da instância writer do cluster Aurora
  aurora_writer_instance_id = try(
    [for m in data.aws_rds_cluster.aurora.cluster_members : m.db_instance_identifier if m.is_cluster_writer][0],
    ""
  )

  # Buckets com sufixo account-id para unicidade global
  buckets = merge(
    var.buckets,
    {
      workspace = "${var.buckets.workspace}-${data.aws_caller_identity.current.account_id}"
      landing   = "${var.buckets.landing}-${data.aws_caller_identity.current.account_id}"
      raw       = "${var.buckets.raw}-${data.aws_caller_identity.current.account_id}"
      trusted   = "${var.buckets.trusted}-${data.aws_caller_identity.current.account_id}"
      business  = "${var.buckets.business}-${data.aws_caller_identity.current.account_id}"
    }
  )
}
