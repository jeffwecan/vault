import os
import time

from ansible.plugins.callback import CallbackBase
from collections import OrderedDict

__metaclass__ = type


class CallbackModule(CallbackBase):
    """
    This class is here to prevent ansible complaining
    """
    def __init__(self):
        self.disabled = True


class WPECallbackBase(CallbackBase):
    """
    This is the base WPEngine callback for setting up some standard methods and values
    """

    def __init__(self):
        super(WPECallbackBase, self).__init__()
        # Results are stored here
        self._task_data = {}
        self.playbook_name = None

        # Get phase from env variable passed from deploy script
        self.deploy_phase = os.getenv('WPE_DEPLOY_PHASE', 'no_phase')

        # When deploying a single package, phased-deploy will set this so we can name logs better and update hipchat
        self.package_name = os.getenv('WPE_DEPLOY_PACKAGE_NAME', None)

        # Default log directory just in case
        self.log_dir = os.getenv('WPE_DEPLOY_LOG_DIR', os.getenv('HOME') + '/ansible_deploy_logs')

        # Ensure log dir exists for this playbook execution
        if not os.path.exists(self.log_dir):
            os.makedirs(self.log_dir)

    def get_log_name(self, suffix="log"):
        """Generate base log name in the format: playbook_name-phase_x-type-iter"""
        # Update deploy_phase each time we call get_log_name
        self.deploy_phase = os.getenv('WPE_DEPLOY_PHASE', 'no_phase')

        if self.package_name is None:
            name = "{}-{}".format(
                self.playbook_name,
                self.deploy_phase,
            )
        else:
            name = "package-{}-{}".format(
                self.package_name,
                self.deploy_phase
            )

        log_path = os.path.join(self.log_dir, name)

        # Append iteration number starting at 1
        i = 1
        while os.path.exists("{}-{}.{}".format(log_path, i, suffix)):
            i += 1
        log_path = "{}-{}".format(log_path, i)

        return "{}.{}".format(log_path, suffix)

    def _start_task(self, task):
        """ record the start of a task for one or more hosts """

        uuid = task._uuid

        if uuid in self._task_data:
            return

        play = self._play_name
        name = task.get_name().strip()
        path = task.get_path()

        self._task_data[uuid] = TaskData(uuid, name, path, play)

    def _finish_task(self, status, result):
        """ record the results of a task for a single host """
        task_uuid = result._task._uuid
        task_data = self._task_data[task_uuid]

        if hasattr(result, '_host'):
            host_uuid = result._host._uuid
            host_name = result._host.name
            # This is only useful if doing a local run against a single host
            # if not self._host_name:
            #    self._host_name = host_name
        else:
            host_uuid = 'include'
            host_name = 'include'

        if status == 'failed' and 'EXPECTED FAILURE' in task_data.name:
            status = 'ok'

        task_data.add_host(HostData(host_uuid, host_name, status, result))


class TaskData:
    """
    Data about an individual task.
    """

    def __init__(self, uuid, name, path, play):
        self.uuid = uuid
        self.name = name
        self.path = path
        self.play = play
        self.start = None
        self.host_data = OrderedDict()
        self.start = time.time()

    def add_host(self, host):
        if host.uuid in self.host_data:
            if host.status == 'included':
                # concatenate task include output from multiple items
                host.result = '%s\n%s' % (self.host_data[host.uuid].result, host.result)

        self.host_data[host.uuid] = host


class HostData:
    """
    Data about an individual host.
    """

    def __init__(self, uuid, name, status, result):
        self.uuid = uuid
        self.name = name
        self.status = status
        self.result = result
        self.finish = time.time()
