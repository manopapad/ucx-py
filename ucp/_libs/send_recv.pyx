# Copyright (c) 2019, NVIDIA CORPORATION. All rights reserved.
# See file LICENSE for terms.
# cython: language_level=3

import asyncio
import logging
import uuid
from core_dep cimport *
from .utils import get_buffer_data
from ..exceptions import UCXError, UCXCanceled

cdef create_future_from_comm_status(ucs_status_ptr_t status,
                                    size_t expected_receive,
                                    pending_msg):
    ret = asyncio.get_event_loop().create_future()
    if UCS_PTR_STATUS(status) == UCS_OK:
        ret.set_result(True)
    else:
        req = <ucp_request*> status
        if req.finished:
            ret.set_result(True)
            req.finished = False
            req.future = NULL
            req.expected_receive = 0
        else:
            Py_INCREF(ret)
            req.future = <void*> ret
            req.expected_receive = expected_receive
            if pending_msg is not None:
                pending_msg['future'] = ret
                pending_msg['ucp_request'] = PyLong_FromVoidPtr(<void*>req)
                pending_msg['expected_receive'] = expected_receive
    return ret

cdef void _send_callback(void *request, ucs_status_t status):
    cdef ucp_request *req = <ucp_request*> request
    if req.future == NULL:
        req.finished = True
        return
    cdef object future = <object> req.future
    if asyncio.get_event_loop().is_closed():
        pass
    elif status == UCS_ERR_CANCELED:
        future.set_exception(UCXCanceled())
    elif status != UCS_OK:
        msg = "[_send_callback] "
        msg += (<object> ucs_status_string(status)).decode("utf-8")
        future.set_exception(UCXError(msg))
    else:
        future.set_result(True)
    Py_DECREF(future)
    req.future = NULL
    ucp_request_free(request)


def tag_send(ucp_ep, buffer, nbytes, tag, pending_msg=None):
    cdef ucp_ep_h ep = <ucp_ep_h> PyLong_AsVoidPtr(ucp_ep)
    cdef void *data = PyLong_AsVoidPtr(get_buffer_data(buffer,
                                       check_writable=False))
    cdef ucs_status_ptr_t status = ucp_tag_send_nb(ep,
                                                   data,
                                                   nbytes,
                                                   ucp_dt_make_contig(1),
                                                   tag,
                                                   _send_callback)
    assert(not UCS_PTR_IS_ERR(status))
    return create_future_from_comm_status(status, nbytes, pending_msg)


cdef void _tag_recv_callback(void *request, ucs_status_t status,
                             ucp_tag_recv_info_t *info):
    cdef ucp_request *req = <ucp_request*> request
    if req.future == NULL:
        req.finished = True
        return
    cdef object future = <object> req.future
    msg = "[_tag_recv_callback] "
    if asyncio.get_event_loop().is_closed():
        pass
    elif status == UCS_ERR_CANCELED:
        future.set_exception(UCXCanceled())
    elif status != UCS_OK:
        msg += (<object> ucs_status_string(status)).decode("utf-8")
        future.set_exception(UCXError(msg))
    elif info.length != req.expected_receive:
        msg += "length mismatch: %d != %d" % (info.length,
                                              req.expected_receive)
        future.set_exception(UCXError(msg))
    else:
        future.set_result(True)
    Py_DECREF(future)
    req.future = NULL
    ucp_request_free(request)


def tag_recv(ucp_worker, buffer, nbytes, tag, pending_msg=None):
    cdef ucp_worker_h worker = <ucp_worker_h> PyLong_AsVoidPtr(ucp_worker)
    cdef void *data = PyLong_AsVoidPtr(get_buffer_data(buffer,
                                       check_writable=True))
    cdef ucs_status_ptr_t status = ucp_tag_recv_nb(worker,
                                                   data,
                                                   nbytes,
                                                   ucp_dt_make_contig(1),
                                                   tag,
                                                   -1,
                                                   _tag_recv_callback)
    assert(not UCS_PTR_IS_ERR(status))
    return create_future_from_comm_status(status, nbytes, pending_msg)


def stream_send(ucp_ep, buffer, nbytes, pending_msg=None):
    cdef ucp_ep_h ep = <ucp_ep_h> PyLong_AsVoidPtr(ucp_ep)
    cdef void *data = PyLong_AsVoidPtr(get_buffer_data(buffer,
                                       check_writable=False))
    cdef ucs_status_ptr_t status = ucp_stream_send_nb(ep,
                                                      data,
                                                      nbytes,
                                                      ucp_dt_make_contig(1),
                                                      _send_callback,
                                                      0)
    assert(not UCS_PTR_IS_ERR(status))
    return create_future_from_comm_status(status, nbytes, pending_msg)


cdef void _stream_recv_callback(void *request, ucs_status_t status,
                                size_t length):
    cdef ucp_request *req = <ucp_request*> request
    if req.future == NULL:
        req.finished = True
        return
    cdef object future = <object> req.future
    msg = "[_stream_recv_callback] "
    if asyncio.get_event_loop().is_closed():
        pass
    elif status == UCS_ERR_CANCELED:
        future.set_exception(UCXCanceled())
    elif status != UCS_OK:
        msg += (<object> ucs_status_string(status)).decode("utf-8")
        future.set_exception(UCXError(msg))
    elif length != req.expected_receive:
        msg += "length mismatch: %d != %d" % (length, req.expected_receive)
        future.set_exception(UCXError(msg))
    else:
        future.set_result(True)
    Py_DECREF(future)
    req.future = NULL
    ucp_request_free(request)


def stream_recv(ucp_ep, buffer, nbytes, pending_msg=None):
    cdef ucp_ep_h ep = <ucp_ep_h> PyLong_AsVoidPtr(ucp_ep)
    cdef void *data = PyLong_AsVoidPtr(get_buffer_data(buffer,
                                       check_writable=True))
    cdef size_t length
    cdef ucp_request *req
    cdef ucs_status_ptr_t status = ucp_stream_recv_nb(ep,
                                                      data,
                                                      nbytes,
                                                      ucp_dt_make_contig(1),
                                                      _stream_recv_callback,
                                                      &length,
                                                      0)
    assert(not UCS_PTR_IS_ERR(status))
    return create_future_from_comm_status(status, nbytes, pending_msg)
