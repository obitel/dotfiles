# -*- ksh -*-
# Originally from Todd, see email to dev-komodo in Feb 2009.

define cls
    shell clear
end
document cls
    Clears the screen with a simple command.
end

# http://blog.kowalczyk.info/article/Gdb-basics.html
define pu
  set $uni = $arg0 
  set $i = 0
  while (*$uni && $i++<100)
    if (*$uni < 0x80) 
      print *(char*)$uni++
    else
      print /x *(short*)$uni++
    end
  end
end
document pu
    Prints a unicode string from the given string address.
end

#
#
# If you use the GNU debugger gdb to debug the Python C runtime, you
# might find some of the following commands useful.  Copy this to your
# ~/.gdbinit file and it'll get loaded into gdb automatically when you
# start it up.  Then, at the gdb prompt you can do things like:
#
#    (gdb) pyo apyobjectptr
#    <module 'foobar' (built-in)>
#    refcounts: 1
#    address    : 84a7a2c
#    $1 = void
#    (gdb)

# Prints a representation of the object to stderr, along with the
# number of reference counts it current has and the hex address the
# object is allocated at.  The argument must be a PyObject*
define pyo
print _PyObject_Dump($arg0)
end

# Prints a representation of the object to stderr, along with the
# number of reference counts it current has and the hex address the
# object is allocated at.  The argument must be a PyGC_Head*
define pyg
print _PyGC_Dump($arg0)
end

# print the local variables of the current frame
define pylocals
    set $_i = 0
    while $_i < f->f_nlocals
    if f->f_localsplus + $_i != 0
        set $_names = co->co_varnames
        set $_name = PyString_AsString(PyTuple_GetItem($_names, $_i))
        printf "%s:\n", $_name
        # side effect of calling _PyObject_Dump is to dump the object's
        # info - assigning just prevents gdb from printing the
        # NULL return value
        set $_val = _PyObject_Dump(f->f_localsplus[$_i])
    end
        set $_i = $_i + 1
    end
end

# A rewrite of the Python interpreter's line number calculator in GDB's
# command language
define lineno
    set $__continue = 1
    set $__co = f->f_code
    set $__lasti = f->f_lasti
    set $__sz = ((PyStringObject *)$__co->co_lnotab)->ob_size/2
    set $__p = (unsigned char *)((PyStringObject *)$__co->co_lnotab)->ob_sval
    set $__li = $__co->co_firstlineno
    set $__ad = 0
    while ($__sz-1 >= 0 && $__continue)
      set $__sz = $__sz - 1
      set $__ad = $__ad + *$__p
      set $__p = $__p + 1
      if ($__ad > $__lasti)
        set $__continue = 0
      else
        set $__li = $__li + *$__p
        set $__p = $__p + 1
      end
    end
    printf "%d", $__li
end

# print the current frame - verbose
define pyframev
    pyframe
    pylocals
end

define pyframe
    set $__fn = (char *)((PyStringObject *)co->co_filename)->ob_sval
    set $__n = (char *)((PyStringObject *)co->co_name)->ob_sval
    printf "%s (", $__fn
    lineno
    printf "): %s\n", $__n
### Uncomment these lines when using from within Emacs/XEmacs so it will
### automatically track/display the current Python source line
#    printf "%c%c%s:", 032, 032, $__fn
#    lineno
#    printf ":1\n"
end

### Use these at your own risk.  It appears that a bug in gdb causes it
### to crash in certain circumstances.

#define up
#    up-silently 1
#    printframe
#end

#define down
#    down-silently 1
#    printframe
#end

define printframe
    if $pc > PyEval_EvalFrameEx && $pc < PyEval_EvalCodeEx
        pyframe
    else
        frame
    end
end

# Here's a somewhat fragile way to print the entire Python stack from gdb.
# It's fragile because the tests for the value of $pc depend on the layout
# of specific functions in the C source code.

# Explanation of while and if tests: We want to pop up the stack until we
# land in Py_Main (this is probably an incorrect assumption in an embedded
# interpreter, but the test can be extended by an interested party).  If
# Py_Main <= $pc <= Py_GetArgcArv is true, $pc is in Py_Main(), so the while
# tests succeeds as long as it's not true.  In a similar fashion the if
# statement tests to see if we are in PyEval_EvalFrame().

# print the entire Python call stack
define pystack
    select-frame 1
    set $stack_count = 0
    while $pc < XRE_main
        if $pc >= PyEval_EvalCodeEx && $pc < (PyEval_EvalCodeEx + 10000)
            pyframe
        end
        up-silently 1
        set $stack_count = $stack_count + 1
    end
    select-frame 0
end

# print the entire Python call stack - verbose mode
define pystackv
    # while $pc < Py_Main || $pc > Py_GetArgcArgv
    set $stack_count = 0
    while $stack_count < 150
        if $pc > PyEval_EvalFrame && $pc < PyEval_EvalCodeEx
        pyframev
        end
        up-silently 1
        set $stack_count = $stack_count + 1
    end
    select-frame 0
end

