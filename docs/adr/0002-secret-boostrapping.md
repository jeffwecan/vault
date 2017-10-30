2: Secret Bootstrapping
=======================

Date: 2017/10/30

Status
------

Proposed

Context
-------

We need some way to bootstrap initial creds (SSL certs for consul and whatnot) into our secret management cluster. So where we gonna keep.

Decision
--------

We will store a very limited subset of bootstrapping creds in credstash?

Consequences
------------

A subset of credentials to be maintained outside of vault maybe sort of.
