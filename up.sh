#!/bin/bash

set -e

NUM_WORKER_NODES=2
WORKER_NODES_INSTANCE_TYPE=t2.micro
STACK_NAME=eks-cluster
KEY_PAIR_NAME=anilOhio

echo  "Deploying CloudFormation stack"
aws cloudformation deploy \
  "$@" \
  --template-file eks.yml \
  --capabilities CAPABILITY_IAM \
  --stack-name "$STACK_NAME" \
  --parameter-overrides \
      KeyPairName="$KEY_PAIR_NAME" \
      NumWorkerNodes="$NUM_WORKER_NODES" \
      WorkerNodesInstanceType="$WORKER_NODES_INSTANCE_TYPE"

echo -e "\nUpdating kubeconfig file..."
aws eks update-kubeconfig "$@" --name "$STACK_NAME" 

echo -e "\nConfiguring worker nodes (to join the cluster)..."
# Get worker nodes role ARN from CloudFormation stack output
arn=$(aws cloudformation describe-stacks \
  "$@" \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='WorkerNodesRoleArn'].OutputValue" \
  --output text)
# Enable worker nodes to join the cluster:
# https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html#eks-create-cluster
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: $arn
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOF

echo -e "Cluster will be ready when all nodes have a 'Ready' status."
echo -e "Check it with command: kubectl get nodes --watch"
