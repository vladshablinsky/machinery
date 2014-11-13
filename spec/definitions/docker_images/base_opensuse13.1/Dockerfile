FROM opensuse:13.1

RUN zypper --non-interactive --gpg-auto-import-keys ref
RUN zypper in -y -t pattern base
RUN zypper in -y openssh \
  openSUSE-release \
  curl \
  tar \
  rsync \
  sudo \
  nfs-kernel-server \
  autofs

# Set root password to 'vagrant'
RUN usermod -p '$6$8g6OVxzWr2Sx$Q11GPMftevWb8jeYy/3nDsfS1RurF5CLWFQdZPiXaHjs5bR7WfROKdT4fqLl5vnZScYjxKOeFwLlcFDgKYqTt0' root

# Set up vagrant user
RUN useradd -m -p '$6$8g6OVxzWr2Sx$Q11GPMftevWb8jeYy/3nDsfS1RurF5CLWFQdZPiXaHjs5bR7WfROKdT4fqLl5vnZScYjxKOeFwLlcFDgKYqTt0' vagrant

# Install vagrant key
RUN mkdir -pm 700 /home/vagrant/.ssh
RUN curl -kLo /home/vagrant/.ssh/authorized_keys 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub'
RUN chmod 0600 /home/vagrant/.ssh/authorized_keys
RUN chown -R vagrant: /home/vagrant/.ssh

# Update sudoers
RUN echo -e "\nupdate sudoers ..."
RUN echo -e "\n# added by veewee/postinstall.sh" >> /etc/sudoers
RUN echo -e "vagrant ALL=(ALL) NOPASSWD: ALL\n" >> /etc/sudoers

# Fix SSH logins into the container
RUN sed -i 's@session.*required.*pam_loginuid.so@#session\trequired\tpam_loginuid.so@' /etc/pam.d/sshd
RUN sshd-gen-keys-start
