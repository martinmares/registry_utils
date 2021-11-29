#!/bin/bash


if [ -z "$1" ]
  then
    echo "No argument supplied! Specifiy retention period 20,10,5 ..."
    exit 1
fi

export RETENTION=$1

export HARBOR_URL="https://celimregp401.server.cetin:8443"

echo "Retention: $RETENTION"

user=$(cat ../secrets/cetin.user)
export HARBOR_USER="$user"

pass=$(cat ../secrets/cetin.pass)
export HARBOR_PASS="$pass"

export SSL_CERT_FILE="../secrets/cetin.root.cer"

../bin/harbor_utils health -u "$HARBOR_URL" -s "$HARBOR_USER" -e "$HARBOR_PASS"

# export PROJECT="tsm-test"
# echo ""
# read -rp "Press [Enter] key to start cleanup '${PROJECT}'..."
# echo ""
# ../bin/harbor_utils cleanup -u "$HARBOR_URL" -s "$HARBOR_USER" -e "$HARBOR_PASS" -p "$PROJECT" -k "$RETENTION"
# 
# export PROJECT="tsm-ref"
# echo ""
# read -rp "Press [Enter] key to start cleanup '${PROJECT}'..."
# echo ""
# ../bin/harbor_utils cleanup -u "$HARBOR_URL" -s "$HARBOR_USER" -e "$HARBOR_PASS" -p "$PROJECT" -k "$RETENTION"
# 
# export PROJECT="tsm-part"
# echo ""
# read -rp "Press [Enter] key to start cleanup '${PROJECT}'..."
# echo ""
# ../bin/harbor_utils cleanup -u "$HARBOR_URL" -s "$HARBOR_USER" -e "$HARBOR_PASS" -p "$PROJECT" -k "$RETENTION"

export PROJECT="tsm-prod"
echo ""
read -rp "Press [Enter] key to start cleanup '${PROJECT}'..."
echo ""
../bin/harbor_utils cleanup -u "$HARBOR_URL" -s "$HARBOR_USER" -e "$HARBOR_PASS" -p "$PROJECT" -k "$RETENTION"

