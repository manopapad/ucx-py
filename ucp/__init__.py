# Copyright (c) 2019, NVIDIA CORPORATION. All rights reserved.
# See file LICENSE for terms.

"""UCX-Py: Python bindings for UCX <www.openucx.org>"""

import logging
import os

from ._version import get_versions as _get_versions
from .public_api import *  # noqa
from .public_api import get_ucx_version
from .utils import get_address  # noqa

logger = logging.getLogger("ucx")

# Notice, if we have to update environment variables
# we need to do it before importing UCX
if "UCX_MEMTYPE_CACHE" not in os.environ:
    # See <https://github.com/openucx/ucx/wiki/NVIDIA-GPU-Support#known-issues>
    logger.debug("Setting env UCX_MEMTYPE_CACHE=n, which is required by UCX")
    os.environ["UCX_MEMTYPE_CACHE"] = "n"

if "UCX_CUDA_IPC_CACHE" not in os.environ:
    # See <https://github.com/openucx/ucx/issues/4410>
    logger.debug(
        "Setting env UCX_CUDA_IPC_CACHE=n, which is required to avoid NVLink memory "
        "leaks"
    )
    os.environ["UCX_CUDA_IPC_CACHE"] = "n"

# Set the root logger before importing modules that use it
_level_enum = logging.getLevelName(os.getenv("UCXPY_LOG_LEVEL", "WARNING"))
logging.basicConfig(level=_level_enum, format="%(levelname)s %(message)s")


__version__ = _get_versions()["version"]
__ucx_version__ = "%d.%d.%d" % get_ucx_version()
