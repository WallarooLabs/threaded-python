import threading

x = 0
lock = threading.Lock()

def inc():
    global x, lock
    lock.acquire()
    x = x + 1
    lock.release()

def print_x():
    print(x)
