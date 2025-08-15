from utils.variant import Variant
from sys.info import sizeof
from memory.maybe_uninitialized import UnsafeMaybeUninitialized
from .tuple import _ParserTuple
from builtin.variadics import VariadicOf
from os import abort
from .error import *
import .combinator

alias ParserValue = Copyable & Movable


@fieldwise_init
struct Parser[ParserType: Parsable](Parsable):
    var _parser: ParserType

    alias Output = ParserType.Output

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        return self._parser.parse(input)

    fn value[
        T: ParserValue, //
    ](self, var value: T) -> Parser[combinator.Value[T, Self]]:
        return combinator.value(value^, self)

    fn cut(self) -> Parser[combinator.Cut[Self]]:
        return combinator.cut(self)

    fn backtrack(self) -> Parser[combinator.Backtrack[Self]]:
        return combinator.backtrack(self)

    fn recognize(self) -> Parser[combinator.Recognize[Self]]:
        return combinator.recognize(self)

    fn recognize_with(self) -> Parser[combinator.RecognizeWith[Self]]:
        return combinator.recognize_with(self)


trait Parsable(Copyable & Movable):
    alias Output: ParserValue

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        ...


alias ParseOutput[T: ParserValue] = (
    T,
    StringSlice[ImmutableAnyOrigin],
)


@fieldwise_init
struct ParseResult[T: ParserValue](Boolable, Copyable, Movable):
    alias _ok = ParseOutput[T]
    alias _err = Err
    alias _type = Variant[Self._ok, Self._err]
    var result: Self._type

    # @implicit
    # fn __init__(out self, var ok: Self._ok):
    #     self.result = Self._type(ok^)

    @implicit
    fn __init__[
        origin: ImmutableOrigin, //
    ](out self, var ok: (T, StringSlice[origin],)):
        self.result = Self._type(ok^)

    @implicit
    fn __init__[
        output_origin: ImmutableOrigin, input_origin: ImmutableOrigin, //
    ](
        out self: ParseResult[StringSlice[ImmutableAnyOrigin]],
        var ok: (
            StringSlice[output_origin],
            StringSlice[input_origin],
        ),
    ):
        var (output, input) = ok^
        self.result = __type_of(self)._type(
            (
                rebind[StringSlice[ImmutableAnyOrigin]](output),
                rebind[StringSlice[ImmutableAnyOrigin]](input),
            )
        )

    @implicit
    fn __init__(out self, var err: Self._err):
        self.result = Self._type(err^)

    fn ok(mut self) -> Self._ok:
        return self.result.take[Self._ok]()

    fn err(mut self) -> Self._err:
        return self.result.take[Self._err]()

    fn map[U: ParserValue, f: fn (T) -> U](deinit self) -> ParseResult[U]:
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
