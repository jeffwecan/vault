import inspect
import os
import sys
from collections import OrderedDict, defaultdict

from ansible.module_utils._text import to_bytes
from junit_xml import TestSuite, TestCase

# Allows importing our base callback module
cmd_folder = os.path.realpath(os.path.abspath(os.path.split(inspect.getfile(inspect.currentframe()))[0]))
if cmd_folder not in sys.path:
    sys.path.insert(0, cmd_folder)

from wpe_base import WPECallbackBase # NOQA

__metaclass__ = type


class CallbackModule(WPECallbackBase):
    """
    This callback writes playbook output to a JUnit formatted XML file.

    Tasks show up in the report as follows:
        'ok': pass
        'failed' with 'EXPECTED FAILURE' in the task name: pass
        'failed' due to an exception: error
        'failed' for other reasons: failure
        'skipped': skipped

    This plugin makes use of the following environment variables:
        JUNIT_OUTPUT_DIR (optional): Directory to write XML files to.
                                     Default: ./junit-results.xml

    Requires:
        junit_xml

    """

    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'aggregate'
    CALLBACK_NAME = 'wpe_junit'
    CALLBACK_NEEDS_WHITELIST = True

    def __init__(self):
        super(CallbackModule, self).__init__()

        self.playbook_name = None
        self._play_name = None
        self._task_data = OrderedDict()
        self._hosts_status = defaultdict(list)
        # If we want to record the order in which tasks are executed
        # self._task_number = 0

        # We set the host_name here because we want to control the structure of the junit
        # and want to use the hostname as the top level of our xml tree. Not all tasks have this attribute
        # available and so we set it once. This makes sense when there are many small local runs that get compiled.
        # self._host_name = None

    def _get_include(self, task_name, host_data):
        _result_out = str(host_data.result)
        try:
            if "TaskResult" in _result_out:
                # In this case we have a TaskResult object that doesn't contain the role which was not included
                # It would be nice to be able to retrieve the value of which include was skipped however
                task_name = task_name.replace('include', 'include skipped')
            else:
                include_role = _result_out.split('/')[-1].split(' ')[0]
                task_name = "{} {}".format(task_name, include_role)
            return task_name
        except Exception as e:
            self._display.warning(repr(e))

    # NOQA is being set for this function to avoid flake8 lint failing for C901.  If you are making changes to this
    # function you should remove the NOQA comment and get the complexity score under 10 if at all possible.
    def _build_test_suite(self, task_data, host_data, **return_status): # NOQA
        """ Build a TestCase from the given TaskData and HostData
        :param: task_data: TaskData object
        :param: host_data: HostData object
        :param: return_ok: Boolean, set True to log tasks with status 'ok'
        :param: return_included: Boolean, set True to log tasks with status 'included'
        :param: return_skipped: Boolean, set True to log tasks with status 'skipped'
        :param: return_failed: Boolean, set True to log tasks with status 'failed'

        NOTE: Jenkins is unable to handle publishing the full junit result's with 1000+ tasks for a load
              of 1000+ hosts, so we will only report failures to reduce the amount of load on jenkins.

        junit_xml.TestSuite and junit_xml.TestCase init constructor parameters:
        TestCase: __init__(self, name, classname=None, elapsed_sec=None, stdout=None, stderr=None)
        TestSuite: __init__(
            self, name, test_cases=None, hostname=None, id=None, package=None, timestamp=None, properties=None)

        Example XML junit structure we're building:
        <testsuite errors="1" failures="1" hostname="localhost" id="0" name="test1"
                   package="testdb" tests="4" timestamp="2012-11-15T01:02:29">
            <properties>
                <property name="assert-passed" value="1"/>
            </properties>
            <testcase classname="testdb.directory" name="1-passed-test" time="10"/>
        """

        try:
            if " : " in task_data.name:
                class_name, task_name = task_data.name.split(' : ')
                # Uncomment if we want to include the order tasks are executed in, not necessary when only recording
                # failures
                # self._task_number += 1
                # task_name = "{:04d}_{}".format(self._task_number, task_name)
                class_name = '{}.{}'.format(host_data.name, class_name)
                test_suite_name = self.playbook_name
            else:
                class_name = "{}.ENTRY POINT PLAYBOOK ({})".format(host_data.name, self.playbook_name)
                # self._task_number += 1
                # task_name = "{:04d}_{}".format(self._task_number, task_data.name)
                task_name = task_data.name
                test_suite_name = "ENTRY POINT PLAYBOOK"
        except Exception as e:
            self._display.warning(repr(e))

        duration = host_data.finish - task_data.start

        # Include cases
        if "include" in task_name:
            task_name = self._get_include(task_name, host_data)

        if host_data.status == 'included' and return_status.get("return_included"):
            test_case = TestCase(name=task_name,
                                 classname=class_name,
                                 elapsed_sec=duration,
                                 stdout=host_data.result)
            return TestSuite(test_suite_name, [test_case], hostname=host_data.name, package=task_data.path)
        elif host_data.status == 'included' and not return_status.get("return_included"):
            return None

        # Set some vars for the following cases
        res = host_data.result._result
        rc = res.get('rc', 0)
        dump = self._dump_results(res, indent=0)

        # OK cases
        if host_data.status == 'ok' and return_status.get("return_ok"):
            test_case = TestCase(name=task_name,
                                 classname=class_name,
                                 elapsed_sec=duration,
                                 stdout=dump)
            return TestSuite(test_suite_name, [test_case], hostname=host_data.name, package=task_data.path)
        elif host_data.status == 'ok' and not return_status.get("return_ok"):
            return None

        test_case = TestCase(name=task_name,
                             classname=class_name,
                             elapsed_sec=duration)

        # Failed cases
        if host_data.status == 'failed' and return_status.get("return_failed"):
            if 'exception' in res:
                message = res['exception'].strip().split('\n')[-1]
                output = res['exception']
                test_case.add_error_info(message, output)
            elif 'msg' in res:
                message = res['msg']
                test_case.add_failure_info(message, dump)
            else:
                test_case.add_failure_info('rc=%s' % rc, dump)
            return TestSuite(test_suite_name, [test_case], hostname=host_data.name, package=task_data.path)
        elif host_data.status == 'failed' and not return_status.get("return_failed"):
            return None

        # Skipped cases
        if host_data.status == 'skipped' and return_status.get("return_skipped"):
            if 'skip_reason' in res:
                message = res['skip_reason']
            else:
                message = 'skipped'
            test_case.add_skipped_info(message)
            return TestSuite(test_suite_name, [test_case], hostname=host_data.name, package=task_data.path)
        elif host_data.status == 'skipped' and not return_status.get("return_skipped"):
            return None

    def _generate_report(self):
        """ generate a TestSuite report from the collected TaskData and HostData """

        test_suites = []

        # Create test suites for all failed hosts
        for task_uuid, task_data in self._task_data.items():
            for host_uuid, host_data in task_data.host_data.items():
                _test_suite = self._build_test_suite(task_data, host_data, return_failed=True)
                if _test_suite:
                    test_suites.append(_test_suite)

        # Create test suites for all successful hosts
        for host in {host for host in self._hosts_status['ok'] if host not in self._hosts_status['failed']}:
            class_name = "{}.ENTRY POINT PLAYBOOK ({})".format(host, self.playbook_name)
            test_case = TestCase(name='Success', classname=class_name)
            test_suites.append(TestSuite("SUCCESS", [test_case], hostname=host, package=None))

        if test_suites:
            report = TestSuite.to_xml_string(test_suites)
        else:
            test_case = TestCase(name='SUCCESS', classname="NO FAILURES")
            test_suites = [TestSuite("SUCCESS", [test_case])]
            report = TestSuite.to_xml_string(test_suites)

        with open(self.log_file, 'wb') as xml:
            xml.write(to_bytes(report, errors='strict'))

    def v2_playbook_on_start(self, playbook):
        file_name = os.path.basename(playbook._file_name)
        self.playbook_name = file_name.replace('.yml', '')
        self.log_file = self.get_log_name(suffix="xml")

    def v2_playbook_on_play_start(self, play):
        self._play_name = play.get_name()

    def v2_runner_on_no_hosts(self, task):
        self._start_task(task)

    def v2_playbook_on_task_start(self, task, is_conditional):
        self._start_task(task)

    def v2_playbook_on_cleanup_task_start(self, task):
        self._start_task(task)

    def v2_playbook_on_handler_task_start(self, task):
        self._start_task(task)

    def v2_runner_on_failed(self, result, ignore_errors=False):
        self._hosts_status['failed'].append(result._host.name)
        if ignore_errors:
            self._finish_task('ok', result)
        else:
            self._finish_task('failed', result)

    def v2_runner_on_ok(self, result):
        self._hosts_status['ok'].append(result._host.name)
        self._finish_task('ok', result)

    def v2_runner_on_skipped(self, result):
        self._finish_task('skipped', result)

    def v2_playbook_on_include(self, included_file):
        self._finish_task('included', included_file)

    def v2_playbook_on_stats(self, stats):
        self._generate_report()
