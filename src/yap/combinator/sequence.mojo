from yap.parser import *
from yap.tuple import *

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
    IgnoredParserType: Parsable, ParserType: Parsable, //
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
    ParserType: Parsable, IgnoredParserType: Parsable, //
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
    SecondParserType: Parsable, //,
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

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
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
    SecondIgnoredPaserType: Parsable, //,
](
    first_ignored: FirstIgnoredPaserType,
    parser: ParserType,
    second_ignored: SecondIgnoredPaserType,
) -> Parser[
    Delimited[FirstIgnoredPaserType, ParserType, SecondIgnoredPaserType]
]:
    return Parser(Delimited(first_ignored, parser, second_ignored))


# --- seq ---


fn seq[
    ParserType: Parsable, //,
](parser: ParserType) -> Parser[ParserType]:
    return Parser(parser)


@fieldwise_init
struct _Seq2[
    parser_a: Parsable,
    parser_b: Parsable,
](Movable & Copyable & Parsable):
    var _a: parser_a
    var _b: parser_b

    alias Output = Tuple[parser_a.Output, parser_b.Output]

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        var result_a = self._a.parse(input)
        if not result_a:
            return result_a.err()
        var (value_a, input_a) = result_a.ok()

        var result_b = self._b.parse(input_a)
        if not result_b:
            return result_b.err()
        var (value_b, input_b) = result_b.ok()

        return (Self.Output(value_a^, value_b^), input_b)


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

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
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

        return (Self.Output(value_a^, value_b^, value_c^), input_c)


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

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
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

        return (Self.Output(value_a^, value_b^, value_c^, value_d^), input_d)


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
