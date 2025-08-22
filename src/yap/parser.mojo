from utils.variant import Variant
from memory.maybe_uninitialized import UnsafeMaybeUninitialized
from .error import *
import .combinator

alias ParserValue = Copyable & Movable
"""Todo."""

alias ParserInput = StringSlice[mut=False]
"""Todo."""


trait Parsable(Copyable & Movable):
    alias Output: ParserValue

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        ...


@fieldwise_init
struct Parser[ParserType: Parsable](Copyable & Movable & Parsable):
    """Todo."""

    var _parser: ParserType

    alias Output = ParserType.Output

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        return self._parser.parse(input)

    fn value[
        T: ParserValue, //
    ](self, var value: T) -> Parser[combinator.Value[T, ParserType]]:
        """Todo."""

        return combinator.value(value^, self._parser)

    fn cut(self) -> Parser[combinator.Cut[ParserType]]:
        """Todo."""

        return combinator.cut(self._parser)

    fn backtrack(self) -> Parser[combinator.Backtrack[ParserType]]:
        """Todo."""

        return combinator.backtrack(self._parser)

    fn recognize(self) -> Parser[combinator.Recognize[ParserType]]:
        """Todo."""

        return combinator.recognize(self._parser)

    fn recognize_with(self) -> Parser[combinator.RecognizeWith[ParserType]]:
        """Todo."""

        return combinator.recognize_with(self._parser)

    fn map[
        MapperInputType: ParserValue,
        MapperOutputType: ParserValue, //,
        mapper: fn (var MapperInputType) -> MapperOutputType,
    ](self) -> Parser[
        combinator.Map[ParserType, MapperInputType, MapperOutputType, mapper]
    ]:
        """Todo."""

        return combinator.map[mapper](self._parser)

    fn try_map[
        MapperInputType: ParserValue,
        MapperOutputType: ParserValue, //,
        mapper: fn (var MapperInputType) raises -> MapperOutputType,
    ](self) -> Parser[
        combinator.TryMap[ParserType, MapperInputType, MapperOutputType, mapper]
    ]:
        """Todo."""

        return combinator.try_map[mapper](self._parser)

    fn and_then[
        AndThenParserType: Parsable, //
    ](self, parser: AndThenParserType) -> Parser[
        combinator.AndThen[ParserType, AndThenParserType]
    ]:
        """Todo."""

        return combinator.and_then(self._parser, parser)

    fn __rshift__[
        P: Parsable, //, __disambiguate: NoneType = None
    ](self, parser: P) -> Parser[combinator.sequence._Seq2[ParserType, P]]:
        return combinator.sequence.seq(self._parser, parser)

    fn __rshift__[
        P: Parsable, //
    ](self, parser: Parser[P]) -> Parser[
        combinator.sequence._Seq2[ParserType, P]
    ]:
        return combinator.sequence.seq(self._parser, parser._parser)

    fn __rshift__(
        self, _none: __type_of(None)
    ) -> Parser[combinator.Discard[ParserType]]:
        return combinator.discard(self._parser)

    fn __or__[
        P: Parsable, //, __disambiguate: NoneType = None
    ](self, parser: P) -> Parser[combinator.choice.Alt[ParserType, P]]:
        return combinator.choice.alt(self._parser, parser)

    fn __or__[
        P: Parsable, //
    ](self, parser: Parser[P]) -> Parser[combinator.choice.Alt[ParserType, P]]:
        return combinator.choice.alt(self._parser, parser._parser)

    fn __lt__[
        P: Parsable, //
    ](self, parser: Parser[P]) -> Parser[combinator.choice.Alt[ParserType, P]]:
        return combinator.choice.alt(self._parser, parser._parser)

    fn __invert__(self) -> Parser[combinator.Not[ParserType]]:
        return combinator.not_(self._parser)


@fieldwise_init
struct ParserFn[T: ParserValue, //, parser: fn (ParserInput) -> ParseResult[T]](
    Copyable & Movable & Parsable
):
    alias Output = T

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        return parser(input)


fn _parser_fn[
    T: ParserValue, //, parser: fn (ParserInput) -> ParseResult[T]
]() -> Parser[ParserFn[parser]]:
    return Parser[_](ParserFn[parser]())


alias parser_fn[
    T: ParserValue, //, parser: fn (ParserInput) -> ParseResult[T]
] = _parser_fn[parser]()


alias ParseOutput[T: ParserValue] = (
    T,
    StringSlice[ImmutableAnyOrigin],
)


struct ParseResult[T: ParserValue](Boolable, Copyable, Movable):
    alias _ok = ParseOutput[T]
    alias _err = Err
    alias _type = Variant[Self._ok, Self._err]
    var result: Self._type

    @implicit
    fn __init__(out self, var result: Self._type):
        self.result = result^

    @implicit
    fn __init__[
        origin: ImmutableOrigin, //
    ](out self, var ok: (T, StringSlice[origin])):
        var (output, input) = ok^
        self.result = Self._type(
            (output^, rebind[StringSlice[ImmutableAnyOrigin]](input))
        )

    @implicit
    fn __init__[
        output_origin: ImmutableOrigin, input_origin: ImmutableOrigin, //
    ](
        out self,
        var ok: (
            StringSlice[output_origin],
            StringSlice[input_origin],
        ),
    ):
        var (output, input) = ok^
        self.result = Self._type(
            (
                rebind[StringSlice[ImmutableAnyOrigin]](output),
                rebind[StringSlice[ImmutableAnyOrigin]](input),
            )
        )

    @implicit
    fn __init__(out self, var err: Self._err):
        self.result = err^

    fn ok(mut self) -> Self._ok:
        return self.result.take[Self._ok]()

    fn err(mut self) -> Self._err:
        return self.result.take[Self._err]()

    fn map[
        U: ParserValue, //, f: fn (var T) -> U
    ](deinit self) -> ParseResult[U]:
        if self:
            var (value, input) = self.result.take[Self._ok]()
            return (f(value^), input)
        else:
            return self.result.take[Self._err]()

    fn __is__(self, kind: ErrKind) -> Bool:
        if not self:
            return self.result[Self._err] is kind
        return False

    fn __isnot__(self, kind: ErrKind) -> Bool:
        return not self is kind

    fn __bool__(self) -> Bool:
        return self.result.isa[Self._ok]()

    fn __repr__[U: ParserValue & Representable](self: ParseResult[U]) -> String:
        return self.__str__()

    fn __str__[U: ParserValue & Representable](self: ParseResult[U]) -> String:
        var string = String()
        self.write_to(string)
        return string^

    fn write_to[
        U: ParserValue & Representable,
        W: Writer,
    ](self: ParseResult[U], mut writer: W):
        alias ok = ParseOutput[U]
        if self.result.isa[ok]():
            ref output = self.result[ok]
            writer.write("ParseResult.Ok(output=")
            writer.write(repr(output[0]))
            writer.write(", remaining=")
            writer.write(repr(output[1]))
            writer.write(")")
        else:
            writer.write("ParseResult.Error(err=")
            writer.write(self.result[Self._err].__repr__())
            writer.write(")")
