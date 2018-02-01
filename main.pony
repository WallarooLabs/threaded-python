use "collections"
use "debug"
use "promises"

use "lib:python2.7"
use "lib:gilstuff"

actor Incrementer
  let _inc: Pointer[U8] val
  var _times: USize
  let _promise: Promise[Incrementer]

  new create(inc': Pointer[U8] val, times: USize, p: Promise[Incrementer]) =>
    _inc = inc'
    _times = times
    _promise = p
    inc()

  be inc() =>
    // let gstate = @PyGILState_Ensure[Pointer[U8]]()
    @acquire_gil[None]()

    @PyObject_CallFunctionObjArgs[Pointer[U8] val](_inc, Pointer[U8])

    //@PyGILState_Release[None](gstate)
    @release_gil[None]()

    _times = _times - 1
    if _times == 0 then
      _promise(this)
    else
      inc()
    end

actor Main
  let _print_x: Pointer[U8] val
  let _env: Env

  let incrementers: Array[Incrementer] = Array[Incrementer]

  new create(env: Env) =>
    _env = env
    Debug("starting")

    let actor_count = try
      env.args(1)?.usize()?
    else
      1
    end

    @init_interpreter_state[None]()

    @acquire_gil[None]()
    let thing = @PyImport_ImportModule[Pointer[U8]]("thing".cstring())

    let inc = @PyObject_GetAttrString[Pointer[U8] val](thing, "inc".cstring())

    _print_x = @PyObject_GetAttrString[Pointer[U8] val](thing, "print_x".cstring())

    @release_gil[None]()

    for _ in Range(0, actor_count) do
      let p = Promise[Incrementer]
      p.next[None](recover {(i: Incrementer)(m = this) => m.done(i)} end)
      incrementers.push(Incrementer(inc, 1000, p))
    end

  be done(incrementer: Incrementer) =>
    try incrementers.remove(incrementers.find(incrementer)?, 1) end

    if incrementers.size() == 0 then
      @acquire_gil[None]()
      @PyObject_CallFunctionObjArgs[Pointer[U8]](_print_x, Pointer[U8])
      @release_gil[None]()
      @finalize_interpreter[None]()
      Debug("finished")
    end
