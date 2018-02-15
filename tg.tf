resource "aws_alb_target_group" "tg" {
  name     = "vault-tg"
  port     = "8200"
  # protocol = "HTTPS"
  protocol = "HTTP"
  vpc_id   = "${ var.vpc_id }"

  deregistration_delay = "10"

  # /sys/health will return 200 only if the vault instance
  # is the leader. Meaning there will only ever be one healthy
  # instance, but a failure will cause a new instance to
  # be healthy automatically.
  health_check {
    path                = "/v1/sys/health"
    port                = "8200"
    # protocol            = "HTTPS"
    protocol            = "HTTP"
    interval            = "5"
    timeout             = "3"
    healthy_threshold   = "2"
    unhealthy_threshold = "2"
    matcher             = "200"
  }

  tags = "${ merge(
    map(
      "Name",
      "vault-tg"
    ),
    var.tags ) }"
}
