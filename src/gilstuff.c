#ifdef __APPLE__
    #include <AvailabilityMacros.h>
    #if MAC_OS_X_VERSION_MAX_ALLOWED < 101300
        #include <Python/Python.h>
    #else
        #include <Python2.7/Python.h>
    #endif
#else
    #include <python2.7/Python.h>
#endif

#include <pthread.h>

#include "pony.h"

PyThreadState* main_thread_state;

PyInterpreterState* interpreter_state;

PyThreadState** thread_states;

int ponyint_sched_cores();

extern void init_interpreter_state()
{
  Py_Initialize();
  PyEval_InitThreads();
  main_thread_state = PyThreadState_Get();
  interpreter_state = main_thread_state->interp;

  int idx = pony_scheduler_index(pony_ctx());

  thread_states = malloc(sizeof(PyThreadState) * ponyint_sched_cores());

  thread_states[idx] = PyEval_SaveThread();
}

extern void finalize_interpreter()
{
  PyThreadState_Swap(main_thread_state);
  Py_Finalize();
}

extern void acquire_gil()
{
  int idx = pony_scheduler_index(pony_ctx());

  PyThreadState *thread_state = thread_states[idx];

  if (thread_state == NULL)
  {
    thread_state = thread_states[idx] = PyThreadState_New(interpreter_state);
  }

  PyEval_RestoreThread(thread_state);
}

extern void release_gil()
{
  int idx = pony_scheduler_index(pony_ctx());

  PyThreadState *thread_state = thread_states[idx];

  PyEval_SaveThread();
}
