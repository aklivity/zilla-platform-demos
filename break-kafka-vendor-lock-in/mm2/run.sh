#!/bin/bash

set -e

envsubst < /opt/mirrormaker/mm2.template > /var/run/mirrormaker/mm2.config

/opt/bitnami/kafka/bin/connect-mirror-maker.sh /var/run/mirrormaker/mm2.config
