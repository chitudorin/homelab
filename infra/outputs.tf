output "server_ipv4" {
  description = "Public IPv4 of the node."
  value       = hcloud_server.node.ipv4_address
}
