Configuration
=============

UCX/UCX-PY can be configured with a wide variety of options and optimizations including: transport, caching, etc.  Users can configure
UCX/UCX-PY either with environment variables or programmatically during initialization.  Below we demonstrate setting ``UCX_MEMTYPE_CACHE`` to
``n`` and checking the configuration:

.. code-block:: python

    import ucp
    options = {"MEMTYPE_CACHE": "n"}
    ucp.init(options)
    assert ucp.get_config()['MEMTYPE_CACHE'] is 'n'

.. note::
    When programmatically configuring UCX-PY, the ``UCX`` prefix is not used.

For novice users we recommend the following settings:

::

    UCX_MEMTYPE_CACHE=n UCX_TLS=all

``UCX_TLS=all`` configures UCX to try all available transport methods.  However, users who want to define specific transport methods to use and/or other optional settings may do so.  Below we define the more common options and provide some example combinations and usage.

Env Vars
--------

DEBUG
~~~~~

Debug variables for both UCX and UCX-PY can be set

``UCXPY_LOG_LEVEL``
``UCX_LOG_LEVEL``

Values: DEBUG, TRACE

If UCX has been built with debug mode enabled

MEMORY
~~~~~~

``UCX_MEMTYPE_CACHE``

This is a UCX Memory optimization which toggles whether UCX library intercepts cu*alloc* calls.  UCX-PY defaults this value to  ``n``.  There `known issues <https://github.com/openucx/ucx/wiki/NVIDIA-GPU-Support#known-issues>`_ when using this feature.

Values: n/y

``UCX_CUDA_IPC_CACHE``

This is a UCX CUDA Memory optimization which enables/disables a remote endpoint IPC memhandle mapping cache. UCX/UCX-py defaults this value to ``y``

Values: n/y


``UCX_RNDV_SCHEME``

Communication scheme in RNDV protocol

Values:

- ``put_zcopy``
- ``get_zcopy``
- ``auto`` (default)


``UCX_TLS``

Transport Methods (Simplified):

- ``all`` -> use all the available transports
- ``rc`` -> InfiniBand (ibv_post_send, ibv_post_recv, ibv_poll_cq) uses rc_v and rc_x (preferably if available)
- ``cuda_copy`` -> cuMemHostRegister, cuMemcpyAsync
- ``cuda_ipc`` -> CUDA Interprocess Communication (cuIpcCloseMemHandle, cuIpcOpenMemHandle, cuMemcpyAsync)
- ``sockcm`` -> connection management over sockets
- ``sm/shm`` -> all shared memory transports (mm, cma, knem)
- ``mm`` -> shared memory transports - only memory mappers
- ``ugni`` -> ugni_smsg and ugni_rdma (uses ugni_udt for bootstrap)
- ``ib`` -> all infiniband transports (rc/rc_mlx5, ud/ud_mlx5, dc_mlx5)
- ``rc_v`` -> rc verbs (uses ud for bootstrap)
- ``rc_x`` -> rc with accelerated verbs (uses ud_mlx5 for bootstrap)
- ``ud_v`` -> ud verbs
- ``ud_x`` -> ud with accelerated verbs
- ``ud  `` -> ud_v and ud_x (preferably if available)
- ``dc/dc_x`` -> dc with accelerated verbs
- ``tcp`` -> sockets over TCP/IP
- ``cuda`` -> CUDA (NVIDIA GPU) memory support
- ``rocm`` -> ROCm (AMD GPU) memory support

``SOCKADDR_TLS_PRIORITY``

Priority of sockaddr transports


InfiniBand Device
~~~~~~~~~~~~~~~~~~

Select InfiniBand Device

``UCX_NET_DEVICES``

Typically these will be the InfiniBand device corresponding to a particular set of GPUs.  Values:

- ``mlx5_0:1``

To find more information on the topology of InfiniBand-GPU pairing run the following::

   nvidia-smi topo -m

Example Configs
---------------

IB -- Yes NVLINK
~~~~~~~~~~~~~~~~

::

    UCX_RNDV_SCHEME=put_zcopy UCX_MEMTYPE_CACHE=n UCX_TLS=rc,cuda_copy,cuda_ipc

TLS/Socket -- No NVLINK
~~~~~~~~~~~~~~~~~~~~~~~

::

    UCX_MEMTYPE_CACHE=n UCX_TLS=tcp,cuda_copy,sockcm UCX_SOCKADDR_TLS_PRIORITY=sockcm <SCRIPT>

TLS/Socket -- Yes NVLINK
~~~~~~~~~~~~~~~~~~~~~~~~

::

    UCX_MEMTYPE_CACHE=n UCX_TLS=tcp,cuda_copy,cuda_ipc,sockcm UCX_SOCKADDR_TLS_PRIORITY=sockcm <SCRIPT>
