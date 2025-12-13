# Threading Implementation - Detailed Notes

## Overview
This document explains the implementation of POSIX thread synchronization using mutexes in `threading.c` and `threading.h`. The implementation demonstrates how multiple threads can safely coordinate access to shared resources using mutex locks.

---

## Table of Contents
1. [Data Structure Design](#1-data-structure-design)
2. [Thread Function Implementation](#2-thread-function-implementation)
3. [Thread Creation Function](#3-thread-creation-function)
4. [Memory Management](#4-memory-management)
5. [Visual Diagrams](#5-visual-diagrams)
6. [Testing and Usage](#6-testing-and-usage)

---

## 1. Data Structure Design

### **threading.h - `struct thread_data`**

#### **TODO Completed: Added Thread Communication Fields**

```c
struct thread_data {
    bool thread_complete_success;      // Original field
    pthread_mutex_t *mutex;            // ← Added: pointer to mutex
    int wait_to_obtain_ms;             // ← Added: wait time before lock
    int wait_to_release_ms;            // ← Added: wait time before unlock
};
```

### **Why These Fields?**

1. **`pthread_mutex_t *mutex`**
   - **Purpose:** Store reference to the mutex this thread will lock/unlock
   - **Type:** Pointer (not a copy) because mutexes should never be copied
   - **Usage:** Passed to `pthread_mutex_lock()` and `pthread_mutex_unlock()`

2. **`int wait_to_obtain_ms`**
   - **Purpose:** Milliseconds to sleep BEFORE attempting to lock the mutex
   - **Simulates:** Real-world scenarios where threads don't all try to lock simultaneously
   - **Range:** Can be 0 (immediate) to any positive value

3. **`int wait_to_release_ms`**
   - **Purpose:** Milliseconds to hold the mutex AFTER locking it
   - **Simulates:** Critical section work duration
   - **Range:** Can be 0 (release immediately) to any positive value

4. **`bool thread_complete_success`**
   - **Purpose:** Indicate whether thread completed all operations without errors
   - **Set to `true`:** Only if lock, unlock, and all operations succeeded
   - **Set to `false`:** If any error occurred (lock failure, unlock failure)

### **ASCII Diagram: Data Structure Flow**

```
thread_data Structure (Heap Allocated)
┌─────────────────────────────────────────────┐
│  thread_complete_success: false             │ ← Status flag
├─────────────────────────────────────────────┤
│  mutex: 0x7fff1234 ────────────────┐        │ ← Points to shared mutex
├────────────────────────────────────┼────────┤
│  wait_to_obtain_ms: 100            │        │ ← Sleep 100ms before lock
├────────────────────────────────────┘        │
│  wait_to_release_ms: 200                    │ ← Hold lock for 200ms
└─────────────────────────────────────────────┘
                                      │
                                      ▼
                        pthread_mutex_t (Shared)
                        ┌─────────────────────┐
                        │ Mutex Object        │
                        │ State: Unlocked/    │
                        │        Locked       │
                        └─────────────────────┘
```

---

## 2. Thread Function Implementation

### **threading.c - `threadfunc()`**

#### **TODO Completed: Implement Wait-Lock-Wait-Unlock Pattern**

```c
void* threadfunc(void* thread_param)
{
    // Cast void* to thread_data*
    struct thread_data* thread_func_args = (struct thread_data *) thread_param;
    
    // Initialize to false (pessimistic approach)
    thread_func_args->thread_complete_success = false;
    
    // STEP 1: Wait before obtaining mutex
    usleep(thread_func_args->wait_to_obtain_ms * 1000);
    
    // STEP 2: Lock the mutex
    int rc = pthread_mutex_lock(thread_func_args->mutex);
    if (rc != 0) {
        ERROR_LOG("Failed to lock mutex, error code: %d", rc);
        return thread_param;
    }
    
    // STEP 3: Wait while holding the mutex (critical section)
    usleep(thread_func_args->wait_to_release_ms * 1000);
    
    // STEP 4: Unlock the mutex
    rc = pthread_mutex_unlock(thread_func_args->mutex);
    if (rc != 0) {
        ERROR_LOG("Failed to unlock mutex, error code: %d", rc);
        return thread_param;
    }
    
    // STEP 5: Mark success
    thread_func_args->thread_complete_success = true;
    
    return thread_param;
}
```

### **Step-by-Step Explanation**

#### **Step 0: Type Casting**
```c
struct thread_data* thread_func_args = (struct thread_data *) thread_param;
```
- **Why?** `pthread_create()` passes `void*` for flexibility
- **Safety:** We know it's actually a `thread_data*` because we passed it
- **Access:** Now we can access the structure fields

#### **Step 1: Initial Wait (Pre-Lock Delay)**
```c
usleep(thread_func_args->wait_to_obtain_ms * 1000);
```
- **Function:** `usleep()` - microsecond sleep
- **Conversion:** milliseconds × 1000 = microseconds
- **Purpose:** Simulate different thread start times
- **Example:** If `wait_to_obtain_ms = 100`, sleeps for 100,000 microseconds (0.1 seconds)

#### **Step 2: Lock the Mutex**
```c
int rc = pthread_mutex_lock(thread_func_args->mutex);
if (rc != 0) {
    ERROR_LOG("Failed to lock mutex, error code: %d", rc);
    return thread_param;
}
```
- **Function:** `pthread_mutex_lock()` - acquire exclusive lock
- **Blocking:** If another thread holds the lock, THIS THREAD WAITS
- **Return Value:** 0 on success, error code on failure
- **Error Handling:** On failure, log error and return early
- **Critical:** `thread_complete_success` remains `false`

**Common Error Codes:**
- `EINVAL (22)` - Invalid mutex
- `EDEADLK (35)` - Deadlock detected (same thread trying to lock twice)

#### **Step 3: Critical Section Wait (Holding Lock)**
```c
usleep(thread_func_args->wait_to_release_ms * 1000);
```
- **Context:** Mutex is LOCKED at this point
- **Purpose:** Simulate doing work in critical section
- **Effect:** Other threads trying to lock will block/wait here
- **Real-world:** This would be where you access shared data

#### **Step 4: Unlock the Mutex**
```c
rc = pthread_mutex_unlock(thread_func_args->mutex);
if (rc != 0) {
    ERROR_LOG("Failed to unlock mutex, error code: %d", rc);
    return thread_param;
}
```
- **Function:** `pthread_mutex_unlock()` - release lock
- **Effect:** Allows one waiting thread to acquire the lock
- **Error Handling:** Should rarely fail, but check anyway
- **Critical:** If unlock fails, mutex stays locked (bad!)

**Common Error Codes:**
- `EPERM (1)` - Thread doesn't own this mutex
- `EINVAL (22)` - Invalid mutex

#### **Step 5: Mark Success**
```c
thread_func_args->thread_complete_success = true;
```
- **Only reaches here:** If all operations succeeded
- **Purpose:** Signal to main thread that this thread completed correctly
- **Checked by:** Test code or main thread after `pthread_join()`

### **ASCII Diagram: Thread Execution Flow**

```
Thread Lifecycle:
═══════════════════════════════════════════════════════════════

Time
  │
  │  pthread_create() called
  │  ↓
  ├──► Thread spawned, threadfunc() starts
  │    │
  │    ├─ Cast parameter to thread_data*
  │    │
  │    ├─ Set thread_complete_success = false
  │    │
  │    ├─ usleep(wait_to_obtain_ms * 1000)
  │    │  │
  │    │  └─► [Thread sleeping...] 💤
  │    │                              
  │    ├─ pthread_mutex_lock(mutex)
  │    │  │
  │    │  ├─ If mutex available: LOCK ACQUIRED ✓
  │    │  │  └─► Continue
  │    │  │
  │    │  └─ If mutex locked by another thread:
  │    │     └─► [Thread blocked, waiting...] 🚫
  │    │         (Another thread holds the lock)
  │    │         Wait here until unlock...
  │    │                              
  │    ├─ CRITICAL SECTION START 🔒
  │    │  │
  │    │  ├─ usleep(wait_to_release_ms * 1000)
  │    │  │  │
  │    │  │  └─► [Thread sleeping while holding lock...] 💤🔒
  │    │  │      (Simulating work on shared resource)
  │    │  │
  │    ├─ CRITICAL SECTION END
  │    │
  │    ├─ pthread_mutex_unlock(mutex)
  │    │  └─► Lock released, other threads can acquire 🔓
  │    │
  │    ├─ Set thread_complete_success = true ✅
  │    │
  │    └─ return thread_param
  │       │
  │       └─► Thread exits
  │           (Can be joined by main thread)
  ▼

Legend:
💤 = Sleeping (not using CPU)
🔒 = Holding mutex lock
🔓 = Released mutex lock
🚫 = Blocked waiting for mutex
✓ = Success
✅ = Completed successfully
```

---

## 3. Thread Creation Function

### **threading.c - `start_thread_obtaining_mutex()`**

#### **TODO Completed: Allocate, Setup, and Launch Thread**

```c
bool start_thread_obtaining_mutex(pthread_t *thread, 
                                   pthread_mutex_t *mutex,
                                   int wait_to_obtain_ms, 
                                   int wait_to_release_ms)
{
    // STEP 1: Allocate memory
    struct thread_data *data = malloc(sizeof(struct thread_data));
    if (data == NULL) {
        ERROR_LOG("Failed to allocate memory for thread_data");
        return false;
    }
    
    // STEP 2: Initialize structure
    data->mutex = mutex;
    data->wait_to_obtain_ms = wait_to_obtain_ms;
    data->wait_to_release_ms = wait_to_release_ms;
    data->thread_complete_success = false;
    
    // STEP 3: Create thread
    int rc = pthread_create(thread, NULL, threadfunc, (void *)data);
    if (rc != 0) {
        ERROR_LOG("Failed to create thread, error code: %d", rc);
        free(data);  // Clean up on failure
        return false;
    }
    
    return true;  // Success
}
```

### **Detailed Parameter Analysis**

#### **Input Parameters:**

1. **`pthread_t *thread`**
   - **Type:** Pointer to thread ID
   - **Purpose:** `pthread_create()` will fill this with new thread's ID
   - **Usage after:** Can use for `pthread_join()`, `pthread_cancel()`, etc.

2. **`pthread_mutex_t *mutex`**
   - **Type:** Pointer to initialized mutex
   - **Requirement:** Caller must have already called `pthread_mutex_init()`
   - **Shared:** Same mutex pointer given to multiple threads

3. **`int wait_to_obtain_ms`**
   - **Type:** Milliseconds (integer)
   - **Purpose:** How long to wait before attempting lock
   - **Test scenario:** Different values create different race conditions

4. **`int wait_to_release_ms`**
   - **Type:** Milliseconds (integer)
   - **Purpose:** How long to hold the lock
   - **Test scenario:** Longer = more contention for other threads

#### **Return Value:**

- **`true`:** Thread created successfully, `*thread` contains valid ID
- **`false`:** Failed (memory allocation or thread creation error)

### **Step-by-Step Explanation**

#### **Step 1: Dynamic Memory Allocation**
```c
struct thread_data *data = malloc(sizeof(struct thread_data));
if (data == NULL) {
    ERROR_LOG("Failed to allocate memory for thread_data");
    return false;
}
```

**Why malloc()?**
- **Lifetime:** Data must survive after this function returns
- **Thread access:** Worker thread needs this data to still exist
- **Scope:** Stack-allocated data would be destroyed when function exits

**Memory Layout:**
```
Heap Memory:
┌─────────────────────────────────────┐
│  struct thread_data                 │
│  ┌───────────────────────────────┐  │
│  │ thread_complete_success: false│  │
│  │ mutex: 0x...                  │  │
│  │ wait_to_obtain_ms: ...        │  │
│  │ wait_to_release_ms: ...       │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
         ↑
         │
    data pointer
    (returned to thread)
```

**Error Handling:**
- Check for `NULL` (allocation failure)
- Common causes: Out of memory, system limits
- Return `false` to indicate failure to caller

#### **Step 2: Initialize Structure**
```c
data->mutex = mutex;
data->wait_to_obtain_ms = wait_to_obtain_ms;
data->wait_to_release_ms = wait_to_release_ms;
data->thread_complete_success = false;
```

**Field-by-field:**

1. **`data->mutex = mutex;`**
   - Stores the pointer (NOT copying the mutex)
   - All threads share the same mutex object
   - Critical for synchronization to work

2. **`data->wait_to_obtain_ms = wait_to_obtain_ms;`**
   - Copies the integer value
   - Each thread can have different wait time
   - Used by worker thread before locking

3. **`data->wait_to_release_ms = wait_to_release_ms;`**
   - Copies the integer value
   - Controls critical section duration
   - Used by worker thread while holding lock

4. **`data->thread_complete_success = false;`**
   - Pessimistic initialization
   - Only set to `true` if thread completes successfully
   - Safe default for error scenarios

#### **Step 3: Create Thread**
```c
int rc = pthread_create(thread, NULL, threadfunc, (void *)data);
if (rc != 0) {
    ERROR_LOG("Failed to create thread, error code: %d", rc);
    free(data);  // ← IMPORTANT: Cleanup on failure
    return false;
}
```

**pthread_create() Parameters:**

```c
pthread_create(
    thread,     // Output: Thread ID stored here
    NULL,       // Thread attributes (NULL = defaults)
    threadfunc, // Function to execute in new thread
    (void *)data // Parameter passed to threadfunc
)
```

**Thread Attributes (NULL = defaults):**
- **Stack size:** System default (usually 2-8 MB)
- **Scheduling:** Inherit from parent
- **Detach state:** Joinable (can call `pthread_join()`)

**Error Codes:**
- `EAGAIN (11)` - Insufficient resources
- `EINVAL (22)` - Invalid attributes
- `EPERM (1)` - No permission to set scheduling

**Critical Error Handling:**
```c
free(data);  // Must free allocated memory!
```
- If thread creation fails, allocated memory would leak
- Worker thread never starts, so it can't free the memory
- Main thread must clean up

### **ASCII Diagram: Function Call Flow**

```
Main Thread                                Worker Thread
═══════════════════════════════════════════════════════════

start_thread_obtaining_mutex()
  │
  ├─ malloc(thread_data)
  │  └─► Heap: [thread_data allocated]
  │
  ├─ Initialize fields:
  │    data->mutex = ...
  │    data->wait_to_obtain_ms = ...
  │    data->wait_to_release_ms = ...
  │    data->thread_complete_success = false
  │
  ├─ pthread_create(&thread, NULL, threadfunc, data)
  │  │
  │  └─────────────────────────────────────► threadfunc(data) starts
  │                                            │
  │                                            ├─ Access data fields
  │                                            ├─ Sleep
  │                                            ├─ Lock mutex
  │                                            ├─ Sleep (critical)
  │                                            ├─ Unlock mutex
  │                                            ├─ Set success = true
  │                                            └─ return data
  │                                               │
  ├─ return true                                 │
  │  (Function exits, thread still running) ◄────┘
  │                                            Thread continues...
  ▼
(Later: pthread_join() can wait for thread)
```

---

## 4. Memory Management

### **Memory Lifecycle**

```
┌─────────────────────────────────────────────────────────┐
│                    MEMORY LIFECYCLE                      │
└─────────────────────────────────────────────────────────┘

Phase 1: ALLOCATION
───────────────────
Main Thread:
  start_thread_obtaining_mutex() called
    │
    └─► malloc(sizeof(struct thread_data))
        │
        └─► Heap memory allocated
            [thread_data structure created]


Phase 2: OWNERSHIP TRANSFER
────────────────────────────
Main Thread:                    Worker Thread:
  pthread_create(..., data) ──────────► threadfunc(data)
    │                                     │
    └─ Main thread returns                ├─ Owns data pointer
       (doesn't free data!)               ├─ Uses data fields
                                          └─ Returns data pointer


Phase 3: CLEANUP
─────────────────
Main Thread:
  pthread_join(thread, &result)
    │
    ├─ Waits for worker thread to finish
    │
    └─► Worker thread exits, returns data pointer
        │
        └─► result = data
            │
            ├─ Check: result->thread_complete_success
            │
            └─► free(result)  ← FREE THE MEMORY HERE!
```

### **Who Frees What?**

#### **Normal Success Case:**
```c
// Main thread
pthread_t thread;
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

// Start thread (allocates memory)
start_thread_obtaining_mutex(&thread, &mutex, 100, 200);

// Wait for thread to complete
struct thread_data *result;
pthread_join(thread, (void **)&result);

// Check success
if (result->thread_complete_success) {
    printf("Thread succeeded!\n");
}

// Free the memory allocated in start_thread_obtaining_mutex()
free(result);  // ← CALLER'S RESPONSIBILITY
```

#### **Failure During Thread Creation:**
```c
// Inside start_thread_obtaining_mutex()
int rc = pthread_create(...);
if (rc != 0) {
    free(data);  // ← FUNCTION FREES ITS OWN ALLOCATION
    return false;
}
```

### **ASCII Diagram: Memory Flow**

```
Memory Ownership Transfer:
═══════════════════════════════════════════════════════

   HEAP
┌────────┐
│ malloc │
│  data  │◄───────────────────┐
└────┬───┘                    │
     │                        │
     │ 1. Allocated by        │
     │    start_thread_       │ 7. Freed by
     │    obtaining_mutex()   │    main thread
     │                        │
     ▼                        │
┌─────────────┐               │
│ thread_data │               │
│  structure  │               │
└─────┬───────┘               │
      │                       │
      │ 2. Passed to          │
      │    pthread_create()   │
      │                       │
      ▼                       │
┌──────────────┐              │
│ Worker Thread│              │
│  threadfunc()│              │
│              │              │
│ 3. Uses data │              │
│ 4. Does work │              │
│ 5. Sets      │              │
│    success   │              │
│ 6. Returns   │              │
│    data ptr  ├──────────────┘
└──────────────┘
```

### **Memory Leak Prevention**

**❌ WRONG - Memory Leak:**
```c
pthread_t thread;
start_thread_obtaining_mutex(&thread, &mutex, 100, 200);
pthread_join(thread, NULL);  // ← Doesn't save return value!
// Memory leaked! No way to free it now.
```

**✅ CORRECT - Proper Cleanup:**
```c
pthread_t thread;
struct thread_data *result;

start_thread_obtaining_mutex(&thread, &mutex, 100, 200);
pthread_join(thread, (void **)&result);

// Use result if needed
if (result->thread_complete_success) {
    // ...
}

free(result);  // ← Properly freed
```

---

## 5. Visual Diagrams

### **Complete Multi-Thread Scenario**

```
Scenario: 3 threads competing for 1 mutex
═══════════════════════════════════════════════════════════

Time
  │
  │   [Mutex initially unlocked]
  │   
  ├─── Thread 1: wait_to_obtain = 50ms, wait_to_release = 100ms
  ├─── Thread 2: wait_to_obtain = 20ms, wait_to_release = 150ms
  └─── Thread 3: wait_to_obtain = 80ms, wait_to_release = 50ms
  │
  ▼

0ms   │ Thread1  │ Thread2  │ Thread3  │ Mutex State
      ├──────────┼──────────┼──────────┼─────────────
      │ sleep    │ sleep    │ sleep    │ UNLOCKED
      │          │          │          │
20ms  │ sleep    │ try lock │ sleep    │ UNLOCKED
      │          │ ✓LOCKED  │          │ LOCKED by T2
      │          │          │          │
50ms  │ try lock │ critical │ sleep    │ LOCKED by T2
      │ 🚫WAIT   │ section  │          │
      │          │          │          │
80ms  │ 🚫WAIT   │ critical │ try lock │ LOCKED by T2
      │          │ section  │ 🚫WAIT   │
      │          │          │          │
170ms │ 🚫WAIT   │ unlock   │ 🚫WAIT   │ UNLOCKED
      │          │ ✅done   │          │
      │ ✓LOCKED  │          │ 🚫WAIT   │ LOCKED by T1
      │ critical │          │          │
      │ section  │          │          │
      │          │          │          │
270ms │ unlock   │          │ 🚫WAIT   │ UNLOCKED
      │ ✅done   │          │          │
      │          │          │ ✓LOCKED  │ LOCKED by T3
      │          │          │ critical │
      │          │          │ section  │
      │          │          │          │
320ms │          │          │ unlock   │ UNLOCKED
      │          │          │ ✅done   │
      ▼          ▼          ▼          ▼

Total time: 320ms (not 300ms due to serialization)

Legend:
✓ = Successfully locked
🚫 = Blocked waiting
✅ = Completed successfully
```

### **Mutex State Diagram**

```
Mutex State Machine:
═══════════════════════════════════════════════════════

        ┌─────────────────┐
        │                 │
        │    UNLOCKED     │
        │   (available)   │
        │                 │
        └────────┬────────┘
                 │
                 │ pthread_mutex_lock()
                 │ by Thread A
                 │
                 ▼
        ┌─────────────────┐
        │                 │
        │     LOCKED      │
        │  (owned by A)   │
        │                 │
        └────────┬────────┘
                 │
                 │ pthread_mutex_unlock()
                 │ by Thread A
                 │
                 ▼
        ┌─────────────────┐
        │                 │
        │    UNLOCKED     │
        │  (available     │
        │   for Thread B) │
        │                 │
        └─────────────────┘


Waiting Threads Queue:
═══════════════════════════════════════════════════════

When multiple threads try to lock:

        Mutex (Locked by Thread A)
             │
             ├─── Thread B (waiting) ──┐
             ├─── Thread C (waiting)   │ FIFO or
             └─── Thread D (waiting)   │ Priority-based
                                       │ (implementation
                                       │  dependent)
                                       └──► Next to acquire
                                            when unlocked
```

### **Data Structure Relationships**

```
Complete Object Relationships:
═══════════════════════════════════════════════════════

Main Thread Stack:
┌─────────────────────────────────┐
│ pthread_t thread1               │──┐
│ pthread_t thread2               │──┼──┐
│ pthread_t thread3               │──┼──┼──┐
│                                 │  │  │  │
│ pthread_mutex_t shared_mutex    │◄─┼──┼──┼───┐
└─────────────────────────────────┘  │  │  │   │
                                     │  │  │   │
                                     │  │  │   │
Heap (Thread 1 data):                │  │  │   │
┌─────────────────────────────────┐  │  │  │   │
│ struct thread_data              │  │  │  │   │
│ ┌─────────────────────────────┐ │  │  │  │   │
│ │ mutex ──────────────────────┼─┼──┘  │  │   │
│ │ wait_to_obtain_ms: 50       │ │     │  │   │
│ │ wait_to_release_ms: 100     │ │     │  │   │
│ │ thread_complete_success: T  │ │     │  │   │
│ └─────────────────────────────┘ │     │  │   │
└─────────────────────────────────┘     │  │   │
                                        │  │   │
Heap (Thread 2 data):                   │  │   │
┌─────────────────────────────────┐     │  │   │
│ struct thread_data              │     │  │   │
│ ┌─────────────────────────────┐ │     │  │   │
│ │ mutex ──────────────────────┼─┼─────┘  │   │
│ │ wait_to_obtain_ms: 20       │ │        │   │
│ │ wait_to_release_ms: 150     │ │        │   │
│ │ thread_complete_success: T  │ │        │   │
│ └─────────────────────────────┘ │        │   │
└─────────────────────────────────┘        │   │
                                           │   │
Heap (Thread 3 data):                      │   │
┌─────────────────────────────────┐        │   │
│ struct thread_data              │        │   │
│ ┌─────────────────────────────┐ │        │   │
│ │ mutex ──────────────────────┼─┼────────┘   │
│ │ wait_to_obtain_ms: 80       │ │            │
│ │ wait_to_release_ms: 50      │ │            │
│ │ thread_complete_success: T  │ │            │
│ └─────────────────────────────┘ │            │
└─────────────────────────────────┘            │
                                               │
┌──────────────────────────────────────────────┘
│
▼
Shared Mutex Object:
┌─────────────────────────────────┐
│ pthread_mutex_t shared_mutex    │
│ ┌─────────────────────────────┐ │
│ │ State: Locked/Unlocked      │ │
│ │ Owner: Thread ID            │ │
│ │ Wait Queue: [...threads...] │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
       ↑
       └─── All threads reference this ONE mutex
```

---

## 6. Testing and Usage

### **Example Test Code**

```c
#include "threading.h"
#include <stdio.h>
#include <stdlib.h>

int main() {
    pthread_t thread1, thread2, thread3;
    pthread_mutex_t mutex;
    
    // Initialize mutex
    pthread_mutex_init(&mutex, NULL);
    
    // Create 3 threads with different timings
    printf("Creating threads...\n");
    
    bool success1 = start_thread_obtaining_mutex(&thread1, &mutex, 50, 100);
    bool success2 = start_thread_obtaining_mutex(&thread2, &mutex, 20, 150);
    bool success3 = start_thread_obtaining_mutex(&thread3, &mutex, 80, 50);
    
    if (!success1 || !success2 || !success3) {
        fprintf(stderr, "Failed to create one or more threads\n");
        return 1;
    }
    
    printf("All threads created, waiting for completion...\n");
    
    // Wait for all threads to complete
    struct thread_data *result1, *result2, *result3;
    
    pthread_join(thread1, (void **)&result1);
    pthread_join(thread2, (void **)&result2);
    pthread_join(thread3, (void **)&result3);
    
    // Check results
    printf("\nResults:\n");
    printf("Thread 1: %s\n", result1->thread_complete_success ? "SUCCESS" : "FAILED");
    printf("Thread 2: %s\n", result2->thread_complete_success ? "SUCCESS" : "FAILED");
    printf("Thread 3: %s\n", result3->thread_complete_success ? "SUCCESS" : "FAILED");
    
    // Cleanup
    free(result1);
    free(result2);
    free(result3);
    pthread_mutex_destroy(&mutex);
    
    printf("\nAll threads completed and cleaned up.\n");
    return 0;
}
```

### **Expected Output**

```
Creating threads...
All threads created, waiting for completion...

Results:
Thread 1: SUCCESS
Thread 2: SUCCESS
Thread 3: SUCCESS

All threads completed and cleaned up.
```

### **Common Issues and Solutions**

#### **Issue 1: Segmentation Fault**
```
Symptom: Program crashes with segfault
Cause: Accessing freed memory or NULL pointer
Solution: 
  - Check malloc() return value
  - Don't free memory before thread uses it
  - Use valgrind to detect memory errors
```

#### **Issue 2: Deadlock**
```
Symptom: Program hangs, threads never complete
Cause: Thread tries to lock already-locked mutex (by itself)
Solution:
  - Never call pthread_mutex_lock() twice without unlock
  - Use pthread_mutex_trylock() for non-blocking attempts
  - Always unlock in same function that locked
```

#### **Issue 3: Memory Leak**
```
Symptom: Memory usage grows over time
Cause: Not freeing thread_data after pthread_join()
Solution:
  - Always save pthread_join() result
  - Free the result after checking it
  - Use valgrind to detect leaks
```

#### **Issue 4: Race Condition**
```
Symptom: Inconsistent behavior, occasional failures
Cause: Multiple threads accessing shared data without mutex
Solution:
  - Protect ALL shared data with mutex
  - Lock before read/write, unlock after
  - Keep critical sections short
```

### **Debugging Tools**

#### **Valgrind Memory Check:**
```bash
valgrind --leak-check=full ./threading_test
```

#### **Helgrind Thread Checker:**
```bash
valgrind --tool=helgrind ./threading_test
```

#### **GDB Thread Debugging:**
```bash
gdb ./threading_test
(gdb) break threadfunc
(gdb) run
(gdb) info threads      # Show all threads
(gdb) thread 2          # Switch to thread 2
(gdb) backtrace         # Show thread's call stack
```

---

## 7. Key Takeaways

### **Critical Concepts**

1. **Mutexes Provide Mutual Exclusion**
   - Only ONE thread can hold a mutex at a time
   - Other threads wait (block) until mutex is released
   - Essential for protecting shared resources

2. **Dynamic Memory for Thread Data**
   - Use `malloc()` to allocate thread parameters
   - Memory must outlive the function that creates thread
   - Caller (after `pthread_join()`) is responsible for `free()`

3. **Error Handling is Critical**
   - Always check return values (`malloc()`, `pthread_create()`, `pthread_mutex_lock()`)
   - Clean up resources on failure
   - Set status flags to indicate success/failure

4. **Thread Synchronization Pattern**
   - Wait → Lock → Critical Section → Unlock
   - This pattern is fundamental to concurrent programming
   - Used in databases, operating systems, network servers

5. **Memory Ownership Transfer**
   - Creator allocates
   - Worker uses
   - Joiner frees
   - Clear ownership prevents leaks

---

## 8. Real-World Applications

### **Where This Pattern Is Used:**

1. **Database Systems**
   ```c
   // Transaction locks
   lock(database_mutex);
   update_account_balance(account, amount);
   unlock(database_mutex);
   ```

2. **Web Servers**
   ```c
   // Request handling
   lock(log_file_mutex);
   write_log_entry(request_info);
   unlock(log_file_mutex);
   ```

3. **Operating Systems**
   ```c
   // Process scheduler
   lock(ready_queue_mutex);
   add_process_to_queue(process);
   unlock(ready_queue_mutex);
   ```

4. **Game Engines**
   ```c
   // Physics simulation
   lock(world_state_mutex);
   update_object_positions();
   unlock(world_state_mutex);
   ```

---

## Conclusion

This implementation demonstrates fundamental concurrent programming concepts:
- Thread creation and management
- Mutex-based synchronization
- Dynamic memory management in multithreaded contexts
- Error handling in concurrent systems

These skills are essential for developing robust, scalable multithreaded applications! 🚀

---

**Author:** Implementation completed for AESD Assignment 4
**Date:** December 2025
**Language:** C (POSIX Threads)
