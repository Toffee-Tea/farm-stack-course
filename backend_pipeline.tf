provider "aws" {
    region = "us-east-1"
}

resource "aws_s3_bucket" "be_codepipeline_bucket" {
  bucket = "be-ebun-codepipe-bucket"
}

resource "aws_iam_role" "be_pipeline_role" {
  name = "be_pipeline_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "be_codepipline_role_policy" {
  name        = "be_codepipline_role_policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "codebuild:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "be_pipeline_role_policy_attach" {
  name       = "be_pipeline_role_policy_attach"
  roles      = [aws_iam_role.be_pipeline_role.name]
  policy_arn = aws_iam_policy.be_codepipline_role_policy.arn
}

resource "aws_iam_role" "be_codebuild_role" {
  name = "be_codebuild_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "be_codebuild_role_policy" {
  name        = "be_codebuild_role_policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "logs:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "be_codebuild_role_policy_attach" {
  name       = "be_pipeline_role_policy_attach"
  roles      = [aws_iam_role.be_codebuild_role.name]
  policy_arn = aws_iam_policy.be_codebuild_role_policy.arn
}

resource "aws_codebuild_project" "be_codebuild_build" {
  name           = "be_codebuild_build"

  service_role = aws_iam_role.be_codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type            = "CODEPIPELINE"
    buildspec       = "buildspec_build.yml"
  }
}

resource "aws_codebuild_project" "be_codebuild_deploy" {
  name           = "be_codebuild_deploy"

  service_role = aws_iam_role.be_codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type            = "CODEPIPELINE"
    buildspec       = "buildspec_deploy.yml"
  }
}

data "aws_ssm_parameter" "be-github-parameter" {
  name = "github-token"
}

resource "aws_codepipeline" "be_codepipeline" {
  name     = "be-tf-pipeline"
  role_arn = aws_iam_role.be_pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.be_codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Commit"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner          = "Toffee-Tea"
        Repo           = "farm-stack-course-be"
        Branch         = "main"
        OAuthToken     = data.aws_ssm_parameter.be-github-parameter.value
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output_build"]
      version          = "1"

      configuration = {
        ProjectName    = aws_codebuild_project.be_codebuild_build.id
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "Deploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output_deploy"]
      version          = "1"

      configuration = {
        ProjectName    = aws_codebuild_project.be_codebuild_deploy.id
      }
    }
  }

}