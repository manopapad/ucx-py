import pickle
import asyncio
import pytest
import sys
import ucp


async def hello(ep):
    import numpy as np    
    msg2send = np.arange(10)
    msg2recv = np.empty_like(msg2send)
    f1 = ep.send(msg2send)
    f2 = ep.recv(msg2recv)
    await f1
    await f2
    np.testing.assert_array_equal(msg2send, msg2recv)


async def server_node(ep):
    await hello(ep)


async def client_node(port):
    ep = await ucp.create_endpoint(ucp.get_address(), port)
    await hello(ep)
    

@pytest.mark.asyncio
async def test_multiple_nodes():
    np = pytest.importorskip("numpy")
    lf1 = ucp.create_listener(server_node)
    lf2 = ucp.create_listener(server_node)
    assert lf1.port != lf2.port

    nodes = []
    for _ in range(10):
        nodes.append(client_node(lf1.port))
        nodes.append(client_node(lf2.port))
    await asyncio.gather(*nodes, loop=asyncio.get_running_loop())
