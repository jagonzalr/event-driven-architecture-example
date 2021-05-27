output "buffer_queue_arn" {
  value = aws_sqs_queue.buffer_queue.arn
}

output "buffer_queue_id" {
  value = aws_sqs_queue.buffer_queue.id
}

output "uploads_bucket_arn" {
  value = aws_s3_bucket.uploads.arn
}

output "uploads_bucket_name" {
  value = aws_s3_bucket.uploads.id
}

output "users_table_arn" {
  value = aws_dynamodb_table.users.arn
}

output "users_table_name" {
  value = aws_dynamodb_table.users.id
}

output "users_table_stream_arn" {
  value = aws_dynamodb_table.users.stream_arn
}