# Throwing and catching exceptions with PIT

After having defined a message of severity `ERROR` or `FATAL`, package `MSG` has defined a respective message, an exception and an exception init for the given Oracle error number. If no Oracle error number has been provided, PIT automatically assigns a custom error number within the range `-20,999 .. -20,000`. Let's have a look at how we can work with these errors in PIT.

## Throwing errors

To throw an error, there are two different ways with specific advantages.

### Throwing errors using `raise`

When using the `raise` command, it's very easy to throw an error: 

```
begin
  ... some work
  raise msg.MY_MESSAGE_ERR;
exception
 when msg.MY_MESSAGE_ERR then
   ... do something
end;
```

The advantage of this way to throw errors is that it's very common for many programmers to throw errors like this. After catching the error, you reference a message and pass any optional parameters in as you see fit. We'll look at catching and processing error later.

The disadvantage is that you don't have control over the message that will be logged. Imagine a situation where the same error may occur at several positions within your code. Based on where it is thrown, the parameteres to add to the message may vary. In these situations it may be helpful to be able to create the message right where the error occurs, including the parameters you have right then. This is why a second way to throw errors exists.

### Throwing errors using `pit.error` or `pit.fatal`

The idea is to create a message of severity error and have it throw the exception for you. Because we create a message rather than throwing an exception we now have the option to pass in any arguments we need. To achieve this, we pass in the message name and parameters as with any other message logging. As you recall, every message has got a matching exception, if severity demands for it. This is now used to throw the error based on the message you just created. Review the following code snippet:

```
begin
  ... some work
  pit.error(msg.MY_MESSAGE, mgs_args('row', to_char(id)));
exception
 when msg.MY_MESSAGE_ERR then
   ... do something
end;
```

The code to catch the exception is the same, although the way to process the error with PIT is different. Before we come to that, I'd like to stress that after throwing an exception with `pit.error` or `pit.fatal`, `SQLCODE` and `SQLERRM` are populated with the message you created when throwing the error. `SQLCODE` contains the Oracle error number or the custom error number assigned to the message. Therefore, to use this feature, make sure that the message has a severity of `level_error` or `level_fatal` to have PIT assign a custom error number to it. In general, `pit.error` and `pit.fatal` overwrite the message's severity with the respective method level to assure that a message of severity `level_error` will stop further execution of the code if it has been thrown by `pit.fatal`.

## Catching exceptions with PIT

Let's see how to catch exceptions with PIT and the options we have here.

There are two specialized methods to handle exceptions within PIT: `pit.sql_exception` and `pit.stop`. I have to admit that the latter was the reason to call the whole package PIT ...

Method `pit.sql_exception` is intended to be used as a exception handler for `pit.error` or `raise`. By catching the exception with this method, it gets passed to all output modules and after that the code will continue. You may or may not define a message to be passed with this method, but normally, when used with `raise` the matching message for the exception caught may make most sense, as in the following example:

```
begin
  ... some work
  raise msg.MY_MESSAGE_ERR;
exception
 when msg.MY_MESSAGE_ERR then
   pit.sql_exception(msg.MY_MESSAGE, msg_args('row', to_char(id)));
end;
```

Method `pit.stop`, on the other hand, is ideal for working in conjunction with `pit.fatal` or `raise`. The difference to `pit.sql_exception` is that `pit.stop` will throw an exception after it has logged the original exception. The thrown exception may be just the one that was passed in or any other message you see fit.

### Passing predefined messages to PIT
If you threw the excpetion with `pit.error` or `pit.fatal`, the messages have been created already. Therefore you don't want the message to be overwritten by a new message in `pit.sql_exception` or `pit.stop` respectively. To achieve this, there is predefined message called `pit.PASS_MESSAGE` that gets thrown if you call the methods without parameters. If you do so, the already existing message (which is stored in the backtrace) will be used for logging, allowing for individual parameters throughout the code.

If you review the next code sample, you will get the idea of how it works immediately:

```
begin
  ... some work
  pit.error(msg.MY_MESSAGE, mgs_args('row', to_char(id)));
exception
 when msg.MY_MESSAGE_ERR then
   pit.sql_exception;
   -- or: pit.stop;
end;
```

Use this approach if you need to differ between many places the same error may occur, if the respecitive parameters have lost focus in the excpetion block or simply if you feel more comfortable with directly creating the error message where it occurs.

## Catching named Oracle errors
If you want to catch named Oracle errors such as `NO_DATA_FOUND` or `TOO_MANY_ROWS`, the way to catch them stays the same as without PIT. The only additional possibility you have is to process the exception with any custom defined message you see fit. Here's a code snippet that shows this usage:

```
begin
  ... some work
exception
 when NO_DATA_FOUND then
   pit.sql_exception(msg.MY_MESSAGE, mgs_args('row', to_char(id)));
end;
```

