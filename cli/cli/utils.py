import fcntl
import glob
import os
import platform
import socket
import subprocess
import tarfile
import threading
import time
from collections import namedtuple
from enum import Enum
from functools import wraps
from queue import Empty, Queue

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
        deployments_dir = args[0] if args else kwargs.get("deployments_dir", "/tmp")

        # Construct the lock file path
        lock_file_path = os.path.join(deployments_dir, ".lock")
        if not os.path.exists(lock_file_path):
            if not os.path.exists(deployments_dir):
                os.makedirs(deployments_dir)

        # Acquire the file-based lock
        with open(lock_file_path, "w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            try:
                return func(*args, **kwargs)
            finally:
                fcntl.flock(lock, fcntl.LOCK_UN)

    return wrapper


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


DeploymentResult = namedtuple(
    "DeploymentResult",
    [
        "succeeded",
        "deployment_id",
        "error",
        "deployment_status",
    ],
)


SubprocessResult = namedtuple(
    "SubprocessResult",
    [
        "succeeded",
        "output",
        "exitcode",
    ],
)


def get_deployments_dir(scripts_dir: str) -> str:
    deployments_dir = f"{scripts_dir}/deployments"
    if not os.path.exists(deployments_dir):
        os.makedirs(deployments_dir)

    return deployments_dir


class CleanUpLevel(Enum):
    FULL = "full"
    DIR = "dir"
    NA = "not-applicable"


def run_script(
    scripts_dir: str, deployment_dir: str, script_name: str, capture_output: bool = False, **extra_env
) -> SubprocessResult:
    env = {
        "DEPLOYMENT_DIR": deployment_dir,
        "PATH": os.environ.get("PATH", ""),
    }
    env.update(**extra_env)
    script_path = os.path.join(scripts_dir, script_name)

    try:
        if capture_output:
            res = subprocess.run([script_path], check=True, shell=False, env=env, capture_output=True, text=True)
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
    except Exception:
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
    for line in iter(out.readline, b""):
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
    def __init__(self, *args, lines=10, follow=False, deployment_id_or_process_name=None, **kwargs):
        self.lines = lines
        self.follow = follow
        self.deployment_id_or_process_name = deployment_id_or_process_name
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
    log_files = [(f, os.path.getctime(f)) for f in glob.glob(os.path.join(LOG_DIR, "*.log"))]
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


def make_utilities_dir(scripts_dir):
    utilities_dir = generate_utilities_dir(scripts_dir)
    if not os.path.exists(utilities_dir):
        os.makedirs(utilities_dir)


def generate_utilities_dir(scripts_dir):
    return f"{scripts_dir}/utilities"


def check_acquired(file_dir):
    path = f"{file_dir}/.lock"
    if os.path.exists(path):
        return True
    return False


def acquire(file_dir):
    path = f"{file_dir}/.lock"
    with open(path, "a") as _:
        pass


def release(file_dir):
    path = f"{file_dir}/.lock"
    os.remove(path)


def set_status(file_dir, status):
    status_file_path = f"{file_dir}/status"
    with open(status_file_path, "w") as file:
        file.write(status)


def check_port(host, port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex((host, port))


def find_available_port(start_port, end_port, host="localhost"):
    for port in range(start_port, end_port + 1):
        if check_port(host, port):
            return port

    return None


def make_tarfile(output_filename, source_dir):
    with tarfile.open(output_filename, "w:gz") as tar:
        tar.add(source_dir, arcname=os.path.basename(source_dir))


def get_architecture():
    arch_info = platform.machine()

    if "x86" in arch_info:
        return "amd"
    elif "arm" in arch_info or "aarch" in arch_info:
        return "arm"
    else:
        return arch_info
