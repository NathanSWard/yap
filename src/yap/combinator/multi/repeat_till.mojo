from yap.parser import *
from yap.error import *
from yap.combinator.multi import *


fn _repeat_till_0[
    ParserType: Parsable,
    TerminatorParserType: Parsable,
    CollecterType: Collectable, //,
](
    parser: ParserType,
    terminator: TerminatorParserType,
    var init: CollecterType,
    input: ParserInput,
) -> ParseResult[Tuple[CollecterType, TerminatorParserType.Output]]:
    var input_to_parse = rebind[StringSlice[ImmutableAnyOrigin]](input)

    while True:
        var terminator_result = terminator.parse(input_to_parse)
        if terminator_result:
            var (output, next_input) = terminator_result.ok()
            return ((init^, output), next_input)
        elif terminator_result is ErrKind.CUT:
            return terminator_result.err()

        var parser_result = parser.parse(input_to_parse)
        if parser_result:
            var (output, next_input) = parser_result.ok()
            init.append(rebind[CollecterType.Element](output^))
            input_to_parse = next_input
        elif parser_result is ErrKind.CUT:
            return parser_result.err()


fn _repeat_till_min[
    ParserType: Parsable,
    TerminatorParserType: Parsable,
    CollecterType: Collectable, //,
    min: UInt,
](
    parser: ParserType,
    terminator: TerminatorParserType,
    var init: CollecterType,
    input: ParserInput,
) -> ParseResult[Tuple[CollecterType, TerminatorParserType.Output]]:
    var input_to_parse = rebind[StringSlice[ImmutableAnyOrigin]](input)

    # We know we need at _least_ min occurences of `ParserType` so we can unroll those here.
    @parameter
    for _ in range(0, min):
        var parser_result = parser.parse(input_to_parse)
        if parser_result:
            var (output, next_input) = parser_result.ok()
            init.append(rebind[CollecterType.Element](output^))
            input_to_parse = next_input
        else:
            return parser_result.err()

    return _repeat_till_0(parser, terminator, init^, input_to_parse)


fn _repeat_till_min_max[
    ParserType: Parsable,
    TerminatorParserType: Parsable,
    CollecterType: Collectable, //,
    min: UInt,
    max: UInt,
](
    parser: ParserType,
    terminator: TerminatorParserType,
    var init: CollecterType,
    input: ParserInput,
) -> ParseResult[Tuple[CollecterType, TerminatorParserType.Output]]:
    var input_to_parse = rebind[StringSlice[ImmutableAnyOrigin]](input)

    # We know we need at _last_ min occurences of `ParserType` so we can unroll those here.
    @parameter
    for _ in range(0, min):
        var parser_result = parser.parse(input_to_parse)
        if parser_result:
            var (output, next_input) = parser_result.ok()
            init.append(rebind[CollecterType.Element](output^))
            input_to_parse = next_input
        else:
            return parser_result.err()

    @parameter
    for _ in range(min, max):
        var terminator_result = terminator.parse(input_to_parse)
        if terminator_result:
            var (output, next_input) = terminator_result.ok()
            return ((init^, output), next_input)
        elif terminator_result is ErrKind.CUT:
            return terminator_result.err()

        var parser_result = parser.parse(input_to_parse)
        if parser_result:
            var (output, next_input) = parser_result.ok()
            init.append(rebind[CollecterType.Element](output^))
            input_to_parse = next_input
        elif parser_result is ErrKind.CUT:
            return parser_result.err()

    var terminator_result = terminator.parse(input_to_parse)
    if terminator_result:
        var (output, next_input) = terminator_result.ok()
        return ((init^, output), next_input)
    else:
        return terminator_result.err()


@fieldwise_init
struct RepeatTill[
    ParserType: Parsable,
    TerminatorParserType: Parsable,
    /,
    range: Range,
    CollecterType: Collectable,
](Copyable & Movable & Parsable):
    """A parser implementation for `repeat`."""

    alias Output = Tuple[CollecterType, TerminatorParserType.Output]

    var _parser: ParserType
    var _terminator: TerminatorParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias min = range.min
        alias max = range.max.or_else(UInt.MAX)
        constrained[
            min < max and max != 0,
            "RepeatTill requires min < max and max != 0",
        ]()

        var init = _initialize_collecter[CollecterType, min]()

        @parameter
        if min == 0 and not range.max:
            return _repeat_till_0(self._parser, self._terminator, init^, input)
        elif min > 0 and not range.max:
            return _repeat_till_min[min](
                self._parser, self._terminator, init^, input
            )
        else:
            return _repeat_till_min_max[min, max](
                self._parser, self._terminator, init^, input
            )


fn reapeat_till[
    ParserType: Parsable,
    TerminatorParserType: Parsable,
    OutputType: ParserValue, //,
    /,
    range: Range,
    CollecterType: Collectable = ListCollecter[ParserType.Output],
](parser: ParserType, terminator: TerminatorParserType) -> Parser[
    RepeatTill[ParserType, TerminatorParserType, range, CollecterType]
]:
    """TODO."""

    return Parser(RepeatTill[_, _, range, CollecterType](parser, terminator))
