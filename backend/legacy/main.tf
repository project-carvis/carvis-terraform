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
      S3_BUCKET          = var.s3_images_id
      SENTRY_ENVIRONMENT = lookup({ live = "production" }, var.env, "deploy-preview")
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
  source_dir  = "backend/legacy/src/images_post"
  output_path = "images_post.zip"
}

resource "aws_lambda_function" "image_get" {
  filename      = "image_get.zip"
  function_name = "${var.project_name}-image_get"
  role          = aws_iam_role.image_get.arn
  handler       = "image_get.handler"
  timeout       = 10
  memory_size   = 2048

  source_code_hash = data.archive_file.image_get.output_base64sha256

  runtime = "nodejs12.x"

  environment {
    variables = {
      S3_BUCKET          = var.s3_images_id
      SENTRY_ENVIRONMENT = lookup({ live = "production" }, var.env, "deploy-preview")
    }
  }
}

resource "aws_lambda_permission" "image_get" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_get.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_iam_role" "image_get" {
  name               = "${var.project_name}-lambda_image_get"
  assume_role_policy = data.aws_iam_policy_document.image_get.json
}

data "aws_iam_policy_document" "image_get" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "archive_file" "image_get" {
  type        = "zip"
  source_dir  = "backend/legacy/src/image_get"
  output_path = "image_get.zip"
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
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.images_post,
      aws_api_gateway_integration.images_options,
      aws_api_gateway_integration.image_get,
      aws_api_gateway_integration.image_options
    ]))
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

resource "aws_api_gateway_resource" "image" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.images.id
  path_part   = "{imageId}"
}

resource "aws_api_gateway_method" "images_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.images.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.this.id
}

resource "aws_api_gateway_method" "images_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.images.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "image_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.image.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.this.id
  request_parameters = {
    "method.request.path.imageId"     = true
    "method.request.querystring.size" = false
  }
}

resource "aws_api_gateway_method" "image_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.image.id
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

resource "aws_api_gateway_method_response" "image_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.image.id
  http_method = aws_api_gateway_method.image_options.http_method
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

resource "aws_api_gateway_integration" "image_get" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_method.image_get.resource_id
  http_method = aws_api_gateway_method.image_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.image_get.invoke_arn
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

resource "aws_api_gateway_integration" "image_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.image.id
  http_method = aws_api_gateway_method.image_options.http_method
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
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "image_options_response" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.image.id
  http_method = aws_api_gateway_method.image_options.http_method
  status_code = aws_api_gateway_method_response.image_options_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}


resource "aws_api_gateway_authorizer" "this" {
  authorizer_credentials           = module.authorizer.lambda_role_arn
  authorizer_uri                   = "arn:aws:apigateway:eu-west-1:lambda:path/2015-03-31/functions/${module.authorizer.lambda_arn}/invocations"
  name                             = "auth0"
  rest_api_id                      = aws_api_gateway_rest_api.this.id
  authorizer_result_ttl_in_seconds = 0
}

module "authorizer" {
  source                  = "jdpx/auth0-authorizer/aws"
  version                 = "0.1.1"
  authorizer_audience     = "ukQnXHJoRrZwGf85Uh4Jpk8V932GsfKt"
  authorizer_jwks_uri     = "https://carvis.eu.auth0.com/.well-known/jwks.json"
  authorizer_token_issuer = "https://carvis.eu.auth0.com/"
  lambda_function_name    = "${var.project_name}-auth0_authorizer-legacy"
  lambda_role_name        = "${var.project_name}-lambda_auth0_authorizer"
}

output "iam_role_names_require_s3_access" {
  value = [aws_iam_role.images_post.name, aws_iam_role.image_get.name]
}
