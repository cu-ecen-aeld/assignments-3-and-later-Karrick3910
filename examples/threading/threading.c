#include "threading.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

// Optional: use these functions to add debug or error prints to your application
#define DEBUG_LOG(msg,...)
//#define DEBUG_LOG(msg,...) printf("threading: " msg "\n" , ##__VA_ARGS__)
#define ERROR_LOG(msg,...) printf("threading ERROR: " msg "\n" , ##__VA_ARGS__)

void* threadfunc(void* thread_param)
{

    // TODO: wait, obtain mutex, wait, release mutex as described by thread_data structure
    // hint: use a cast like the one below to obtain thread arguments from your parameter
    struct thread_data* thread_func_args = (struct thread_data *) thread_param;
    
    // Initialize thread_complete_success to false
    thread_func_args->thread_complete_success = false;
    
    // Step 1: Wait before attempting to obtain the mutex
    // Convert milliseconds to microseconds for usleep()
    usleep(thread_func_args->wait_to_obtain_ms * 1000);
    
    // Step 2: Obtain (lock) the mutex
    int rc = pthread_mutex_lock(thread_func_args->mutex);
    if (rc != 0) 
    {
        ERROR_LOG("Failed to lock mutex, error code: %d", rc);
        return thread_param;
    }
    
    // Step 3: Wait while holding the mutex
    usleep(thread_func_args->wait_to_release_ms * 1000);
    
    // Step 4: Release (unlock) the mutex
    rc = pthread_mutex_unlock(thread_func_args->mutex);
    if (rc != 0) 
    {
        ERROR_LOG("Failed to unlock mutex, error code: %d", rc);
        return thread_param;
    }
    
    // Mark thread as successfully completed
    thread_func_args->thread_complete_success = true;
    
    return thread_param;
}


bool start_thread_obtaining_mutex(pthread_t *thread, pthread_mutex_t *mutex,int wait_to_obtain_ms, int wait_to_release_ms)
{
    /**
     * TODO: allocate memory for thread_data, setup mutex and wait arguments, pass thread_data to created thread
     * using threadfunc() as entry point.
     *
     * return true if successful.
     *
     * See implementation details in threading.h file comment block
     */
    
    // Step 1: Dynamically allocate memory for thread_data structure
    struct thread_data *data = (struct thread_data *)malloc(sizeof(struct thread_data));
    if (data == NULL) 
    {
        ERROR_LOG("Failed to allocate memory for thread_data");
        return false;
    }
    
    // Step 2: Initialize the thread_data structure with parameters
    data->mutex = mutex;
    data->wait_to_obtain_ms = wait_to_obtain_ms;
    data->wait_to_release_ms = wait_to_release_ms;
    data->thread_complete_success = false;
    
    // Step 3: Create the thread with threadfunc as entry point
    int rc = pthread_create(thread, NULL, threadfunc, (void *)data);
    if (rc != 0) 
    {
        ERROR_LOG("Failed to create thread, error code: %d", rc);
        free(data);  // Clean up allocated memory on failure
        return false;
    }
    
    // Thread created successfully
    return true;
}

