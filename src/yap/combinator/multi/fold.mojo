from yap.parser import *
from yap.error import *
from yap.combinator.multi import Range


trait FoldInitializable(Copyable & Movable):
    """TODO."""

    alias InitialType: Copyable & Movable
    """TODO."""

    fn initial(self) -> Self.InitialType:
        """TODO."""
        ...


struct FoldInitialValue[T: Movable & Copyable](
    Movable & Copyable & FoldInitializable
):
    """TODO."""

    alias InitialType = T

    var value: T
    """TODO."""

    @implicit
    fn __init__(out self, var value: T):
        """TODO."""
        self.value = value^

    fn initial(self) -> Self.InitialType:
        return self.value.copy()


@fieldwise_init
@register_passable("trivial")
struct FoldInitialValueFn[T: Movable & Copyable, init: fn () capturing -> T](
    Movable & Copyable & FoldInitializable
):
    """TODO."""

    alias InitialType = T

    fn initial(self) -> Self.InitialType:
        return init()


fn _fold_0[
    ParserType: Parsable,
    OutputType: ParserValue, //,
    func: fn (var OutputType, var ParserType.Output) capturing -> OutputType,
](parser: ParserType, var init: OutputType, input: ParserInput) -> ParseResult[
    OutputType
]:
    var input_to_parse = input

    while True:
        var result = parser.parse(input_to_parse)
        if result:
            var (output, next_input) = result.ok()
            input_to_parse = rebind[__type_of(input_to_parse)](next_input)
            init = func(init^, output^)
        elif result is ErrKind.BACKTRACK:
            return (init^, input_to_parse)
        else:
            return result.err()


fn _fold_min[
    ParserType: Parsable,
    OutputType: ParserValue, //,
    func: fn (var OutputType, var ParserType.Output) capturing -> OutputType,
    min: UInt,
](parser: ParserType, var init: OutputType, input: ParserInput) -> ParseResult[
    OutputType
]:
    var input_to_parse = input

    @parameter
    for _ in range(0, min):
        var result = parser.parse(input_to_parse)
        if result:
            var (output, next_input) = result.ok()
            input_to_parse = rebind[__type_of(input_to_parse)](next_input)
            init = func(init^, output^)
        else:
            return result.err()

    return _fold_0[func](parser, init^, input_to_parse)


fn _fold_min_max[
    ParserType: Parsable,
    OutputType: ParserValue, //,
    func: fn (var OutputType, var ParserType.Output) capturing -> OutputType,
    min: UInt,
    max: UInt,
](parser: ParserType, var init: OutputType, input: ParserInput) -> ParseResult[
    OutputType
]:
    alias result_type = ParseResult[OutputType]

    var input_to_parse = input

    @parameter
    for _ in range(0, min):
        var result = parser.parse(input_to_parse)
        if result:
            var (output, next_input) = result.ok()
            input_to_parse = rebind[__type_of(input_to_parse)](next_input)
            init = func(init^, output^)
        else:
            return result_type(result.err())

    @parameter
    for _ in range(min, max):
        var result = parser.parse(input_to_parse)
        if result:
            var (output, next_input) = result.ok()
            input_to_parse = rebind[__type_of(input_to_parse)](next_input)
            init = func(init^, output^)
        elif result is ErrKind.CUT:
            return result_type(result.err())

    return result_type((init^, input_to_parse))


@fieldwise_init
struct Fold[
    ParserType: Parsable,
    OutputType: ParserValue, //,
    InitialType: FoldInitializable,
    range: Range,
    func: fn (var OutputType, var ParserType.Output) capturing -> OutputType,
](Copyable & Movable & Parsable):
    """A parser implementation for `fold`."""

    alias Output = OutputType

    var _parser: ParserType
    var _init: InitialType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias min = range.min
        alias max = range.max.or_else(UInt.MAX)
        constrained[
            min < max and max != 0,
            "Fold requires min < max and max != 0",
        ]()

        var init = rebind[Self.Output](self._init.initial())

        @parameter
        if min == 0 and not range.max:
            return _fold_0[func](self._parser, init^, input)
        elif min > 0 and not range.max:
            return _fold_min[func, min](self._parser, init^, input)
        else:
            return _fold_min_max[func, min, max](self._parser, init^, input)


fn fold[
    ParserType: Parsable,
    OutputType: ParserValue, //,
    /,
    range: Range,
    folder: fn (var OutputType, var ParserType.Output) capturing -> OutputType,
](parser: ParserType, *, var init: OutputType) -> Parser[
    Fold[FoldInitialValue[OutputType], range, folder]
]:
    """TODO."""

    return Parser(
        Fold[
            FoldInitialValue[OutputType],
            range,
            folder,
        ](parser, init^)
    )


fn fold[
    ParserType: Parsable,
    OutputType: ParserValue, //,
    /,
    range: Range,
    folder: fn (var OutputType, var ParserType.Output) capturing -> OutputType,
    *,
    init: fn () capturing -> OutputType,
](parser: ParserType) -> Parser[
    Fold[
        FoldInitialValueFn[OutputType, init],
        range,
        folder,
    ]
]:
    """TODO."""

    return Parser(
        Fold[
            FoldInitialValueFn[OutputType, init],
            range,
            folder,
        ](parser, FoldInitialValueFn[OutputType, init]())
    )
