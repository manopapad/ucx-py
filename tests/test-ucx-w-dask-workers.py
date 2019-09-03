import pytest
from distributed.utils import format_bytes
import numpy as np
import asyncio
import dask.dataframe as dd
from distributed import Scheduler, Worker, Client, Nanny, wait
from distributed.utils import log_errors

#async with Nanny(s.address, protocol='ucx', nthreads=1,
# nanny is really a worker running on a defined CUDA DEVICE
protocol = 'ucx'
interface = 'ib0'  # Ff changing CUDA_VISIBLE_DEVICES CHECK IB Controller
import os


w_env = {
    "UCX_RNDV_SCHEME": "put_zcopy",
    "UCX_MEMTYPE_CACHE": "n",
    "UCX_TLS": "rc,cuda_copy,cuda_ipc",
    "CUDA_VISIBLE_DEVICES": "0,1",
}
os.environ.update(w_env)

w_env_2 = w_env.copy()
w_env_2["CUDA_VISIBLE_DEVICES"] = "1,0"

async def f(cudf_obj_generator):
    async with Scheduler(protocol=protocol, interface=interface,
    dashboard_address=':8789') as s:
        async with Nanny(s.address, protocol=protocol, nthreads=1,
                memory_limit='32GB', interface=interface,
                env=w_env,
                ) as w:
            async with Nanny(s.address, protocol=protocol,memory_limit='32gb',
                    env=w_env_2, interface=interface,
                    nthreads=1) as w2:
                async with Client(s.address, asynchronous=True) as c:
                    with log_errors():

                        def set_nb_context(x=None):
                            import numba.cuda
                            try:
                                numba.cuda.current_context()
                            except Exception:
                                print("FAILED EXCEPTION!")

                        print(f"SETTING CUDA CONTEXT ON WORKERS: {w.worker_address} / {w2.worker_address}")
                        out = await c.run(set_nb_context, workers=[w.worker_address, w2.worker_address])
                        print(set_nb_context())
                        # def get_env(x=None):
                        #     import os
                        #     return os.environ
                        # out = await c.run(get_env, workers=[w.worker_address, w2.worker_address])
                        # print(out)

                        print("Creating and Mapping CUDA Objects")
                        # offset worker two for unique hash names inside of dask
                        N = 100
                        left = c.map(cudf_obj_generator,
                                        range(N), workers=[w.worker_address])
                        right = c.map(cudf_obj_generator,
                                        range(1, N+1), workers=[w2.worker_address])
                        await wait(left)
                        await wait(right)
                        print("Gather CUDA Objects")
                        futures = c.map(lambda x, y: (x,y), left, right, priority=10)
                        results = await c.gather(futures, asynchronous=True)
                        print(await c.who_has(asynchronous=True))
                        print(results)
                        print("ALL DONE!")


def column(x):
    import cudf
    import numpy as np
    return cudf.Series(np.arange(10000))._column


def series(x):
    import cudf
    import numpy as np
    return cudf.Series(np.arange(10000))


def dataframe(x):
    import cudf
    import numpy as np

    size = 2 ** 12
    return cudf.DataFrame(
        {"a": np.random.random(size), "b": np.random.random(size)},
        index=np.random.randint(size, size=size),
    )



@pytest.mark.asyncio
@pytest.mark.parametrize("cudf_obj_generator", [
    column,
    series,
    dataframe
    ]
)
async def test_send_recv_cuda(event_loop, cudf_obj_generator):
    await f(cudf_obj_generator)