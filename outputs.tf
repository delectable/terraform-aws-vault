output "vault_alb_addr" {
  value = "${aws_alb.alb.dns_name}"
}

output "vault_alb_zone_id" {
  value = "${aws_alb.alb.zone_id}"
}

output "vault_addr" {
  value = "${var.vault_dns_address}"
}
