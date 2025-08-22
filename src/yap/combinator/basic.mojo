from yap.parser import *
from yap.tuple import *
from os.os import abort

# --- cond ---


@fieldwise_init
struct Cond[
    ParserType: Parsable,
](Movable & Copyable & Parsable):
    """A parser implementation for `map`."""

    alias Output = ParserType.Output

    var _cond: Bool
    var _parser: ParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]
        if self._cond:
            return self._parser.parse(input)
        else:
            return result_type(Err(input=input))


fn verify[
    ParserType: Parsable,
](cond: Bool, parser: ParserType) -> Parser[Cond[ParserType]]:
    """Runs the parser if the condition is `True`.

    Parameters:
        ParserType: The type of the parser.

    Args:
        cond: A `Bool` determining wheather to run the parser or not.
        parser: The parser which will be run if `cond` is `True`.

    Returns:
        A new `Cond` parser.
    """

    return Parser(Cond[ParserType](cond, parser))


# --- verify ---


@fieldwise_init
struct Verify[
    ParserType: Parsable,
    verifier: fn (ParserType.Output) -> Bool,
](Movable & Copyable & Parsable):
    """A parser implementation for `map`."""

    alias Output = ParserType.Output

    var _parser: ParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]

        var result = self._parser.parse(input)
        if result:
            var (output, next_input) = result.ok()
            if verifier(output):
                return result_type((output^, next_input))
            else:
                return result_type(Err(input=input))
        else:
            return result_type(result.err())


fn verify[
    ParserType: Parsable,
    verifier: fn (ParserType.Output) -> Bool,
](parser: ParserType) -> Parser[Verify[ParserType, verifier]]:
    """Returns the output of the parser if it satisfies a verification function.

    Parameters:
        ParserType: The type of the parser.
        verifier: The function used to verify the output.

    Args:
        parser: The parser whose output will be verified.

    Returns:
        A new `Verify` parser.
    """

    return Parser(Verify[ParserType, verifier](parser))


# --- and_then ---


@fieldwise_init
struct AndThen[
    FirstParserType: Parsable,
    SecondParserType: Parsable,
](Movable & Copyable & Parsable):
    """Parser implementation for `and_then`."""

    alias Output = SecondParserType.Output

    var _first: FirstParserType
    var _second: SecondParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]

        var first = self._first.parse(input)
        if first:
            var (output, next_input) = first.ok()
            var second = self._second.parse(
                rebind[StringSlice[ImmutableAnyOrigin]](output)
            )
            if second:
                var (output, _) = second.ok()
                return result_type((output^, next_input))
            else:
                return result_type(second.err())
        else:
            return result_type(first.err())


fn and_then[
    FirstParserType: Parsable,
    SecondParserType: Parsable, //,
](first: FirstParserType, second: SecondParserType) -> Parser[
    AndThen[FirstParserType, SecondParserType]
]:
    """Applies the second parser over the result of the first.

    Args:
        first: The first parser to parse the input.
        second: The second parser to parse the result of the first.

    Returns:
        A new `AndThen` parser.
    """

    return Parser(AndThen[FirstParserType, SecondParserType](first, second))


# --- try_map ---


@fieldwise_init
struct TryMap[
    ParserType: Parsable,
    MapperInputType: ParserValue,
    MapperOutputType: ParserValue,
    mapper: fn (var MapperInputType) raises -> MapperOutputType,
](Movable & Copyable & Parsable):
    """Parser implementation for `try_map`."""

    alias Output = MapperOutputType

    var _parser: ParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]

        var result = self._parser.parse(input)
        if result:
            var (output, next_input) = result.ok()
            try:
                return result_type(
                    (mapper(rebind[MapperInputType](output^)), next_input)
                )
            except:
                return result_type(Err(input=input))
        else:
            return result_type(result.err())


fn try_map[
    ParserType: Parsable,
    MapperInputType: ParserValue,
    MapperOutputType: ParserValue, //,
    mapper: fn (var MapperInputType) raises -> MapperOutputType,
](
    parser: ParserType,
) -> Parser[
    TryMap[ParserType, MapperInputType, MapperOutputType, mapper]
]:
    """Tries to map the output of the parser using the raising mapper function,
    returning an error if the mapper raises an exception.

    Parameters:
        ParserType: The type of the mapper parser.
        MapperInputType: The input type of the mapper.
        MapperOutputType: The new mapped output type.
        mapper: The raising function used to transform the output of the parser.

    Args:
        parser: The parser whose output will be try to be transformed.

    Returns:
        A new `TryMap` parser.
    """

    return Parser(
        TryMap[ParserType, MapperInputType, MapperOutputType, mapper](parser)
    )


# --- map ---


@fieldwise_init
struct Map[
    ParserType: Parsable,
    MapperInputType: ParserValue,
    MapperOutputType: ParserValue,
    mapper: fn (var MapperInputType) -> MapperOutputType,
](Movable & Copyable & Parsable):
    """A parser implementation for `map`."""

    alias Output = MapperOutputType

    var _parser: ParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]

        var result = self._parser.parse(input)
        if result:
            var (output, next_input) = result.ok()
            return result_type(
                (mapper(rebind[MapperInputType](output^)), next_input)
            )
        else:
            return result_type(result.err())


