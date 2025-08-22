from yap.parser import *
from yap.error import *
from yap.combinator.multi import *
from yap.combinator.sequence import preceded

from sys.intrinsics import unlikely


fn _separated_parse_till_backtrack[
    ParserType: Parsable,
    SeparatorParserType: Parsable,
    CollecterType: Collectable, //,
](
    parser: ParserType,
    separator: SeparatorParserType,
    var init: CollecterType,
    input: ParserInput,
) -> ParseResult[CollecterType]:
    var input_to_parse = rebind[StringSlice[ImmutableAnyOrigin]](input)

    while len(input_to_parse) > 0:
        if result := preceded(separator, parser).parse(input_to_parse):
            var (output, next_input) = result.ok()

            # TODO: add error context to this
            # Check that the separator/parser consume part of the input to prevent an infinite loop
            if unlikely(len(input_to_parse) == len(next_input)):
                return Err(input=input)

            init.append(rebind[CollecterType.Element](output^))
            input_to_parse = next_input

        elif result is ErrKind.BACKTRACK:
            return (init^, input_to_parse)
        else:
            return result.err()

    return (init^, input_to_parse)


fn _separated_0[
    ParserType: Parsable,
    SeparatorParserType: Parsable,
    CollecterType: Collectable, //,
](
    parser: ParserType,
    separator: SeparatorParserType,
    var init: CollecterType,
    input: ParserInput,
) -> ParseResult[CollecterType]:
    var input_to_parse = rebind[StringSlice[ImmutableAnyOrigin]](input)

    if result := parser.parse(input_to_parse):
        var (output, next_input) = result.ok()
        init.append(rebind[CollecterType.Element](output^))
        input_to_parse = next_input
    elif result is ErrKind.BACKTRACK:
        return (init^, input_to_parse)
    else:
        return result.err()

    return _separated_parse_till_backtrack(
        parser, separator, init^, input_to_parse
    )


fn _separated_1[
    ParserType: Parsable,
    SeparatorParserType: Parsable,
    CollecterType: Collectable, //,
](
    parser: ParserType,
    separator: SeparatorParserType,
    var init: CollecterType,
    input: ParserInput,
) -> ParseResult[CollecterType]:
    var input_to_parse = rebind[StringSlice[ImmutableAnyOrigin]](input)

    if result := parser.parse(input_to_parse):
        var (output, next_input) = result.ok()
        init.append(rebind[CollecterType.Element](output^))
        input_to_parse = next_input
    else:
        return result.err()

    return _separated_parse_till_backtrack(
        parser, separator, init^, input_to_parse
    )


fn _separated_min[
    ParserType: Parsable,
    SeparatorParserType: Parsable,
    CollecterType: Collectable, //,
    min: UInt,
](
    parser: ParserType,
    separator: SeparatorParserType,
    var init: CollecterType,
    input: ParserInput,
) -> ParseResult[CollecterType]:
    var input_to_parse = rebind[StringSlice[ImmutableAnyOrigin]](input)

    if result := parser.parse(input_to_parse):
        var (output, next_input) = result.ok()
        init.append(rebind[CollecterType.Element](output^))
        input_to_parse = next_input
    else:
        return result.err()

    @parameter
    for _ in range(1, min):
        if result := preceded(separator, parser).parse(input_to_parse):
            var (output, next_input) = result.ok()
            init.append(rebind[CollecterType.Element](output^))
            input_to_parse = next_input
        else:
            return result.err()

    return _separated_parse_till_backtrack(
        parser, separator, init^, input_to_parse
    )


fn _separated_parse_till_backtrack_or_max[
    ParserType: Parsable,
    SeparatorParserType: Parsable,
    CollecterType: Collectable, //,
    min: UInt,
    max: UInt,
](
    parser: ParserType,
    separator: SeparatorParserType,
    var init: CollecterType,
    input: ParserInput,
) -> ParseResult[CollecterType]:
    var input_to_parse = rebind[StringSlice[ImmutableAnyOrigin]](input)

    for _ in range(min, max):
        if result := preceded(separator, parser).parse(input_to_parse):
            var (output, next_input) = result.ok()
            init.append(rebind[CollecterType.Element](output^))
            input_to_parse = next_input
        elif result is ErrKind.BACKTRACK:
            return (init^, input_to_parse)
        else:
            return result.err()

    return (init^, input_to_parse)


fn _separated_0_max[
    ParserType: Parsable,
    SeparatorParserType: Parsable,
    CollecterType: Collectable, //,
    max: UInt,
](
    parser: ParserType,
    separator: SeparatorParserType,
    var init: CollecterType,
    input: ParserInput,
) -> ParseResult[CollecterType]:
    var input_to_parse = rebind[StringSlice[ImmutableAnyOrigin]](input)

    if result := parser.parse(input_to_parse):
        var (output, next_input) = result.ok()
        init.append(rebind[CollecterType.Element](output^))
        input_to_parse = next_input
    else:
        return (init^, input_to_parse)

    return _separated_parse_till_backtrack_or_max[1, max](
        parser, separator, init^, input_to_parse
    )


fn _separated_min_max[
    ParserType: Parsable,
    SeparatorParserType: Parsable,
    CollecterType: Collectable, //,
    min: UInt,
    max: UInt,
](
    parser: ParserType,
    separator: SeparatorParserType,
    var init: CollecterType,
    input: ParserInput,
) -> ParseResult[CollecterType]:
    var input_to_parse = rebind[StringSlice[ImmutableAnyOrigin]](input)

    if result := parser.parse(input_to_parse):
        var (output, next_input) = result.ok()
        init.append(rebind[CollecterType.Element](output^))
        input_to_parse = next_input
    else:
        return result.err()

    @parameter
    for _ in range(1, min):
        if result := preceded(separator, parser).parse(input_to_parse):
            var (output, next_input) = result.ok()
            init.append(rebind[CollecterType.Element](output^))
            input_to_parse = next_input
        else:
            return result.err()

    return _separated_parse_till_backtrack_or_max[min, max](
        parser, separator, init^, input_to_parse
    )


@fieldwise_init
struct Separated[
    ParserType: Parsable,
    SeparatorParserType: Parsable,
    /,
    range: Range,
    CollecterType: Collectable,
](Copyable & Movable & Parsable):
    """A parser implementation for `separated`."""

    alias Output = CollecterType

    var _parser: ParserType
    var _separator: SeparatorParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias min = range.min
        alias max = range.max.or_else(UInt.MAX)
        constrained[
            min <= max and max != 0,
            "RepeatTill requires min <= max and max != 0",
        ]()

        var init = _initialize_collecter[CollecterType, min]()

        @parameter
        if not range.max:

            @parameter
            if min == 0:
                return _separated_0(self._parser, self._separator, init^, input)
            elif min == 1:
                return _separated_1(self._parser, self._separator, init^, input)
            else:
                return _separated_min[min](
                    self._parser, self._separator, init^, input
                )
        else:

            @parameter
            if min == 0:
                return _separated_0_max[max](
                    self._parser, self._separator, init^, input
                )
            else:
                return _separated_min_max[min, max](
                    self._parser, self._separator, init^, input
                )


fn separated[
    ParserType: Parsable,
    SeparatorParserType: Parsable, //,
    /,
    range: Range,
    collecter: Collectable = ListCollecter[ParserType.Output],
](parser: ParserType, separator: SeparatorParserType) -> Parser[
    Separated[
        ParserType,
        SeparatorParserType,
        range,
        collecter,
    ]
]:
    """TODO."""

    return Parser(
        Separated[
            _,
            _,
            range,
            collecter,
        ](parser, separator)
    )
