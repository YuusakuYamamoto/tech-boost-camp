# =============================================================================
# Monitoring Module - Budget / Notifications / Alarms
#
# このモジュールは他モジュールの output を受け取らない。Budget だけは
# ルートコンパートメントに作られるため tenancy_id を取る。
# =============================================================================

# --- 通知 ---

# アラームの通知先。Budget のアラートはこのトピックを経由せず、
# alert_rule の recipients に直接送られる。
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/ons_notification_topic
resource "oci_ons_notification_topic" "alarms" {
  compartment_id = var.compartment_id
  name           = "${var.app_name}-alarms"
  description    = "Destination for ${var.app_name} monitoring alarms."

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "monitoring"
  }
}

# apply 直後の状態は PENDING。届いた確認メールのリンクを押すまで通知は
# 配信されない。endpoint / protocol / topic_id はいずれも非 Updatable で、
# メールアドレスを変えると再作成され確認をやり直すことになる。
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/ons_subscription
resource "oci_ons_subscription" "alarms_email" {
  compartment_id = var.compartment_id
  topic_id       = oci_ons_notification_topic.alarms.id
  protocol       = "EMAIL"
  endpoint       = var.notification_email

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "monitoring"
  }
}

# --- コスト保護 ---

# Budget はターゲットのコンパートメントに関わらず、必ずルートコンパートメントに
# 作成される。そのため compartment_id にはテナンシーの OCID を渡し、対象は
# targets で指定する。IAM も `manage usage-budgets in tenancy` でないと効かない。
# Docs: https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/budgetsoverview.htm
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/budget_budget
resource "oci_budget_budget" "this" {
  compartment_id = var.tenancy_id
  display_name   = "${var.app_name}-budget"
  description    = "Cost guard for the ${var.app_name} compartment (ADR-0017)."

  # amount はレートカードの通貨における整数。本テナンシーは JPY。
  # budget_processing_period_start_offset は既定（毎月 1 日）のため指定しない。
  amount       = var.budget_amount
  reset_period = "MONTHLY"

  # targets / target_type は非 Updatable。対象を変えると Budget が再作成される。
  # targets は現時点では要素 1 つのみ対応。
  target_type = "COMPARTMENT"
  targets     = [var.compartment_id]

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "monitoring"
  }
}

# OCI の Budget は 1 リソースに 1 つの金額しか持てないため、閾値の段数ぶん
# アラートルールを作る（ADR-0017 は 50 / 80 / 100 の 3 段）。
# threshold / threshold_type / type はいずれも Updatable。
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/budget_alert_rule
resource "oci_budget_alert_rule" "actual" {
  for_each = { for t in var.budget_alert_thresholds : tostring(t) => t }

  budget_id      = oci_budget_budget.this.id
  display_name   = "${var.app_name}-budget-actual-${each.key}"
  description    = "Alert when actual spend exceeds ${each.key}% of the budget."
  threshold      = each.value
  threshold_type = "PERCENTAGE"
  type           = "ACTUAL"
  recipients     = var.notification_email
  message        = "${var.app_name}: 実績が月間予算の ${each.key}% を超えました。"

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "monitoring"
  }
}

# --- 異常検知 ---

# LB のメトリックはモニタリングの有効化が不要で、作成時点から利用できる。
# Backend Set は各 1 台構成のため「異常なバックエンド > 0」が ADR-0017 の
# 「OK 状態の Backend = 0」と同義。groupBy で 1 本が両方のセットを見る。
# メトリックの実際の名前は UnHealthyBackendServers（H も大文字）。MQL は
# 大文字小文字を区別しないことを実測で確認済みだが、oci monitoring metric list
# が返す表記に合わせておく。
# Docs: https://docs.oracle.com/iaas/Content/Balance/Reference/loadbalancermetrics.htm
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/monitoring_alarm
resource "oci_monitoring_alarm" "lb_backend_down" {
  compartment_id        = var.compartment_id
  metric_compartment_id = var.compartment_id
  display_name          = "${var.app_name}-lb-backend-down"
  namespace             = "oci_lbaas"
  query                 = "UnHealthyBackendServers[1m].groupBy(backendSetName).max() > 0"
  severity              = "CRITICAL"
  pending_duration      = "PT3M"
  is_enabled            = true

  destinations   = [oci_ons_notification_topic.alarms.id]
  message_format = "ONS_OPTIMIZED"

  # Backend Set ごとに分けて通知し、どちらが落ちたか分かるようにする。
  is_notifications_per_metric_dimension_enabled = true

  body = "LB のバックエンドセットに異常なバックエンドがある。Bastion 経由でアプリ VM に入り、docker ps と systemctl status tbcamp-app-bootstrap.service を確認する。"

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "monitoring"
  }
}

# instance_status は running 状態の VM が利用可能（0）か、インフラ側の問題で
# 停止（1）かを示す。インスタンスを停止すると値そのものが出なくなるため、
# 意図的な停止はこの閾値アラームでは検知できない（既知の穴）。
# groupBy を使わないのは、このネームスペースのディメンション名が未確認のため。
# is_notifications_per_metric_dimension_enabled で VM ごとに分割される。
# Docs: https://docs.oracle.com/en-us/iaas/Content/Compute/References/infrastructurehealthmetrics.htm
resource "oci_monitoring_alarm" "vm_down" {
  compartment_id        = var.compartment_id
  metric_compartment_id = var.compartment_id
  display_name          = "${var.app_name}-vm-down"
  namespace             = "oci_compute_infrastructure_health"
  query                 = "instance_status[1m].max() > 0"
  severity              = "CRITICAL"
  pending_duration      = "PT5M"
  is_enabled            = true

  destinations   = [oci_ons_notification_topic.alarms.id]
  message_format = "ONS_OPTIMIZED"

  is_notifications_per_metric_dimension_enabled = true

  body = "VM がインフラ側の問題で停止している。30 分以上続く場合は Oracle サポートに連絡する。"

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "monitoring"
  }
}
