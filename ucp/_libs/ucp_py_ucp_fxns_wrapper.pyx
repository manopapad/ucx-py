# Copyright (c) 2018, NVIDIA CORPORATION. All rights reserved.
# See file LICENSE for terms.
# cython: language_level=3

cdef extern from "src/common.h":
    struct data_buf:
        void *buf


cdef extern from "src/ucp_py_ucp_fxns.h":
    struct ucx_context:
        int completed

cdef extern from "src/ucp_py_ucp_fxns.h":
    int ucp_py_worker_progress()
    int ucp_py_worker_progress_wait()
    int ucp_py_worker_drain_fd()
    int ucp_py_init()
    void *ucp_py_listen(listener_accept_cb_func, void *, int *)
    int ucp_py_stop_listener(void *)
    int ucp_py_finalize()
    void* ucp_py_get_ep(char *, int)
    int ucp_py_put_ep(void *)
    ucx_context* ucp_py_ep_send_nb(void*, data_buf*, size_t)
    ucx_context* ucp_py_recv_nb(void*, data_buf*, size_t)
    int ucp_py_ep_post_probe()
    int ucp_py_probe_query(void*)
    int ucp_py_probe_query_wo_progress(void*)
    int ucp_py_probe_wait(void*)
    int ucp_py_query_request(ucx_context*)
    int ucp_py_request_is_complete(ucx_context*)
    int ucp_py_worker_get_epoll_fd()

    void *get_worker()
    void *get_ep_ptr(void * ep)

