#!/usr/bin/bash
# DX system files, and the signature policy for the cosmic-blue-dx image.
set -euox pipefail

cp -a /ctx/system_files_dx/. /

# Only accept key-signed cosmic-blue-dx images (same key as cosmic-blue)
install -Dm0644 /ctx/cosign.pub /etc/pki/containers/cosmic-blue.pub
IMAGE="ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"
jq --arg image "$IMAGE" '.transports.docker[$image] = [{
    "type": "sigstoreSigned",
    "keyPath": "/etc/pki/containers/cosmic-blue.pub",
    "signedIdentity": {"type": "matchRepository"}
}]' /etc/containers/policy.json > /tmp/policy.json
mv /tmp/policy.json /etc/containers/policy.json
# One file for both images: registries.d rejects a namespace defined twice.
cat > /etc/containers/registries.d/cosmic-blue.yaml <<YAML
docker:
  ghcr.io/${IMAGE_VENDOR}/cosmic-blue:
    use-sigstore-attachments: true
  ${IMAGE}:
    use-sigstore-attachments: true
YAML
