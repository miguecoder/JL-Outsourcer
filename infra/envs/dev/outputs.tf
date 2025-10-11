output "raw_bucket_name" {
  value = module.storage.raw_bucket_name
}

output "curated_table_name" {
  value = module.storage.curated_table_name
}

output "queue_url" {
  value = module.messaging.queue_url
}