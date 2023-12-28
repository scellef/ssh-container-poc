#!/usr/bin/env bash

# Set Vault env vars for dev server
export VAULT_ADDR=http://localhost:9210
export VAULT_TOKEN=root
CONTAINER_ADDR=localhost
CONTAINER_PORT=22
mkdir keys

# The Vault server is only used as a CA to import the host images' keypair, and
# otherwise doesn't interact with the target system.  Spin up a Vault dev
# server in a separate console using something like the following:
#
#    vault server \
#       -dev \
#       -dev-root-token-id=root \
#       -dev-listen-address=localhost:9210 \
#       -log-level=trace
 

# Build Docker image for a bare bones SSH server using RHEL's UBI8 base image
docker build . -t rhel-ssh

# Run newly built image with SSH port 22 exposed and forwarded
docker run --name rhel-ssh -dit -p 22:$CONTAINER_PORT rhel-ssh

# Collect keys from Docker image, we'll use the SSH host key as our trusted CA
docker cp rhel-ssh:/etc/ssh/ssh_host_rsa_key ./keys/ssh_host_rsa_key
docker cp rhel-ssh:/etc/ssh/ssh_host_rsa_key.pub ./keys/ssh_host_rsa_key.pub
docker cp rhel-ssh:/home/ssh-user/.ssh/id_rsa.pub ./keys/id_rsa.pub
docker cp rhel-ssh:/home/ssh-user/.ssh/id_rsa ./keys/id_rsa
chmod go-r ./keys/id_rsa

# Configure Vault SSH secrets engine
vault read ssh/config/ca 2> /dev/null 
if [ "$?" -ne 0 ] ; then
  vault secrets enable ssh
  vault write ssh/config/ca \
    private_key=@./keys/ssh_host_rsa_key \
    public_key=@./keys/ssh_host_rsa_key.pub
else
  vault delete ssh/config/ca
  vault write ssh/config/ca \
    private_key=@./keys/ssh_host_rsa_key \
    public_key=@./keys/ssh_host_rsa_key.pub
fi

# `jo` makes it simpler to generate JSON blobs to overcome Vault CLIs inability
# to specify maps. `jo -- -s` overrides default typing behavior, prevents
# interpreting empty string as 'null'
jo \
  key_type=ca \
  allow_user_certificates=true \
  allowed_users=ssh-user \
  default_user=ssh-user \
  allowed_extensions=permit-pty \
  default_extensions=$(jo -- -s permit-pty='') | 
  vault write ssh/roles/ssh-user -
 
# Generate signed SSH certificate
vault write -field=signed_key ssh/sign/ssh-user public_key=@./keys/id_rsa.pub > ./keys/id_rsa.cert
chmod go-r ./keys/id_rsa.cert

# Specify both the private key and signed pub key while attempting to SSH
/usr/bin/ssh -i keys/id_rsa -i keys/id_rsa.cert -l ssh-user $CONTAINER_ADDR -p $CONTAINER_PORT