fn map[
    ParserType: Parsable,
    MapperInputType: ParserValue,
    MapperOutputType: ParserValue, //,
    mapper: fn (var MapperInputType) -> MapperOutputType,
](parser: ParserType) -> Parser[
    Map[ParserType, MapperInputType, MapperOutputType, mapper]
]:
    """Maps the output of the parser using the mapper function.

    Parameters:
        ParserType: The type of the mapper parser.
        MapperInputType: The mappers input type.
        MapperOutputType: The new mapped output type.
        mapper: The function used to transform the output of the parser.

    Args:
        parser: The parser whose output will be transformed.

    Returns:
        A new `Map` parser.
    """

    return Parser(
        Map[ParserType, MapperInputType, MapperOutputType, mapper](parser)
    )


# --- recognize ---


@fieldwise_init
struct Recognize[ParserType: Parsable](Movable & Copyable & Parsable):
    alias Output = StringSlice[ImmutableAnyOrigin]

    var _parser: ParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]

        var result = self._parser.parse(input)
        if result:
            var (_, next_input) = result.ok()
            var consumed = len(input) - len(next_input)
            return result_type(
                ok=(
                    input[:consumed],
                    input[consumed:],
                )
            )
        else:
            return result_type(result.err())


fn recognize[
    ParserType: Parsable
](parser: ParserType) -> Parser[Recognize[ParserType]]:
    return Parser(Recognize(parser))


# --- recognize_with ---


@fieldwise_init
struct RecognizeWith[ParserType: Parsable](Movable & Copyable & Parsable):
    alias Output = Tuple[StringSlice[ImmutableAnyOrigin], ParserType.Output]

    var _parser: ParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        var result = self._parser.parse(input)
        if result:
            var (output, next_input) = result.ok()
            var consumed = len(input) - len(next_input)
            return (
                (
                    rebind[StringSlice[ImmutableAnyOrigin]](input[:consumed]),
                    output^,
                ),
                input[:consumed],
            )

        else:
            return result.err()


fn recognize_with[
    ParserType: Parsable
](parser: ParserType) -> Parser[RecognizeWith[ParserType]]:
    return Parser(RecognizeWith(parser))


# --- eof ---


@fieldwise_init
struct Eof(Movable & Copyable & Parsable):
    alias Output = StringSlice[ImmutableAnyOrigin]

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]

        if not input:
            return result_type(
                (rebind[Self.Output](input), rebind[Self.Output](input))
            )
        else:
            return result_type(Err(input=input))


alias eof = Parser(Eof())

# --- opt ---


@fieldwise_init
struct Opt[ParserType: Parsable](Movable & Copyable & Parsable):
    """A parser impementation for `opt`."""

    alias Output = Optional[ParserType.Output]

    var _parser: ParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]

        var result = self._parser.parse(input)
        if result:
            var (output, next_input) = result.ok()
            return result_type((Optional(output^), next_input))
        elif result is ErrKind.BACKTRACK:
            return result_type(
                (
                    Self.Output(),
                    rebind[StringSlice[ImmutableAnyOrigin]](input),
                )
            )
        else:
            return result_type(result.err())


fn opt[ParserType: Parsable](parser: ParserType) -> Parser[Opt[ParserType]]:
    """A parser that will return `None` on failure instead of an error.

    Args:
        parser: The child parser.

    Returns:
        A new `Opt` parser.

    This parser will still propagate `ErrKind.CUT` appropriately.
    Only `ErrKind.BACKTRACK` will result and output of `None`.
    """
    return Parser(Opt(parser))


# --- value ---


@fieldwise_init
struct Value[ValueType: Movable & Copyable, ParserType: Parsable](
    Movable & Copyable & Parsable
):
    """A parser implementation of `value`."""

    alias Output = ValueType

    var _value: ValueType
    var _parser: ParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]
        var result = self._parser.parse(input)
        if result:
            var (_, next_input) = result.ok()
            return result_type((self._value.copy(), next_input))
        else:
            return result_type(result.err())


fn value[
    ValueType: Movable & Copyable, ParserType: Parsable
](value: ValueType, parser: ParserType) -> Parser[Value[ValueType, ParserType]]:
    """A parser that will produce the provided `value` if the child parser succeeds.

    Args:
        value: The value to produce on success.
        parser: The child parser.

    Returns:
        A new `Value` parser.
    """
    return Parser(Value(value, parser))


# --- void ---


@fieldwise_init
struct Discard[ParserType: Parsable](Movable & Copyable & Parsable):
    """A parser implementaion for `discard`."""

    alias Output = NoneType

    var _parser: ParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]

        var result = self._parser.parse(input)
        if result:
            var (_, next_input) = result.ok()
            return result_type((NoneType(), next_input))
        else:
            return result_type(result.err())


