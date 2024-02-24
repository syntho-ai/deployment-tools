import os
import fcntl
import subprocess
import click
import time
import select
import threading
import sys
import glob

from queue import Queue, Empty
from functools import wraps
from enum import Enum
from collections import namedtuple
from typing import Dict, NoReturn

from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer


# Sentinel object
END_OF_OUTPUT = object()
CURSOR_TRACKER = {}


def reset_cursor_tracker(deployment_id_or_process_name):
    global CURSOR_TRACKER
    CURSOR_TRACKER[deployment_id_or_process_name] = {}


def is_arch_supported(arch: str) -> bool:
    return arch in ["amd", "arm"]


def thread_safe(func):
    def wrapper(*args, **kwargs):
        deployments_dir = args[0] if args else kwargs.get(
            "deployments_dir", "/tmp")

        # Construct the lock file path
        lock_file_path = os.path.join(deployments_dir, ".lock")

        # Acquire the file-based lock
        with open(lock_file_path, "w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            try:
                return func(*args, **kwargs)
            finally:
                fcntl.flock(lock, fcntl.LOCK_UN)

    return wrapper


class ProgressBar:
    def __init__(self, message: str, total_steps: int, style: Dict = None):
        self.message = message
        self.total_steps = total_steps
        self.current_step = 0
        self.length = 20
        self.style = style

    def start(self):
        self.update_progress(0.1)
        final_message = self.make_final_message()
        click.echo(final_message)

    def update_progress(self, current_step: int):
        self.current_step = min(current_step, self.total_steps)

    def update(self, current_step: int):
        self.update_progress(current_step)
        self.current_step = min(current_step, self.total_steps)
        final_message = self.make_final_message()
        click.echo(f"\r{final_message}", nl=False)

    def get_progress_str(self):
        progress = self.current_step / self.total_steps
        progress_str = f"[{'#' * int(progress * self.length)}{'.' * (self.length - int(progress * self.length))}] [{int(progress * 100)}%]"
        return progress_str

    def make_final_message(self):
        final_message = f"{self.message}  -  {self.get_progress_str()}"
        if self.style is not None and isinstance(self.style, dict):
            final_message = click.style(f"{final_message}", **self.style)

        return final_message


def with_working_directory(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        original_dir = os.getcwd()

        try:
            result = func(*args, **kwargs)

            return result

        finally:
            os.chdir(original_dir)

    return wrapper


DeploymentResult = namedtuple("DeploymentResult", [
    "succeeded",
    "deployment_id",
    "error",
    "deployment_status",
])


SubprocessResult = namedtuple("SubprocessResult", [
    "succeeded",
    "output",
    "exitcode",
])


def get_deployments_dir(scripts_dir: str) -> str:
    deployments_dir = f"{scripts_dir}/deployments" 
    if not os.path.exists(deployments_dir):
        os.makedirs(deployments_dir)

    return deployments_dir


class CleanUpLevel(Enum):
    FULL = "full"
    DIR = "dir"
    NA = "not-applicable"


def run_script(scripts_dir:str,
               deployment_dir: str,
               script_name: str,
               capture_output: bool = False,
               **extra_env) -> SubprocessResult:
    env = {
        "DEPLOYMENT_DIR": deployment_dir,
        "PATH": os.environ.get("PATH", ""),
    }
    env.update(**extra_env)
    script_path = os.path.join(scripts_dir, script_name)

    try:
        if capture_output:
            res = subprocess.run([script_path], check=True, shell=False, env=env,
                                 capture_output=True, text=True)
        else:
            res = subprocess.run([script_path], check=True, shell=False, env=env)

        return SubprocessResult(
            succeeded=True,
            output=res.stdout.strip() if res.stdout else "",
            exitcode=res.returncode,
        )
    except subprocess.CalledProcessError as e:
        return SubprocessResult(succeeded=False, output=e.stderr, exitcode=e.returncode)
    except KeyboardInterrupt:
        return SubprocessResult(succeeded=False, output="", exitcode=1)
    except Exception as e:
        return SubprocessResult(succeeded=False, output="", exitcode=1)


def tail(f, lines, follow, deployment_id_or_process_name):
    """
    Simulates tail -f functionality, spooling the output of the file in realtime.
    """
    proc = subprocess.Popen(["tail", "-F", "-n", str(lines), f], stdout=subprocess.PIPE)
    cursor_tracker = CURSOR_TRACKER.get(deployment_id_or_process_name, {})
    CURSOR_TRACKER[deployment_id_or_process_name] = cursor_tracker
    last_cursor_point = cursor_tracker.get(f, 0)

    try:
        cursor = 0
        # for each read line, print it
        for line in read_lines(proc.stdout, 5 if follow else 0.1):
            if line:
                cursor += 1
                if cursor > last_cursor_point:
                    print(line.strip().decode())
                    last_cursor_point = cursor
                    CURSOR_TRACKER[deployment_id_or_process_name][f] = last_cursor_point
                else:
                    continue
            else:
                raise KeyboardInterrupt

    except KeyboardInterrupt:
        pass

    CURSOR_TRACKER[deployment_id_or_process_name][f] = last_cursor_point
    proc.kill()
    proc.wait()


def enqueue_output(out, queue):
    """Read lines from 'out' and put them into 'queue'"""
    for line in iter(out.readline, b''):
        queue.put(line)
    queue.put(END_OF_OUTPUT)


def read_lines(stdout, timeout):
    """Yield lines from 'stdout' with 'timeout' until no more lines are available"""
    q = Queue()
    reader_thread = threading.Thread(target=enqueue_output, args=(stdout, q))
    reader_thread.daemon = True  # Thread dies when the main program exits
    reader_thread.start()

    current_line = None
    while True:
        try:
            next_line = q.get(timeout=timeout)  # Raises Empty after 'timeout' if queue is empty
            if next_line is END_OF_OUTPUT:
                # If the sentinel is encountered, return the line and stop the function
                if current_line is not None:
                    yield current_line
                break
            else:
                if current_line is not None:
                    yield current_line
                current_line = next_line
        except Empty:
            # If a timeout is encountered, return the line and stop the function
            if current_line is not None:
                yield current_line
            break


class LogEventHandler(FileSystemEventHandler):

    def __init__(self,
                 *args,
                 lines=10,
                 follow=False,
                 deployment_id_or_process_name=None,
                 **kwargs):
        self.lines = lines
        self.follow = follow
        self.deployment_id_or_process_name=deployment_id_or_process_name
        super().__init__(*args, **kwargs)

    def on_any_event(self, event):
        time.sleep(0.5)
        if os.path.isfile(event.src_path):
            tail(event.src_path, self.lines, self.follow, self.deployment_id_or_process_name)


def deployment_exists(scripts_dir, deployment_id):
    deployments_dir = f"{scripts_dir}/deployments"
    deployment_dir = f"{deployments_dir}/{deployment_id}"

    return os.path.isdir(deployment_dir)


def utility_exists(scripts_dir, utility_name):
    utilities_dir = f"{scripts_dir}/utilities"
    utility_dir = f"{utilities_dir}/{utility_name}"

    return os.path.isdir(utility_dir)


def logs(scripts_dir, deployment_id_or_process_name, lines, follow, is_deployment=True):
    if is_deployment:
        if not deployment_exists(scripts_dir, deployment_id_or_process_name):
            return
    else:
        if not utility_exists(scripts_dir, deployment_id_or_process_name):
            return

    reset_cursor_tracker(deployment_id_or_process_name)

    if is_deployment:
        deployments_dir = f"{scripts_dir}/deployments"
    else:
        deployments_dir = f"{scripts_dir}/utilities"

    deployment_dir = f"{deployments_dir}/{deployment_id_or_process_name}"
    shared = f"{deployment_dir}/shared"
    if not os.path.exists(shared):
        os.makedirs(shared)

    process = f"{shared}/process"
    if not os.path.exists(process):
        os.makedirs(process)

    LOG_DIR = process
    # Generate list of log files with associated creation times
    log_files = [(f, os.path.getctime(f)) for f in glob.glob(os.path.join(LOG_DIR, '*.log'))]
    sorted_log_files = sorted(log_files, key=lambda x: x[1])

    for index, (filename, _) in enumerate(sorted_log_files):
        tail(filename, lines, index == len(sorted_log_files) - 1, deployment_id_or_process_name)

    if not follow:
        return

    # create an event handler
    event_handler = LogEventHandler(
        lines=lines,
        follow=follow,
        deployment_id_or_process_name=deployment_id_or_process_name,
    )

    # create an observer
    observer = Observer()
    observer.schedule(event_handler, LOG_DIR, recursive=False)

    # start the observer
    observer.start()

    try:
        # keep the script running
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        observer.join()
