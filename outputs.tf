output "lb-endpoint" {
  value = "http://${aws_lb.web-lb.dns_name}"

}