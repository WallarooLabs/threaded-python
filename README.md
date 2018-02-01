# Threaded Python

This is an example using multiple Pony threads to call a shared Python interpreter.

## Build

### Building `ponyc`

First, you'll need to modify `ponyc`. You should be able to apply this patch to 69e9a53c91c3032c8824a90b3b2fe8df3634917a:

```
diff --git a/src/libponyrt/actor/actor.c b/src/libponyrt/actor/actor.c
index 68000d6b0..c6f724bfc 100644
--- a/src/libponyrt/actor/actor.c
+++ b/src/libponyrt/actor/actor.c
@@ -218,7 +218,7 @@ bool ponyint_actor_run(pony_ctx_t* ctx, pony_actor_t* actor, size_t batch)
   pony_msg_t* head = atomic_load_explicit(&actor->q.head, memory_order_relaxed);

   while((msg = ponyint_actor_messageq_pop(&actor->q
-#ifdef USE_DYNAMIC_TRACE
+#ifdef USE_DYNAMIC_TRACE
     , ctx->scheduler, ctx->current
 #endif
     )) != NULL)
@@ -507,7 +507,7 @@ PONY_API void pony_sendv(pony_ctx_t* ctx, pony_actor_t* to, pony_msg_t* first,
     ponyint_maybe_mute(ctx, to);

   if(ponyint_actor_messageq_push(&to->q, first, last
-#ifdef USE_DYNAMIC_TRACE
+#ifdef USE_DYNAMIC_TRACE
     , ctx->scheduler, ctx->current, to
 #endif
     ))
@@ -813,3 +813,10 @@ void ponyint_unmute_actor(pony_actor_t* actor)
   pony_assert(is_muted == 1);
   (void)is_muted;
 }
+
+// Thread magic
+
+PONY_API int32_t pony_scheduler_index(pony_ctx_t* ctx)
+{
+  return ctx->scheduler->index;
+}
diff --git a/src/libponyrt/pony.h b/src/libponyrt/pony.h
index 54f56400f..08f3e0af8 100644
--- a/src/libponyrt/pony.h
+++ b/src/libponyrt/pony.h
@@ -485,6 +485,11 @@ PONY_API void pony_register_thread();
  */
 PONY_API void pony_unregister_thread();

+/** Gets the index of the current scheduler.
+ * This can be used by applicaitons when doing per-thread configuration.
+ */
+PONY_API int32_t pony_scheduler_index(pony_ctx_t* ctx);
+
 /** Signals that the pony runtime may terminate.
  *
  * This only needs to be called if pony_start() was called with library set to
```

Then build `ponyc`.

### Building the Application

Here's the commands I'm using. *Make sure to replace `/Users/aturley/development/ponyc/src/libponyrt` with the appropriate path on your system to your newly compiled `ponyc`*.

```
clang -c -o gilstuff.o -I/Users/aturley/development/ponyc/src/libponyrt src/gilstuff.c
ar rcs lib/libgilstuff.a gilstuff.o
ponyc --path=lib .
```

## Run

To run with 1 incrementer actor:

```
PYTHONPATH=. ./threaded-pony 1
```

To run with 5 incrementer actors:

```
PYTHONPATH=. ./threaded-pony 1
```

Each incrementer will increment the global counter 1000 times.

## Things of Note

This program uses the GIL and a single Python interpreter.

The code in `thing.py` is thread-safe. You can remove the lock to see a race condition.

When the program terminates you will often see a message like this:

```
Exception KeyError: KeyError(123145485697024,) in <module 'threading' from '/usr/local/Cellar/python/2.7.11/Frameworks/Python.framework/Versions/2.7/lib/python2.7/threading.pyc'> ignored
```

I believe this is because the call to `Py_Finalize()` is being made from a thread that is not the thread that started the Python interpreter.
