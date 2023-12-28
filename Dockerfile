FROM redhat/ubi8

# Install and configure sshd
RUN dnf update -y && dnf install -y openssh-server
RUN mkdir /etc/ssh/auth_principals
RUN echo 'ssh-user' > /etc/ssh/auth_principals/ssh-user
RUN sed -i -e 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
RUN echo 'AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u' >> /etc/ssh/sshd_config
RUN echo 'ChallengeResponseAuthentication no' >> /etc/ssh/sshd_config
RUN echo 'TrustedUserCAKeys /etc/ssh/trusted-CA.pem'  >> /etc/ssh/sshd_config
RUN echo 'LogLevel Debug3'  >> /etc/ssh/sshd_config

# Generate host keys
RUN ssh-keygen -q -f /etc/ssh/ssh_host_rsa_key -N "" -t rsa
RUN ssh-keygen -q -f /etc/ssh/ssh_host_ecdsa_key -N "" -t ecdsa
RUN ssh-keygen -q -f /etc/ssh/ssh_host_ed25519_key -N "" -t ed25519
RUN cp /etc/ssh/ssh_host_rsa_key.pub /etc/ssh/trusted-CA.pem

# Add user, set password, generate pubkey
RUN adduser ssh-user
RUN echo 'ssh-user:ssh-password' | chpasswd
RUN su ssh-user -c 'ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""'

# Expose port 22, run the sshd process logging to stdout
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]

