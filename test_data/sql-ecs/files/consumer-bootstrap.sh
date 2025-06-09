#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

apt-get update
apt-get install -y awscli
