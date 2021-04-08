###
# S3
###
resource "aws_s3_bucket" "images" {
  bucket = "${var.project_name}-images"
  acl    = "private"

  cors_rule {
    allowed_headers = ["Content-Type"]
    allowed_methods = ["PUT"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
  versioning {
    enabled = true
  }
}

resource "aws_iam_policy" "images_s3" {
  name = "${var.project_name}-lambda_access_s3"
  path = "/"

  policy = data.aws_iam_policy_document.images_s3.json
}

data "aws_iam_policy_document" "images_s3" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.images.arn}/*"]
  }
}

resource "aws_iam_role_policy_attachment" "images_s3" {
  role       = aws_iam_role.images_post.name
  policy_arn = aws_iam_policy.images_s3.arn
}

###
# Lambda
###
resource "aws_lambda_function" "images_post" {
  filename      = "images_post.zip"
  function_name = "${var.project_name}-images_post"
  role          = aws_iam_role.images_post.arn
  handler       = "images_post.handler"

  source_code_hash = data.archive_file.images_post.output_base64sha256

  runtime = "nodejs12.x"

  environment {
    variables = {
      S3_BUCKET = aws_s3_bucket.images.id
    }
  }
}

resource "aws_lambda_permission" "images_post" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.images_post.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_iam_role" "images_post" {
  name               = "${var.project_name}-lambda_images_post"
  assume_role_policy = data.aws_iam_policy_document.images_post.json
}

data "aws_iam_policy_document" "images_post" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "archive_file" "images_post" {
  type        = "zip"
  source_dir  = "images/src"
  output_path = "images_post.zip"
}


###
# API Gateway
###
resource "aws_api_gateway_rest_api" "this" {
  name = var.project_name

  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_deployment" "v1" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = "v1"

  triggers = {
    redeployment = sha1(join(",", list(
      jsonencode(aws_api_gateway_integration.images_post),
      jsonencode(aws_api_gateway_integration.images_options),
    )))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_resource" "images" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "images"
}

resource "aws_api_gateway_method" "images_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.images.id
  http_method   = "POST"
  authorization = "NONE" # TODO
}

resource "aws_api_gateway_method" "images_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.images.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "images_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.images.id
  http_method = aws_api_gateway_method.images_options.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "images_post" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_method.images_post.resource_id
  http_method = aws_api_gateway_method.images_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.images_post.invoke_arn
}

resource "aws_api_gateway_integration" "images_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.images.id
  http_method = aws_api_gateway_method.images_options.http_method
  type        = "MOCK"
   request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_integration_response" "images_options_response" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.images.id
  http_method = aws_api_gateway_method.images_options.http_method
  status_code = aws_api_gateway_method_response.images_options_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}