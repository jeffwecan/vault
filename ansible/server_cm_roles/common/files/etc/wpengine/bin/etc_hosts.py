#!/usr/bin/env python

import os
import sys
import shutil
import filecmp
import logging
import logging.handlers

from tempfile import mkstemp
from server_meta import ServerMeta


def get_logger():
    FORMAT = '%(asctime)s - DYNAMIC_ETC_HOSTS - %(levelname)s - %(message)s'
    logging.basicConfig(format=FORMAT)
    logger = logging.getLogger()
    if os.path.exists('/dev/log'):
        handler = logging.handlers.SysLogHandler(address='/dev/log')
        logger.addHandler(handler)
    elif os.path.exists('/var/run/syslog'):
        handler = logging.handlers.SysLogHandler(address='/var/run/syslog')
        logger.addHandler(handler)
    logger.setLevel(getattr(logging, 'INFO'))
    return logger


def main():
    if os.path.exists('/etc/wpengine/enabled/dynamic_etc_hosts'):
        refresh = len(sys.argv) > 1 and sys.argv[1] == "FIRST_RUN"
        sm = ServerMeta()
        hosts = sm.etc_hosts(refresh=refresh)
        # Write the hosts to disk if we have more than 500 characters...
        # Terrible validation... but whatever?
        if hosts is not False and len(hosts) > 500:
            logger = get_logger()
            if os.path.exists('/etc/wpengine/host_header'):
                with open('/etc/wpengine/host_header', 'r') as f:
                    header = f.read()
                body = hosts.index('##########  BEGIN DYNAMICO    #############')
                hosts = '%s\n%s' % (header, hosts[body:])
            try:
                fd, tmpfile = mkstemp(prefix="hosts_dynamico")
                with os.fdopen(fd, 'w') as f:
                    f.write(hosts)
                are_equal = filecmp.cmp(tmpfile, '/etc/hosts', False)
                if not are_equal:
                    msg = "Copying new hosts file in to place."
                    logger.warn(msg)
                    shutil.copyfile('/etc/hosts', '/etc/hosts.bak_dynamico')
                    shutil.move(tmpfile, '/etc/hosts')
                    shutil.copymode('/etc/hosts.bak_dynamico', '/etc/hosts')
                else:
                    msg = "No changes need to be copied for hosts file."
                    logger.info(msg)
                    os.remove(tmpfile)
            except:
                msg = "Error during file creation or comparison. No changes."
                logger.warn(msg)


if __name__ == "__main__":
    main()
