FROM ubuntu:16.04

RUN apt update
RUN apt install -y sudo python-pip
RUN pip install ansible>=2.2
RUN pip install junit_xml


COPY ansible_callbacks/wpe_base.py /usr/share/ansible/plugins/callback/wpe_base.py
COPY ansible_callbacks/wpe_junit.py /usr/share/ansible/plugins/callback/wpe_junit.py
