struct Range(Copyable & Movable):
    """An inclusively bounded range for counting parses performed."""

    var min: UInt
    var max: Optional[UInt]

    fn __init__(out self, *, exactly: UInt):
        """A range of exactly `n`. This is the same as `Range(min=n, max=n)`."""

        self.min = exactly
        self.max = exactly

    fn __init__(out self, *, min: UInt):
        """A range of at least `min` with no upper bound."""

        self.min = min
        self.max = None

    fn __init__(out self, *, min: UInt, max: UInt):
        """A range of `min..=max` (inclusive)."""

        self.min = min
        self.max = max


trait Collectable(Copyable & Movable):
    """A type that can collect outputs of a parser applied multiple times."""

    alias Element: Copyable & Movable
    """The collected paser output type."""

    fn __init__(out self):
        """Default initialize self."""
        ...

    fn __init__(out self, *, capacity: Int):
        """Initialize self with the given capacity."""
        ...

    fn append(mut self, var element: Self.Element):
        """Append `element` to self."""
        ...


struct ListCollecter[T: Copyable & Movable](Copyable & Movable & Collectable):
    """A `Collectable` that collects the parser outputs into a `List`."""

    alias Element = T

    var list: List[T]
    """The list of collected parser elements."""

    fn __init__(out self):
        self.list = List[T]()

    fn __init__(out self, *, capacity: Int):
        self.list = List[T](capacity=capacity)

    fn append(mut self, var element: Self.Element):
        self.list.append(element^)


@fieldwise_init
@register_passable("trivial")
struct NoneElement(Copyable & Movable):
    @implicit
    fn __init__[T: AnyType, //](out self, _ignored: T):
        pass


@register_passable("trivial")
struct NoneCollecter(Copyable & Movable & Collectable):
    """A `Collectable` which does not collect the parser outputs (a no-op)."""

    alias Element = NoneElement

    fn __init__(out self):
        pass

    fn __init__(out self, *, capacity: Int):
        pass

    fn append(mut self, var element: Self.Element):
        pass


fn _initialize_collecter[
    CollecterType: Collectable, min: UInt
]() -> CollecterType:
    @parameter
    if min > 0:
        return CollecterType(capacity=Int(min))
    else:
        return CollecterType()
