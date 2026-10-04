# =============================================================================
# Load Balancer Module - Public Flexible LB, Backend Sets, Listeners
# =============================================================================

# --- Reserved Public IP ---

# A レコードは Xserver の管理画面で手入力するため、LB を作り直しても IP が
# 変わらないよう予約 IP を使う。予約 IP は LB と独立したリソースで、
# LB を destroy しても保持される。
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_public_ip
resource "oci_core_public_ip" "lb" {
  count = var.use_reserved_ip ? 1 : 0

  compartment_id = var.compartment_id
  display_name   = "${var.app_name}-lb-ip"
  lifetime       = "RESERVED"

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "load-balancer"
  }

  # LB にアタッチされると LB 側が private_ip_id を書き戻すため、
  # 無変更でも plan に差分が出続ける。プロバイダー既知の挙動。
  lifecycle {
    ignore_changes = [private_ip_id]
  }
}

# --- Load Balancer ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/load_balancer_load_balancer
resource "oci_load_balancer_load_balancer" "this" {
  compartment_id             = var.compartment_id
  display_name               = "${var.app_name}-lb"
  shape                      = "flexible"
  subnet_ids                 = [var.subnet_id]
  network_security_group_ids = [var.nsg_id]
  is_private                 = false
  ip_mode                    = "IPV4"

  shape_details {
    minimum_bandwidth_in_mbps = var.bandwidth_mbps
    maximum_bandwidth_in_mbps = var.bandwidth_mbps
  }

  dynamic "reserved_ips" {
    for_each = oci_core_public_ip.lb
    content {
      id = reserved_ips.value.id
    }
  }

  freeform_tags = {
    app        = var.app_name
    managed-by = "terraform"
    role       = "load-balancer"
  }
}

# --- Backend Sets ---

# Backend の登録は Step 10（Container Instance 作成）で行う。
# Backend が 0 件でも health_checker ブロックの定義は必須。
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/load_balancer_backend_set
resource "oci_load_balancer_backend_set" "frontend" {
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  name             = "${var.app_name}-frontend"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    port              = var.frontend_port
    url_path          = "/health"
    return_code       = 200
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
  }
}

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/load_balancer_backend_set
resource "oci_load_balancer_backend_set" "backend" {
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  name             = "${var.app_name}-backend"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    port              = var.backend_port
    url_path          = "/health"
    return_code       = 200
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
  }
}

# --- Path Based Routing ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/load_balancer_path_route_set
resource "oci_load_balancer_path_route_set" "this" {
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  name             = "${var.app_name}-path-routes"

  path_routes {
    backend_set_name = oci_load_balancer_backend_set.backend.name
    path             = var.api_path_prefix

    path_match_type {
      match_type = "PREFIX_MATCH"
    }
  }
}

# --- Listeners ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/load_balancer_listener
resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.this.id
  name                     = "http"
  port                     = 80
  protocol                 = "HTTP"
  default_backend_set_name = oci_load_balancer_backend_set.frontend.name
  path_route_set_name      = oci_load_balancer_path_route_set.this.name

  # HTTPS リスナーがないあいだは空リスト。redirect が作られると 301 を返すようになる。
  rule_set_names = oci_load_balancer_rule_set.redirect_to_https[*].name

  connection_configuration {
    idle_timeout_in_seconds = 60
  }
}

# 証明書が渡されるまで（Step 9c まで）作成しない。
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/load_balancer_listener
resource "oci_load_balancer_listener" "https" {
  count = length(var.certificate_ids) > 0 ? 1 : 0

  load_balancer_id         = oci_load_balancer_load_balancer.this.id
  name                     = "https"
  port                     = 443
  protocol                 = "HTTP"
  default_backend_set_name = oci_load_balancer_backend_set.frontend.name
  path_route_set_name      = oci_load_balancer_path_route_set.this.name

  # cipher_suite_name / protocols は指定せず OCI の既定に任せる
  # （protocols だけ指定すると既定の cipher suite と不整合になりうるため）
  ssl_configuration {
    certificate_ids = var.certificate_ids
  }

  connection_configuration {
    idle_timeout_in_seconds = 60
  }
}

# --- Rule Sets ---

# HTTP リスナーに紐付けて 301 で HTTPS に飛ばす。HTTPS リスナーと同じ条件で
# 作成し、リスナーがない状態でリダイレクトだけ残らないようにする。
# redirect_uri のプレースホルダ（{host} / {path} / {query}）により、
# パスとクエリを保持したままスキームだけ変える。
# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/load_balancer_rule_set
resource "oci_load_balancer_rule_set" "redirect_to_https" {
  count = length(var.certificate_ids) > 0 ? 1 : 0

  load_balancer_id = oci_load_balancer_load_balancer.this.id
  name             = "redirect-to-https"

  items {
    action        = "REDIRECT"
    response_code = 301
    description   = "Redirect all HTTP traffic to HTTPS"

    # すべてのパスを対象にする。FORCE_LONGEST_PREFIX_MATCH で "/" は全体に一致する。
    conditions {
      attribute_name  = "PATH"
      attribute_value = "/"
      operator        = "FORCE_LONGEST_PREFIX_MATCH"
    }

    redirect_uri {
      protocol = "HTTPS"
      host     = "{host}"
      path     = "{path}"
      query    = "{query}"
      port     = 443
    }
  }
}

# --- NSG Rules ---

# Docs: https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/core_network_security_group_security_rule

resource "oci_core_network_security_group_security_rule" "lb_http_ingress" {
  network_security_group_id = var.nsg_id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow HTTP from the internet"

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_https_ingress" {
  network_security_group_id = var.nsg_id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Allow HTTPS from the internet"

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

# バックエンドへの転送とヘルスチェックの両方がこの経路を通る。
# App NSG 側の ingress は Step 10 で追加するため、現時点では疎通しない。
resource "oci_core_network_security_group_security_rule" "lb_app_egress" {
  network_security_group_id = var.nsg_id
  direction                 = "EGRESS"
  protocol                  = "6"
  description               = "Allow traffic and health checks to the App NSG"

  destination      = var.app_nsg_id
  destination_type = "NETWORK_SECURITY_GROUP"
}
