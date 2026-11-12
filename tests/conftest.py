import logging
from subprocess import PIPE, run

from infrahouse_core.logging import setup_logging

DEFAULT_PROGRESS_INTERVAL = 10
TERRAFORM_ROOT_DIR = "test_data"

# The default image's owner and name, as the module looks it up: the Amazon
# Linux 2023 ECS-optimized image, as infrahouse/ecs/aws finds it.
AMAZON = "591542846629"
AL2023_ECS_IMAGES = "al2023-ami-ecs-hvm-*"


LOG = logging.getLogger(__name__)


setup_logging(LOG, debug=True)


def terraform(module_dir: str, *args: str) -> str:
    """
    Run a terraform command in a root module.

    :param module_dir: The root module's directory.
    :param args: The command and its arguments, after ``terraform``.
    :return: The command's stdout.
    :raise CalledProcessError: If terraform exits with non-zero.
    """
    LOG.info("Executing: terraform %s", " ".join(args))
    return run(
        ["terraform", *args], cwd=module_dir, stdout=PIPE, check=True, text=True
    ).stdout
