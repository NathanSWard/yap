from .parser import Parsable, ParserValue, Parser
from builtin.variadics import VariadicOf, Variadic


struct _TraitTuple[
    trait_type: __type_of(AnyType & Movable & Copyable), *values: trait_type
](Movable & Copyable):
    alias _mlir_type = __mlir_type[
        `!kgen.pack<:`,
        VariadicOf[trait_type],
        values,
        `>`,
    ]
    var storage: Self._mlir_type

    @always_inline("nodebug")
    fn __init__(out self, var *args: *values):
        self = Self(storage=args^)

    @always_inline("nodebug")
    fn __init__[
        *movable: Movable
    ](out self, *, var storage: VariadicPack[_, _, trait_type, *values],):
        # Mark 'self.storage' as being initialized so we can work on it.
        __mlir_op.`lit.ownership.mark_initialized`(
            __get_mvalue_as_litref(self.storage)
        )

        # Move each element into the tuple storage.
        @parameter
        fn init_elt[idx: Int](var elt: values[idx]):
            UnsafePointer(to=self[idx]).init_pointee_move(elt^)

        storage^.consume_elements[init_elt]()

    fn __del__(deinit self):
        @parameter
        for i in range(Self.__len__()):
            UnsafePointer(to=self[i]).destroy_pointee()

    @always_inline("nodebug")
    fn __copyinit__(out self, existing: Self):
        # Mark 'storage' as being initialized so we can work on it.
        __mlir_op.`lit.ownership.mark_initialized`(
            __get_mvalue_as_litref(self.storage)
        )

        @parameter
        for i in range(Self.__len__()):
            UnsafePointer(to=self[i]).init_pointee_copy(existing[i])

    @always_inline
    fn copy(self) -> Self:
        return self

    @always_inline("nodebug")
    fn __moveinit__(out self, deinit existing: Self):
        # Mark 'storage' as being initialized so we can work on it.
        __mlir_op.`lit.ownership.mark_initialized`(
            __get_mvalue_as_litref(self.storage)
        )

        @parameter
        for i in range(Self.__len__()):
            UnsafePointer(to=existing[i]).move_pointee_into(
                UnsafePointer(to=self[i])
            )
        # Note: The destructor on `existing` is auto-disabled in a moveinit.

    @always_inline
    @staticmethod
    fn __len__() -> Int:
        @parameter
        fn variadic_size(x: VariadicOf[trait_type]) -> Int:
            return __mlir_op.`pop.variadic.size`(x)

        alias result = variadic_size(values)
        return result

    @always_inline("nodebug")
    fn __len__(self) -> Int:
        return Self.__len__()

    @always_inline("nodebug")
    fn __getitem__[idx: Int](ref self) -> ref [self] values[idx.value]:
        # Return a reference to an element at the specified index, propagating
        # mutability of self.
        var storage_kgen_ptr = UnsafePointer(to=self.storage).address

        # KGenPointer to the element.
        var elt_kgen_ptr = __mlir_op.`kgen.pack.gep`[index = idx.value](
            storage_kgen_ptr
        )
        # Use an immortal mut reference, which converts to self's origin.
        return UnsafePointer(elt_kgen_ptr)[]
