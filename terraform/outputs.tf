output "instance_group_public_ips" {
  description = "Public IP addresses of the instance group"
  value       = yandex_compute_instance_group.lamp_group.instances[*].network_interface[0].nat_ip_address
}

output "load_balancer_public_ip" {
  description = "Public IP address of the load balancer"
  value       = yandex_lb_network_load_balancer.lamp_load_balancer.listener[*].external_address_spec[*].address
}
