FROM opensuse:13.1

RUN zypper --non-interactive --gpg-auto-import-keys ref
RUN zypper in -y -t pattern base
RUN zypper in -y curl \
  tar \
  rsync \
  sudo \
  nfs-kernel-server \
  autofs

# Install git for checking out the machinery code and other machinery dependencies
RUN zypper --non-interactive install --no-recommends git libxslt1 libxslt-devel zlib-devel libxml2-devel expect patch

# Install kiwi and dependencies for building
RUN zypper rm -y libudev-mini1
RUN zypper --non-interactive install --no-recommends kiwi kiwi-desc-vmxboot kiwi-tools db45-utils db-utils grub

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