## Throwing errors with `pit.log_special`

Throwing errors with this method is possible, but not it's intended use. This method is used to overwrite log settings for a specific message. It's useful to make sure that certain messages always get logged. They were included in PIT after the demand came up to reuse the message capabilites beyond the boundaries of normal error logging. One example is a Finite State Machine I needed. This pattern had to log all status changes into a log table, including errors, reagrdless of any log settings. So the log entries for this machine were created using PIT, but aside the normal logging flow.

Do not use it for normal logging. 

## Overview of possibilities to throw and catch exceptions in PIT
Here is a brief overview of the different possibilities of throwing and catching exceptions with PIT. It is assumed that the respective messages were created upfront with a severity of 20 or 30 and a matching Oracle error number, if applicable. Catching exceptions with `pit.sql_exception` or `pit.stop` is identical syntaxwise. The only difference is that `pit.stop` will throw the error after logging it, whereas `pit.sql_exception` will not.

### Catching Oracle named exceptions
```
begin
  <do something that causes Oracle to throw a named exception>
exception
  when NO_DATA_FOUND then
    pit.sql_exception(msg.NO_ITEMS_IN_STOCK, msg_args(...));
end;
```

### Catching Oracle non-named exceptions
```
begin
  <do something that causes Oracle to throw a non-named exception>
exception
  when msg.CHILD_RECORD_FOUND_ERR then
    pit.sql_exception(msg.CHILD_RECORD_FOUND, msg_args(...));
end;
```

### Catching user defined exceptions, option 1
```
begin
  <do something>
  raise msg.PARAM_OUT_OF_RANGE_ERR
exception
  when msg.PARAM_OUT_OF_RANGE_ERR then
    pit.sql_exception(msg.PARAM_OUT_OF_RANGE, msg_args(...));
end;
```

### Catching user defined exceptions, option 2
```
begin
  <do something>
  pit.error(msg.PARAM_OUT_OF_RANGE, msg_args(...));
exception
  when msg.PARAM_OUT_OF_RANGE_ERR then
    pit.sql_exception;
end;
```

### Throwing exceptions with `pit.assert` and predefined messages
```
begin
  pit.assert(p_param_1 in (10, 20, 30));
  pit.assert_not_null(p_param_2);
  <do something>
exception
  when msg.ASSERT_TRUE_ERR then
    pit.stop(msg.PARAM_OUT_OF_RANGE, msg_args('P_PARAM1', to_char(p_param_1)));
  when msg.ASSERT_IS_NOT_NULL_ERR then
    pit.sql_exception(msg.PARAM_MUST_EXIST, msg_args('P_PARAM_2'));
end;
```

### Throwing exceptions with `pit.assert` and custom messages, option 1
```
begin
  pit.assert(
    p_condition => p_param_1 in (10, 20, 30), 
    p_message_name => msg.PARAM_OUT_OF_RANGE, 
    p_arg_list => msg_args('P_PARAM_1', to_char(p_param_1)));
  pit.assert_not_null(
    p_condition => p_param_2, 
    p_message_name => msg.PARAM_MUST_EXIST, 
    p_arg_list => msg_args('P_PARAM_2'));
  <do something>
exception
  when msg.ASSERT_TRUE_ERR then
    pit.stop;
  when msg.ASSERT_IS_NOT_NULL_ERR then
    pit.sql_exception;
end;
```

### Throwing exceptions with `pit.assert` and custom messages, option 2
```
begin
  pit.assert(p_param_1 in (10, 20, 30), msg.PARAM_OUT_OF_RANGE);
  pit.assert_not_null(p_param_2, msg.PARAM_MUST_EXIST);
  <do something>
exception
  when msg.PARAM_OUT_OF_RANGE_ERR then
    pit.stop(msg.PARAM_OUT_OF_RANGE, msg_args('P_PARAM1', to_char(p_param_1)));
  when msg.PARAM_MUST_EXIST_ERR then
    pit.sql_exception(msg.PARAM_MUST_EXIST, msg_args('P_PARAM_2'));
end;
```

### Throwing exceptions with `pit.log_specific`

This method is used if certain messages require a defined set of output modules and a given severity. This method logs in any case and may not be controled by a context if parameter `p_log_threshold` is set. If the severity of the message is `level_error` or `level_fatal`, it won't throw an error that is catchable in the exception block. It will simply log the exception and continue. Use it in special cases only. 

```
begin
  pit.log_specific(
    p_message_name => msg.FSM_STATUS_CHANGED, 
    p_arg_list => msg_args(fst.DOC_PROCESS_FAILED),
    p_affected_id => fsm.fsm_id,
    p_log_threshold => pit.level_verbose,
    p_log_modules => 'PIT_FSM');
end;
```