fn discard[
    ParserType: Parsable
](parser: ParserType) -> Parser[Discard[ParserType]]:
    """A combinator that discards the output of a parser.

    Args:
        parser: The parser whose output should be discarded.

    Returns:
        A new `Discard` parser.
    """
    return Parser(Discard(parser))


# --- empty ---


@fieldwise_init
@register_passable("trivial")
struct Empty(Movable & Copyable & Parsable):
    """A parser implementation for `empty`."""

    alias Output = NoneType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]

        return result_type(
            (NoneType(), rebind[StringSlice[ImmutableAnyOrigin]](input))
        )


alias empty = Parser(Empty())
"""A parser that always suceeds and consumes no input."""

# --- fail ---


@fieldwise_init
@register_passable("trivial")
struct Fail(Movable & Copyable & Parsable):
    """A parser implementation for `fail`."""

    alias Output = NoneType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]

        return result_type(Err(input=input))


alias fail = Parser(Fail())
"""A parser that always fails."""

# --- success ---


@fieldwise_init
struct Success[T: ParserValue](Movable & Copyable & Parsable):
    """A parser implementation for `success`."""

    alias Output = T

    var _value: T

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        return (
            self._value.copy(),
            rebind[StringSlice[ImmutableAnyOrigin]](input),
        )


fn success[T: ParserValue, //](var value: T) -> Parser[Success[T]]:
    """A parser that will always succeeds producing the provided value as the output.
    This parser does not consume any input.

    Args:
        value: The value for the parser to produce.

    Returns:
        A new `Success` parser.
    """

    return Parser(Success(value^))


# --- backtrack ---


@fieldwise_init
struct Backtrack[ParserType: Parsable](Movable & Copyable & Parsable):
    """A parser implementation for `backtrack`."""

    alias Output = ParserType.Output

    var _parser: ParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        var result = self._parser.parse(input)
        if result:
            return result^
        else:
            return Err(
                kind=ErrKind.BACKTRACK,
                input=input,
            )


fn backtrack[
    ParserType: Parsable
](parser: ParserType) -> Parser[Backtrack[ParserType]]:
    """Transforms the parser's error to `ErrKind.BACKTRACK` on failure.

    Args:
        parser: The parser to transform.

    Returns:
        A new `Backtrack` parser.
    """

    return Parser(Backtrack(parser))


# --- cut ---


@fieldwise_init
struct Cut[ParserType: Parsable](Movable & Copyable & Parsable):
    """A parser implementation for `cut`."""

    alias Output = ParserType.Output

    var _parser: ParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        var result = self._parser.parse(input)
        if result:
            return result^
        else:
            return Err(
                kind=ErrKind.CUT,
                input=input,
            )


fn cut[ParserType: Parsable](parser: ParserType) -> Parser[Cut[ParserType]]:
    """Transforms the parser's error to `ErrKind.CUT` on failure.

    Args:
        parser: The parser to transform.

    Returns:
        A new `Cut` parser.
    """

    return Parser(Cut(parser))


# --- not ---


@fieldwise_init
struct Not[ParserType: Parsable](Movable & Copyable & Parsable):
    """A parser implementation for `not_`."""

    alias Output = NoneType

    var _parser: ParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]
        var result = self._parser.parse(input)
        if result is ErrKind.CUT:
            return result_type(
                Err(
                    kind=ErrKind.CUT,
                    input=input,
                )
            )
        elif result is ErrKind.BACKTRACK:
            return result_type(
                (NoneType(), rebind[StringSlice[ImmutableAnyOrigin]](input))
            )
        else:
            return result_type(Err(input=input))


fn not_[ParserType: Parsable](parser: ParserType) -> Parser[Not[ParserType]]:
    """A parser that succeeds if provided parser fails.

    Note:
        This parser still respects `ErrMode.CUT` and will propagate it accordingly.
        Only `ErrMode.BACKTRACK` will result in this parser succeeding.

    Args:
        parser: The child parser.

    Returns:
        A new `Not` parser.
    """

    return Parser(Not(parser))


# --- peek ---


@fieldwise_init
struct Peek[ParserType: Parsable](Movable & Copyable & Parsable):
    alias Output = ParserType.Output

    var _parser: ParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]

        var result = self._parser.parse(input)
        if result:
            var (output, _) = result.ok()
            return result_type((output^, input))
        return result^


fn peek[ParserType: Parsable](parser: ParserType) -> Parser[Peek[ParserType]]:
    """Applies the provided parser without consuming the input.

    Args:
        parser: The child parser.

    Returns:
        A new `Peek` parser.
    """
    return Parser(Peek(parser))


# --- todo ---


@fieldwise_init
struct Todo[TodoOutput: ParserValue](Movable & Copyable & Parsable):
    """A parser implementation of `todo`."""

    alias Output = TodoOutput

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        return abort[ParseResult[Self.Output]]()


alias todo[TodoOutput: ParserValue = StringSlice[ImmutableAnyOrigin]] = Todo[
    TodoOutput
]()
"""A temporary placeholder parser that will abort if called."""
