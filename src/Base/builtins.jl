const BUILTINS = Set([
    # consts
    :True,
    :False,
    :NotImplemented,
    :None,
    :Ellipsis,
    # classes/functions
    :abs,
    :all,
    :any,
    :ascii,
    :bin,
    :bool,
    :bytes,
    :bytearray,
    :callable,
    :chr,
    :classmethod,
    :compile,
    :complex,
    :delattr,
    :dict,
    :dir,
    :divmod,
    :enumerate,
    :eval,
    :exec,
    :filter,
    :float,
    :format,
    :frozenset,
    :getattr,
    :globals,
    :hasattr,
    :hash,
    :help,
    :hex,
    :id,
    :input,
    :int,
    :isinstance,
    :issubclass,
    :iter,
    :len,
    :list,
    :locals,
    :map,
    :max,
    :memoryview,
    :min,
    :next,
    :object,
    :oct,
    :open,
    :ord,
    :pow,
    :print,
    :property,
    :range,
    :repr,
    :reversed,
    :round,
    :set,
    :setattr,
    :slice,
    :sorted,
    :staticmethod,
    :str,
    :sum,
    :super,
    :tuple,
    :type,
    :vars,
    :zip,
    # exceptions
    :BaseException,
    :Exception,
    :StopIteration,
    :GeneratorExit,
    :ArithmeticError,
    :LookupError,
    :AssertionError,
    :AttributeError,
    :BufferError,
    :EOFError,
    :FloatingPointError,
    :OSError,
    :ImportError,
    :IndexError,
    :KeyError,
    :KeyboardInterrupt,
    :MemoryError,
    :NameError,
    :OverflowError,
    :RuntimeError,
    :RecursionError,
    :NotImplementedError,
    :SyntaxError,
    :IndentationError,
    :TabError,
    :ReferenceError,
    :SystemError,
    :SystemExit,
    :TypeError,
    :UnboundLocalError,
    :UnicodeError,
    :UnicodeEncodeError,
    :UnicodeDecodeError,
    :UnicodeTranslateError,
    :ValueError,
    :ZeroDivisionError,
    :BlockingIOError,
    :BrokenPipeError,
    :ChildProcessError,
    :ConnectionError,
    :ConnectionAbortedError,
    :ConnectionRefusedError,
    :FileExistsError,
    :FileNotFoundError,
    :InterruptedError,
    :IsADirectoryError,
    :NotADirectoryError,
    :PermissionError,
    :ProcessLookupError,
    :TimeoutError,
    :EnvironmentError,
    :IOError,
    :Warning,
    :UserWarning,
    :DeprecationWarning,
    :PendingDeprecationWarning,
    :SyntaxWarning,
    :RuntimeWarning,
    :FutureWarning,
    :ImportWarning,
    :UnicodeWarning,
    :BytesWarning,
    :ResourceWarning,
])

@eval baremodule pybuiltins
    $([:(const $k = $pynew()) for k in BUILTINS]...)
end
"""
    pybuiltins

An object whose fields are the Python builtins, of type [`Py`](@ref).

For example `pybuiltins.None`, `pybuiltins.int`, `pybuiltins.ValueError`.
"""
pybuiltins
export pybuiltins

@eval function init_pybuiltins()
    b = pyimport("builtins")
    $([
        if k == :help
            # help is only available in interactive contexts (imported by the 'site' module)
            # see: https://docs.python.org/3/library/functions.html#help
            # see: https://github.com/cjdoris/PythonCall.jl/issues/248
            :(pycopy!(pybuiltins.$k, pygetattr(b, $(string(k)), pybuiltins.None)))
        else
            :(pycopy!(pybuiltins.$k, pygetattr(b, $(string(k)))))
        end
        for k in BUILTINS
    ]...)
    return
end
