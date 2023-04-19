output "alb_dns_name" {
  description = "Open this hostname in a browser (HTTP port 80) once the service is healthy."
  value       = aws_lb.app.dns_name
}

# Handy for labs: compare /health (no DB) vs / (hits MySQL).
output "alb_urls" {
  description = "Example URLs through the load balancer for the Flask app."
  value = {
    app    = "http://${aws_lb.app.dns_name}/"
    health = "http://${aws_lb.app.dns_name}/health"
  }
}
