#!/bin/bash

# Exit on error for critical commands
set -e

AWS_REGION="eu-west-1"
ARGOCD_SERVER="your-argocd-server.com"
CLUSTERS=("cluster1" "cluster2")
REPOS=("https://github.com/org/repo1.git" "https://github.com/org/repo2.git")
PROJECTS=("project1" "project2")

SECRET_NAME="argocd-secrets"
SECRET_FIELD_ADMIN_PASS="admin-pass"
SECRET_FIELD_GITHUB_TOKEN="github-token"
ROLE_ARN="arn:aws:iam::123456789012:role/YourRoleName"

# Function to assume IAM role
assume_role() {
    echo "Assuming IAM role..."
    ROLE_SESSION=$(aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name "ArgoCDSetupSession")
    export AWS_ACCESS_KEY_ID=$(echo $ROLE_SESSION | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo $ROLE_SESSION | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo $ROLE_SESSION | jq -r '.Credentials.SessionToken')
}

# Function to retrieve secrets
get_secrets() {
    echo "Retrieving secrets from AWS Secrets Manager..."
    SECRET_JSON=$(aws secretsmanager get-secret-value --region "$AWS_REGION" --secret-id "$SECRET_NAME" | jq -r '.SecretString')
    ADMIN_PASSWORD=$(echo $SECRET_JSON | jq -r ".$SECRET_FIELD_ADMIN_PASS")
    GITHUB_TOKEN=$(echo $SECRET_JSON | jq -r ".$SECRET_FIELD_GITHUB_TOKEN")
    echo "Secrets retrieved successfully."
}

# Function to check if a cluster exists
cluster_exists() {
    local CLUSTER=$1
    argocd cluster list | grep -q "$CLUSTER"
}

# Function to check if a repository exists
repo_exists() {
    local REPO=$1
    argocd repo list | grep -q "$REPO"
}

# Function to check if a project exists
project_exists() {
    local PROJECT=$1
    argocd proj list | grep -q "$PROJECT"
}

# Main script
assume_role
get_secrets

echo "Logging into ArgoCD server..."
argocd login $ARGOCD_SERVER --username admin --password $ADMIN_PASSWORD --insecure

# Add clusters
echo "Adding clusters to ArgoCD..."
for CLUSTER in "${CLUSTERS[@]}"; do
    if cluster_exists "$CLUSTER"; then
        echo "Cluster $CLUSTER already exists. Skipping."
    else
        echo "Adding cluster: $CLUSTER"
        argocd cluster add $CLUSTER --yes
    fi
done

# Add repositories
echo "Adding repositories to ArgoCD..."
for REPO in "${REPOS[@]}"; do
    if repo_exists "$REPO"; then
        echo "Repository $REPO already exists. Skipping."
    else
        echo "Adding repository: $REPO"
        argocd repo add $REPO --username your-github-username --password $GITHUB_TOKEN
    fi
done

# TODO: RBAC
# Create projects
echo "Creating projects in ArgoCD..."
for PROJECT in "${PROJECTS[@]}"; do
    if project_exists "$PROJECT"; then
        echo "Project $PROJECT already exists. Skipping."
    else
        echo "Creating project: $PROJECT"
        argocd proj create $PROJECT \
            --description "Description for $PROJECT" \
            --dest "*/*" \
            --src "*"
    fi
done

echo "ArgoCD setup and updates completed successfully!"



# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Sid": "AssumeRole",
#             "Effect": "Allow",
#             "Action": "sts:AssumeRole",
#             "Resource": "arn:aws:iam::123456789012:role/YourRoleName"
#         },
#         {
#             "Sid": "SecretsManagerAccess",
#             "Effect": "Allow",
#             "Action": [
#                 "secretsmanager:GetSecretValue"
#             ],
#             "Resource": "arn:aws:secretsmanager:eu-west-1:123456789012:secret:argocd-secrets*"
#         }
#     ]
# }
