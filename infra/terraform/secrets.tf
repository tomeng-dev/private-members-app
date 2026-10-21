resource "aws_secretsmanager_secret" "app" {
  name = "${var.project_name}/${var.environment}/app"
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id
  secret_string = jsonencode({
    DATABASE_URL           = "mysql://pmadmin:${random_password.db.result}@${aws_db_instance.main.address}:3306/private_members"
    JWT_ACCESS_SECRET      = random_password.jwt_access.result
    JWT_REFRESH_SECRET     = random_password.jwt_refresh.result
    JWT_KID                = "v1"
    QR_HMAC_SECRET         = random_password.qr.result
    STORAGE_SIGNING_SECRET = random_password.storage.result
    STAFF_2FA_REQUIRED     = "true"
  })
}

resource "random_password" "jwt_access" {
  length  = 48
  special = false
}
resource "random_password" "jwt_refresh" {
  length  = 48
  special = false
}
resource "random_password" "qr" {
  length  = 48
  special = false
}
resource "random_password" "storage" {
  length  = 48
  special = false
}
