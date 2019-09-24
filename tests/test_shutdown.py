import asyncio
import pytest
import sys
import ucp
import numpy as np

from utils import device_name

async def shutdown(ep):
    await ep.signal_shutdown()
    ep.close()


@pytest.mark.asyncio
async def test_server_shutdown():
    """The server calls shutdown"""

    async def server_node(ep):
        msg = np.empty(10 ** 6)
        with pytest.raises(ucp.exceptions.UCXCanceled):
            await asyncio.gather(ep.recv(msg), shutdown(ep))

    async def client_node(port, device_name):
        ep = await ucp.create_endpoint(ucp.get_address(device_name), port)
        msg = np.empty(10 ** 6)
        with pytest.raises(ucp.exceptions.UCXCanceled):
            await ep.recv(msg)

    lf = ucp.create_listener(server_node)
    await client_node(lf.port)


@pytest.mark.asyncio
async def test_client_shutdown(device_name):
    """The client calls shutdown"""

    async def client_node(port):
        ep = await ucp.create_endpoint(ucp.get_address(device_name), port)
        msg = np.empty(10 ** 6)
        with pytest.raises(ucp.exceptions.UCXCanceled):
            await asyncio.gather(ep.recv(msg), shutdown(ep))

    async def server_node(ep):
        msg = np.empty(10 ** 6)
        with pytest.raises(ucp.exceptions.UCXCanceled):
            await ep.recv(msg)

    lf = ucp.create_listener(server_node)
    await client_node(lf.port)
