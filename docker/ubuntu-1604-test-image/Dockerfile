FROM ubuntu:16.04

RUN apt update
RUN apt install -y sudo python-pip
RUN pip install --upgrade pip
RUN pip install ansible>=2.2
RUN pip install junit_xml


COPY ansible_callbacks/wpe_base.py /usr/share/ansible/plugins/callback/wpe_base.py
COPY ansible_callbacks/wpe_junit.py /usr/share/ansible/plugins/callback/wpe_junit.py
COPY ansible_callbacks/wpe_base.py /ansible-callbacks/wpe_base.py
COPY ansible_callbacks/wpe_junit.py /ansible-callbacks/wpe_junit.py
RUN mkdir -p /etc/ansible
RUN ansible -c local localhost -m ini_file -a 'path=/etc/ansible/ansible.cfg section=general option=callback_plugins value=~/.ansible/plugins/callback:/usr/share/ansible/plugins/callback'
RUN ansible -c local localhost -m ini_file -a 'path=/etc/ansible/ansible.cfg section=general option=callback_whitelist value=wpe_junit'
#RUN echo '[general]\ncallback_plugins = ~/.ansible/plugins/callback:/usr/share/ansible/plugins/callback' >> /etc/ansible/ansible.cfg
# name: Ensure "fav=lemonade is in section "[drinks]" in specified file
#  ini_file:
#    path: /etc/conf
#    section: drinks
#    option: fav
#    value: lemonade
#    mode: 0600
#    backup: yes
#
#- ini_file:
