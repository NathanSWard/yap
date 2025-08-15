from .parser import *
from .tuple import _TraitTuple
from os import abort
from memory.maybe_uninitialized import *
from testing import assert_raises

# --- preceded ---


@fieldwise_init
struct Preceded[IgnoredParserType: Parsable, ParserType: Parsable](
    Movable & Copyable & Parsable
):
    alias Output = ParserType.Output

    var _ignored: IgnoredParserType
    var _parser: ParserType

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        var result = seq(self._ignored, self._parser).parse(input)
        if result:
            var ((_, output), next_input) = result.ok()
            return (output^, next_input)
        else:
            return result.err()


fn preceded[
    IgnoredParserType: Parsable, ParserType: Parsable
](ignored: IgnoredParserType, parser: ParserType) -> Parser[
    Preceded[IgnoredParserType, ParserType]
]:
    return Parser(Preceded(ignored, parser))


# --- terminated ---


@fieldwise_init
struct Terminated[ParserType: Parsable, IgnoredParserType: Parsable](
    Movable & Copyable & Parsable
):
    alias Output = ParserType.Output

    var _parser: ParserType
    var _ignored: IgnoredParserType

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        var result = seq(self._parser, self._ignored).parse(input)
        if result:
            var ((output, _), next_input) = result.ok()
            return (output^, next_input)
        else:
            return result.err()


fn terminated[
    ParserType: Parsable, IgnoredParserType: Parsable
](parser: ParserType, ignored: IgnoredParserType) -> Parser[
    Preceded[ParserType, IgnoredParserType]
]:
    return Parser(Preceded(parser, ignored))


# --- separated_pair ---


@fieldwise_init
struct SeparatedPair[
    FirstParserType: Parsable,
    SeparatorParserType: Parsable,
    SecondParserType: Parsable,
](Movable & Copyable & Parsable):
    alias Output = Tuple[FirstParserType.Output, SecondParserType.Output]

    var _first: FirstParserType
    var _separator: SeparatorParserType
    var _second: SecondParserType

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        var result = seq(self._first, self._separator, self._second).parse(
            input
        )

        if result:
            var ((first, _, second), next_input) = result.ok()
            return ((first^, second^), next_input)
        else:
            return result.err()


fn separated_pair[
    FirstParserType: Parsable,
    SeparatorParserType: Parsable,
    SecondParserType: Parsable,
](
    first: FirstParserType,
    separator: SeparatorParserType,
    second: SecondParserType,
) -> Parser[
    SeparatedPair[FirstParserType, SeparatorParserType, SecondParserType]
]:
    return Parser(SeparatedPair(first, separator, second))


# --- delimited ---


@fieldwise_init
struct Delimited[
    FirstIgnoredPaserType: Parsable,
    ParserType: Parsable,
    SecondIgnoredPaserType: Parsable,
](Movable & Copyable & Parsable):
    alias Output = ParserType.Output

    var _first_ignored: FirstIgnoredPaserType
    var _parser: ParserType
    var _second_ignored: SecondIgnoredPaserType

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        var result = seq(
            self._first_ignored, self._parser, self._second_ignored
        ).parse(input)

        if result:
            var ((_, output, _), next_input) = result.ok()
            return (output^, next_input)
        else:
            return result.err()


fn delimited[
    FirstIgnoredPaserType: Parsable,
    ParserType: Parsable,
    SecondIgnoredPaserType: Parsable,
](
    first_ignored: FirstIgnoredPaserType,
    parser: ParserType,
    second_ignored: SecondIgnoredPaserType,
) -> Parser[
    Delimited[FirstIgnoredPaserType, ParserType, SecondIgnoredPaserType]
]:
    return Parser(Delimited(first_ignored, parser, second_ignored))


# --- recognize ---


@fieldwise_init
struct Recognize[ParserType: Parsable](Movable & Copyable & Parsable):
    alias Output = StringSlice[ImmutableAnyOrigin]

    var _parser: ParserType

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        var result = self._parser.parse(input)
        if result:
            var (_, next_input) = result.ok()
            var consumed = len(input) - len(next_input)
            return (
                input[:consumed],
                input[consumed:],
            )
        else:
            return result.err()


fn recognize[
    ParserType: Parsable
](parser: ParserType) -> Parser[Recognize[ParserType]]:
    return Parser(Recognize(parser))


# --- recognize_with ---


@fieldwise_init
struct RecognizeWith[ParserType: Parsable](Movable & Copyable & Parsable):
    alias Output = Tuple[StringSlice[ImmutableAnyOrigin], ParserType.Output]

    var _parser: ParserType

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        var result = self._parser.parse(input)
        if result:
            var (output, next_input) = result.ok()
            var consumed = len(input) - len(next_input)
            return (
                (
                    rebind[StringSlice[ImmutableAnyOrigin]](input[:consumed]),
                    output^,
                ),
                rebind[StringSlice[ImmutableAnyOrigin]](input[:consumed]),
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

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        if not input:
            return (rebind[Self.Output](input), rebind[Self.Output](input))
        else:
            return Err(input=input)


alias eof = Parser(Eof())

# --- opt ---


@fieldwise_init
struct Opt[ParserType: Parsable](Movable & Copyable & Parsable):
    alias Output = Optional[ParserType.Output]

    var _parser: ParserType

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        var result = self._parser.parse(input)
        if result:
            var (output, next_input) = result.ok()
            return (Optional(output^), next_input)

        var err = result.err()
        if err.kind == ErrKind.BACKTRACK:
            return (
                Self.Output(),
                rebind[StringSlice[ImmutableAnyOrigin]](input),
            )
        else:
            return err^


fn opt[ParserType: Parsable](parser: ParserType) -> Parser[Opt[ParserType]]:
    return Parser(Opt(parser))


# --- value ---


@fieldwise_init
struct Value[ValueType: Movable & Copyable, ParserType: Parsable](
    Movable & Copyable & Parsable
):
    alias Output = ValueType

    var _value: ValueType
    var _parser: ParserType

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        var result = self._parser.parse(input)
        if result:
            var (_, next_input) = result.ok()
            return (self._value.copy(), next_input)
        else:
            return result.err()


fn value[
    ValueType: Movable & Copyable, ParserType: Parsable
](value: ValueType, parser: ParserType) -> Parser[Value[ValueType, ParserType]]:
    return Parser(Value(value, parser))


# --- empty ---


@fieldwise_init
@register_passable("trivial")
struct Empty(Movable & Copyable & Parsable):
    alias Output = NoneType

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        return (NoneType(), rebind[StringSlice[ImmutableAnyOrigin]](input))


alias empty = Parser(Empty())


# --- fail ---


@fieldwise_init
@register_passable("trivial")
struct Fail(Movable & Copyable & Parsable):
    alias Output = NoneType

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        return Err(input=input)


alias fail = Parser(Fail())

# --- success ---


@fieldwise_init
struct Success[T: ParserValue](Movable & Copyable & Parsable):
    alias Output = T

    var _value: T

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        return (
            self._value.copy(),
            rebind[StringSlice[ImmutableAnyOrigin]](input),
        )


fn success[T: ParserValue, //](var value: T) -> Parser[Success[T]]:
    return Parser(Success(value^))


# --- backtrack ---


@fieldwise_init
struct Backtrack[ParserType: Parsable](Movable & Copyable & Parsable):
    alias Output = ParserType.Output

    var _parser: ParserType

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
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
    return Parser(Backtrack(parser))


# --- cut ---


@fieldwise_init
struct Cut[ParserType: Parsable](Movable & Copyable & Parsable):
    alias Output = ParserType.Output

    var _parser: ParserType

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        var result = self._parser.parse(input)
        if result:
            return result^
        else:
            return Err(
                kind=ErrKind.CUT,
                input=input,
            )


fn cut[ParserType: Parsable](parser: ParserType) -> Parser[Cut[ParserType]]:
    return Parser(Cut(parser))


# --- not ---


@fieldwise_init
struct Not[ParserType: Parsable](Movable & Copyable & Parsable):
    alias Output = NoneType

    var _parser: ParserType

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        var result = self._parser.parse(input)
        if result is ErrKind.CUT:
            return Err(
                kind=ErrKind.CUT,
                input=input,
            )
        elif result is ErrKind.BACKTRACK:
            return (NoneType(), rebind[StringSlice[ImmutableAnyOrigin]](input))
        else:
            return Err(input=input)


fn not_[ParserType: Parsable](parser: ParserType) -> Parser[Not[ParserType]]:
    return Parser(Not(parser))


# --- peek ---


@fieldwise_init
struct Peek[ParserType: Parsable](Movable & Copyable & Parsable):
    alias Output = ParserType.Output

    var _parser: ParserType

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        var result = self._parser.parse(input)
        if result:
            var (output, _) = result.ok()
            return (output^, input)
        return result^


fn peek[ParserType: Parsable](parser: ParserType) -> Parser[Peek[ParserType]]:
    return Parser(Peek(parser))


# --- todo ---


@fieldwise_init
struct Todo[TodoOutput: ParserValue](Movable & Copyable & Parsable):
    alias Output = TodoOutput

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        return abort[ParseResult[Self.Output]]()


alias todo[TodoOutput: ParserValue, //] = Todo[TodoOutput]()


# --- alt ---


@fieldwise_init
struct Alt[*parser_types: Parsable](Movable & Copyable & Parsable):
    alias Output = parser_types[0].Output
    alias _tuple = _TraitTuple[Parsable, *parser_types]

    var _parsers: Self._tuple

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        @parameter
        for i in range(Self._tuple.__len__()):
            var result = rebind[__type_of(self._parsers[i])](
                self._parsers[i]
            ).parse(input)

            if result is ErrKind.CUT:
                return Err(
                    kind=ErrKind.CUT,
                    input=input,
                )
            if result:
                return rebind[ParseResult[Self.Output]](result^)

        return Err(input=input)


fn alt[
    *parser_types: Parsable
](var *parsers: *parser_types) -> Parser[Alt[*parser_types]]:
    return Parser(Alt(_TraitTuple(storage=parsers^)))


# --- seq ---


# @fieldwise_init
# struct _Seq[
#     output: ParserValue,
#     *parsers: Parsable,
# ](Movable & Copyable & Parsable):
#     alias _tuple = _ParserTuple[*parsers]
#     var _parsers: Self._tuple

#     alias Output = output

#     fn parse_impl[
#         *values: ParserValue
#     ](self: _Seq[_ParserValueTuple[*values], *parsers]):
#         pass

#     fn parse[
#         *values: ParserValue
#     ](
#         self: _Seq[_ParserValueTuple[*values], *parsers], input: Input
#     ) -> ParseResult[Self.Output]:
#         var to_parse = input

#         var ret = UnsafeMaybeUninitialized[_ParserValueTuple[*values]]()

#         @parameter
#         for i in range(Self._tuple.__len__()):
#             var result = self._parsers[i].parse(to_parse)
#             if not result:

#                 @parameter
#                 for to_destroy in range(i):
#                     ret.unsafe_ptr()[].unsafe_pointer_to[
#                         to_destroy
#                     ]().destroy_pointee()

#                 return ParseResult[Self.Output](ParseError())

#             (value, next_input) = result^.ok()
#             to_parse = next_input

#             rebind[__type_of(value)](ret.unsafe_ptr()[][i]) = value

#         return ParseResult[Self.Output](ret.assume_initialized())

#     fn parse(self: Self, input: Input) -> ParseResult[Self.Output]:
#         constrained[False, "..."]()
#         return abort[ParseResult[Self.Output]]()


@fieldwise_init
struct _Seq2[
    parser_a: Parsable,
    parser_b: Parsable,
](Movable & Copyable & Parsable):
    var _a: parser_a
    var _b: parser_b

    alias Output = Tuple[parser_a.Output, parser_b.Output]

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        var result_a = self._a.parse(input)
        if not result_a:
            return result_a.err()
        var (value_a, input_a) = result_a.ok()

        var result_b = self._b.parse(input_a)
        if not result_b:
            return result_b.err()
        var (value_b, input_b) = result_b.ok()

        return ParseResult((Self.Output(value_a^, value_b^), input_b))


fn seq[
    parser_a: Parsable,
    parser_b: Parsable, //,
](a: parser_a, b: parser_b) -> Parser[_Seq2[parser_a, parser_b]]:
    return Parser(
        _Seq2[
            parser_a,
            parser_b,
        ](a, b)
    )


@fieldwise_init
struct _Seq3[
    parser_a: Parsable,
    parser_b: Parsable,
    parser_c: Parsable,
](Movable & Copyable & Parsable):
    var _a: parser_a
    var _b: parser_b
    var _c: parser_c

    alias Output = Tuple[parser_a.Output, parser_b.Output, parser_c.Output]

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        var result_a = self._a.parse(input)
        if not result_a:
            return result_a.err()
        var (value_a, input_a) = result_a.ok()

        var result_b = self._b.parse(input_a)
        if not result_b:
            return result_b.err()
        var (value_b, input_b) = result_b.ok()

        var result_c = self._c.parse(input_b)
        if not result_c:
            return result_c.err()
        var (value_c, input_c) = result_c.ok()

        return ParseResult((Self.Output(value_a^, value_b^, value_c^), input_c))


fn seq[
    parser_a: Parsable,
    parser_b: Parsable,
    parser_c: Parsable, //,
](a: parser_a, b: parser_b, c: parser_c) -> Parser[
    _Seq3[parser_a, parser_b, parser_c]
]:
    return Parser(
        _Seq3[
            parser_a,
            parser_b,
            parser_c,
        ](a, b, c)
    )


@fieldwise_init
struct _Seq4[
    parser_a: Parsable,
    parser_b: Parsable,
    parser_c: Parsable,
    parser_d: Parsable,
](Movable & Copyable & Parsable):
    var _a: parser_a
    var _b: parser_b
    var _c: parser_c
    var _d: parser_d

    alias Output = Tuple[
        parser_a.Output, parser_b.Output, parser_c.Output, parser_d.Output
    ]

    fn parse[
        origin: ImmutableOrigin, //
    ](self, input: StringSlice[origin]) -> ParseResult[Self.Output]:
        var result_a = self._a.parse(input)
        if not result_a:
            return result_a.err()
        var (value_a, input_a) = result_a.ok()

        var result_b = self._b.parse(input_a)
        if not result_b:
            return result_b.err()
        var (value_b, input_b) = result_b.ok()

        var result_c = self._c.parse(input_b)
        if not result_c:
            return result_c.err()
        var (value_c, input_c) = result_c.ok()

        var result_d = self._d.parse(input_c)
        if not result_d:
            return result_d.err()
        var (value_d, input_d) = result_d.ok()

        return ParseResult(
            (Self.Output(value_a^, value_b^, value_c^, value_d^), input_d)
        )


fn seq[
    parser_a: Parsable,
    parser_b: Parsable,
    parser_c: Parsable,
    parser_d: Parsable, //,
](a: parser_a, b: parser_b, c: parser_c, d: parser_d) -> Parser[
    _Seq4[parser_a, parser_b, parser_c, parser_d]
]:
    return Parser(
        _Seq4[
            parser_a,
            parser_b,
            parser_c,
            parser_d,
        ](a, b, c, d)
    )
