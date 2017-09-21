FROM hashicorp/packer:1.1.0 as packer


#FROM docker:stable
#COPY --from=packer /bin/packer /bin/packer

RUN apk update
RUN apk add docker

#COPY artifacts/vault-test-image.tar /vault-test-image.tar
#RUN docker load -i /vault-test-image.tar
