FROM ubuntu:16.04

RUN apt update
RUN apt install -y sudo python-pip
RUN rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip
RUN pip install ansible>=2.2
RUN pip install junit_xml
RUN pip install ansible-lint

ENTRYPOINT ["/usr/local/bin/ansible-lint"]
