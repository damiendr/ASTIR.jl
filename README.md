# ASTIR

*Work In Progress, not useable yet!*

ASTIR helps you write tools that translate Julia functions to other languages at runtime, using Julia's typed syntax trees (**AST**) as an intermediate representation (**IR**) of the function code.

Translating ASTs rather than top-level Julia source enables call-site translation of generic Julia functions and lets Julia's dispatch system do all the work of resolving methods.

Starting from *typed* ASTs brings two further advantages. The first advantage is that the types of arguments and local variables are already resolved: no need to re-implement type inference when translating to statically-typed languages. The second is that inlineable function calls inside the function to translate will already be inlined; this is a particularly cheap way to support user-defined functions inside the code to translate.

However starting from typed ASTs also presents a number of challenges. The IR can be a bit hairy at times. It contains Julia-specific constructs that one may want to remove (eg. boxing of native types). More importantly, control flow in the IR is goto-based; when translating to a language that does not support gotos, some sort of structured control flow must be recovered.

This tool provides both a convenient way to trigger the translation at runtime, and a set of transformations that normalise the IR and make it easier to translate.

A word of caution: Julia's IR is still changing rapidly and is not an official API. This means that this tool may break even after minor updates of Julia, and it is not guaranteed that the fix will always be easy (or even possible, for that matter).