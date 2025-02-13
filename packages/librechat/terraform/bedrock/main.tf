# IAM user for bedrock access
resource "aws_iam_user" "aida_bedrock" {
  name = "aida-bedrock"
}

# Create the bedrock access policy
resource "aws_iam_policy" "aida_bedrock_policy" {
  name        = "BedrockQueryPolicy"
  description = "Policy to allow querying AWS Bedrock models"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the user
resource "aws_iam_user_policy_attachment" "bedrock_attachment" {
  user       = aws_iam_user.aida_bedrock.name
  policy_arn = aws_iam_policy.aida_bedrock_policy.arn
}

# Make access keys for the user
resource "aws_iam_access_key" "aida_bedrock_access" {
  user = aws_iam_user.aida_bedrock.name
}

# Store the access key information in a secret
resource "aws_secretsmanager_secret" "aida_bedrock_secret" {
  name = "librechat-jwt-secret"
}

resource "aws_secretsmanager_secret_version" "aida_bedrock_secret_value" {
  secret_id = aws_secretsmanager_secret.aida_bedrock_secret.id
  secret_string = jsonencode({
    access = aws_iam_access_key.aida_bedrock_access.id
    secret = aws_iam_access_key.aida_bedrock_access.secret
  })
}
