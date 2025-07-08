provider "aws" {
    region = "us-east-1"
}

resource "aws_s3_bucket" "fe_codepipeline_bucket" {
  bucket = "fe-ebun-codepipe-bucket"
}

resource "aws_iam_role" "fe_pipeline_role" {
  name = "fe_pipeline_role"

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

resource "aws_iam_policy" "fe_codepipline_role_policy" {
  name        = "fe_codepipline_role_policy"

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

resource "aws_iam_policy_attachment" "fe_pipeline_role_policy_attach" {
  name       = "fe_pipeline_role_policy_attach"
  roles      = [aws_iam_role.fe_pipeline_role.name]
  policy_arn = aws_iam_policy.fe_codepipline_role_policy.arn
}

resource "aws_iam_role" "fe_codebuild_role" {
  name = "fe_codebuild_role"

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

resource "aws_iam_policy" "fe_codebuild_role_policy" {
  name        = "fe_codebuild_role_policy"

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

resource "aws_iam_policy_attachment" "codebuild_role_policy_attach" {
  name       = "fe_pipeline_role_policy_attach"
  roles      = [aws_iam_role.fe_codebuild_role.name]
  policy_arn = aws_iam_policy.fe_codebuild_role_policy.arn
}

resource "aws_codebuild_project" "fe_codebuild_build" {
  name           = "fe_codebuild_build"

  service_role = aws_iam_role.fe_codebuild_role.arn

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

resource "aws_codebuild_project" "fe_codebuild_deploy" {
  name           = "fe_codebuild_deploy"

  service_role = aws_iam_role.fe_codebuild_role.arn

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

data "aws_ssm_parameter" "github-parameter" {
  name = "github-token"
}

resource "aws_codepipeline" "fe_codepipeline" {
  name     = "fe-tf-pipeline"
  role_arn = aws_iam_role.fe_pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
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
        Repo           = "farm-stack-course"
        Branch         = "main"
        OAuthToken     = data.aws_ssm_parameter.github-parameter.value
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