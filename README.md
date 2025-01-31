# To get started:
```zig
// Import the library
const hooking = @import("trampoline");
```

```zig
// Initialize the library at runtime
hooking.init(allocator);
```

```zig
// Hook a function
original_func = @ptrCast(hooking.trampoline_hook(&func_to_hook, &hook_to_run, 5));
// If you're unsure what 5 means here, you should probably research what a trampoline hook is.
// Or don't. I don't care. Trial and error has a 10% success rate here.
```

```zig
// Release all hooks
hooking.deinit();
```

[main.zig](src/main.zig) contains an example
