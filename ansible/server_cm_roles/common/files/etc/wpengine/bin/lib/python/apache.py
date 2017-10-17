#!/usr/bin/python

import counter
import glob
import os
import re
import string
import sys

from datetime import datetime, timedelta


class apache:
    logmatch = "/var/log/apache2/[^staging]+.access.log(\.1)?$"
    total_apache_hits = 0
    max_hours = 3
    acct = ''

    def __init__(self, argv):
        callit = getattr(self, argv[1])
        if len(argv) > 2:
            self.acct = argv[2]
        callit()

    def hourly(self):
        self.sites = counter.Counter()
        # find necessary files
        files = [f for f in os.listdir('/var/log/apache2/') if re.search(r'[^staging]+\.access.log(\.1)?$', f)]
        # removing staging server logs
        files = [f for f in files if not re.search(r'staging.*', f)]
        numfiles = len(files)
        donefiles = 0
        for log in files:
            account = re.sub(r'(.*)\.access\.log', r'\1', log)
            donefiles += 1
            message = "reading %d of %d" % (donefiles, numfiles)
            Printer(message)
            factor = 0
            while factor <= self.max_hours:
                data = open('/var/log/apache2/' + log)
                newtime = datetime.today() - timedelta(hours=factor)
                time_to_grep = newtime.strftime("%d/%b/%Y:%H")
                for line in data:
                    if re.match("(.*)"+time_to_grep+"(.*)", line):
                        self.sites[account] += 1
                        self.total_apache_hits += 1
                factor += 1
        projected = (24 * 60 / self.max_hours * 60) * self.total_apache_hits
        print bcolors.WARNING + "\nApache Hits Last " + str(self.max_hours) + " Hour(s): " + bcolors.ENDC +\
            str(self.total_apache_hits)
        print bcolors.WARNING + "Projected 24 hour total : " + bcolors.ENDC + str(projected)
        print "Top Users: "
        for k, v in self.sites.most_common(15):
            print "\t %s %d" % (k, v)

    def stats(self):
        self.stats = counter.Counter()
        self.stats['codes'] = counter.Counter()
        self.stats['total'] = 0
        self.stats['accounts'] = counter.Counter()
        print bcolors.WARNING + "Generating some stats" + bcolors.ENDC
        files = glob.glob("/var/log/nginx/*.access.log")
        numfiles = len(files)
        donefiles = 0
        for log in files:
            account = self.account_from_file(log)
            message = "Reading %d of %d \t %s " % (donefiles, numfiles, account)
            donefiles += 1
            Printer(message)
            data = open(log)
            for line in data:
                sp = line.split("|")
                if len(sp) > 4:
                    self.stats['codes'][sp[4]] += 1
                    self.stats['total'] += 1
                    self.stats['accounts'][account] += 1
        print "\n"
        print bcolors.WARNING + "TOTAL REQUESTS:" + bcolors.ENDC + "\t" + str(self.stats['total']) + "\n"
        print bcolors.WARNING + "BY STATUS:" + bcolors.ENDC
        for k, v in self.stats['codes'].most_common(25):
            print "\t %s \t\t %d \t%s" % (k, v, format(float(v) / self.stats['total'], '.2f'))
        print "\n"
        print bcolors.WARNING + "BY ACCOUNT:" + bcolors.ENDC + "\t\n"
        for k, v in self.stats['accounts'].most_common(25):
            if len(k) <= 6:
                k += "\t\t\t"
            elif len(k) > 15:
                k += "\t"
            else:
                k += "\t\t"
            print "\t %s %d \t%s" % (k, v, format(float(v) / self.stats['total'], '.2f'))
        print "\n"
        print "All done"

    # seg 6 IP
    # NOQA is being set for this function to avoid flake8 lint failing for C901.  If you are making changes to this
    # function you should remove the NOQA comment and get the complexity score under 10 if at all possible.
    def analyze(self): # NOQA
        self.stats = counter.Counter()
        self.stats['reqs'] = counter.Counter()
        self.stats['types'] = counter.Counter()
        self.stats['posts'] = counter.Counter()
        self.stats['post_actions'] = counter.Counter()
        self.stats['gets'] = counter.Counter()
        self.stats['cached'] = counter.Counter()
        self.stats['backend'] = counter.Counter()
        self.stats['statics'] = counter.Counter()
        Printer("Analyzing " + self.acct)
        nginx_logfile = "/var/log/nginx/"+self.acct+".access.log"
        data = open(nginx_logfile)
        current_line = 1
        for line in data:
            current_line += 1
            linedata = line.split("|")
            if len(linedata) < 8:
                continue
            req = linedata[9].split(" ")
            Printer("Reading %d requests \t%s" % (current_line, req[1][:50]))
            static = False
            if linedata[6] == '-':
                static = True
                self.stats['statics'][req[1]] += 1
            else:
                proxy = linedata[6].split(":")
                if proxy[1] == '9002':
                    self.stats['cached'][req[1]] += 1
                else:
                    self.stats['backend'][req[1]] += 1

            if req[0] == 'POST':
                clean_req = req[1].split("?")
                self.stats['posts'][clean_req[0]] += 1
                if len(clean_req) > 1:
                    args = clean_req[1].split("&")
                    for arg in args:
                        params = arg.split("=")
                        self.stats['post_actions'][params[0]] += 1
            elif req[0] == 'GET':
                if static is False:
                    clean_req = req[1].split("?")
                    self.stats['gets'][clean_req[0]] += 1

        print "... all done"
        print bcolors.WARNING + "Total Requests:" + bcolors.ENDC + "\t" + str(current_line)

        total = 0
        for url, count in self.stats['gets'].most_common():
            total = total + count
        pct = float(total) / current_line
        print bcolors.WARNING + "GET Requests:" + bcolors.ENDC + "\t" + str(total) + "\t" + format(pct, '.2f')
        print bcolors.WARNING + "Popular GETs: " + bcolors.ENDC
        for url, count in self.stats['gets'].most_common(10):
            print "\t %s \t %s" % (str(count), url)

        total = 0
        for url, count in self.stats['posts'].most_common():
            total = total + count
        pct = float(total) / current_line
        print bcolors.WARNING + "POST Requests:" + bcolors.ENDC + "\t" + str(total) + "\t" + format(pct, '.2f')
        print bcolors.WARNING + "Popular POSTs: " + bcolors.ENDC
        for url, count in self.stats['posts'].most_common(10):
            print "\t %s \t %s" % (str(count), url)

        print bcolors.WARNING + "POST actions/args: " + bcolors.ENDC
        for action, value in self.stats['post_actions'].most_common(10):
            print"\t %s \t %s" % (action, str(value))

        print bcolors.WARNING + "Service Breakdown: " + bcolors.ENDC
        for service in ['cached', 'backend', 'statics']:
            total = 0
            for url, count in self.stats[service].most_common():
                            total = total + count
            pct = float(total)/current_line
            print "\t%s\t\t%d\t%s" % (service, total, format(pct, '.2f'))
        for service in ['cached', 'backend', 'statics']:
            print bcolors.WARNING + "Popular " + string.capwords(service) + ": " + bcolors.ENDC
            for url, count in self.stats[service].most_common(15):
                print "\t%d\t\t%s" % (count, url)

    def account_from_file(self, file):
        account = re.sub(r'/var/log/.+/([^\?|\.]+)\.access\.log', r'\1', file)
        return account

    def parse_line(self, line, match):
        if re.match("(.*)"+match+"(.*)", line):
            print line
            return True
        return False


class Printer:
    """
    Print things to stdout on one line dynamically
    """
    def __init__(self, data):
        sys.stdout.write("\r\x1b[K" + data.__str__())
        sys.stdout.flush()


class Site:
    """
    Store info related to sites
    """
    hits = 0
    name = ""

    def __init__(self, name):
        self.name = name

    def hit(self, hits):
        self.hits = self.hits + hits
        return self.hits

    def gethits(self):
        return self.hits


class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'

    def disable(self):
        self.HEADER = ''
        self.OKBLUE = ''
        self.OKGREEN = ''
        self.WARNING = ''
        self.FAIL = ''
        self.ENDC = ''


apache = apache(sys.argv)
