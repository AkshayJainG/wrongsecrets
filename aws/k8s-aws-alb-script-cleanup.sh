#!/bin/bash
# set -o errexit
# set -o pipefail
# set -o nounset

function checkCommandsAvailable() {
  for var in "$@"
  do
    if ! [ -x "$(command -v "$var")" ]; then
      echo "🔥 ${var} is not installed." >&2
      exit 1
    else
      echo "🏄 $var is installed..."
    fi
  done
}

checkCommandsAvailable helm jq vault sed grep docker grep cat aws curl eksctl kubectl

if test -n "${AWS_REGION-}"; then
  echo "AWS_REGION is set to <$AWS_REGION>"
else
  AWS_REGION=eu-west-1
  echo "AWS_REGION is not set or empty, defaulting to ${AWS_REGION}"
fi

if test -n "${CLUSTERNAME-}"; then
  echo "CLUSTERNAME is set to <$CLUSTERNAME>"
else
  CLUSTERNAME=wrongsecrets-exercise-cluster
  echo "CLUSTERNAME is not set or empty, defaulting to ${CLUSTERNAME}"
fi

ACCOUNT_ID=$(aws sts get-caller-identity | jq '.Account' -r)
echo "ACCOUNT_ID=${ACCOUNT_ID}"

LBC_VERSION="v2.3.0"
echo "LBC_VERSION=$LBC_VERSION"


echo "cleanup k8s ingress and service"
kubectl delete ingress wrongsecrets
kubectl delete service secret-challenge

echo "Cleanup helm chart"
helm uninstall aws-load-balancer-controller \
    -n kube-system

echo "Cleanup k8s ALB"
kubectl delete -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"



echo "Cleanup iam serviceaccount and policy"
eksctl delete iamserviceaccount \
    --cluster $CLUSTERNAME \
    --name aws-load-balancer-controller \
    --namespace kube-system \
    --region $AWS_REGION

aws iam delete-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy
