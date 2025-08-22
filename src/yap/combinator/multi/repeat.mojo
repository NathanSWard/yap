from yap.parser import *
from yap.error import *
from yap.combinator.multi import *
from yap.combinator.multi.fold import fold, FoldInitialValueFn


fn _repeat_folder[
    ParserType: Parsable, CollecterType: Collectable
](
    var collecter: CollecterType,
    var element: ParserType.Output,
) -> CollecterType:
    collecter.append(rebind[CollecterType.Element](element^))
    return collecter^


fn _finish_collecter[
    CollecterType: Collectable
](var collecter: CollecterType) -> CollecterType:
    return collecter^.finish()


@fieldwise_init
struct Repeat[ParserType: Parsable, CollecterType: Collectable, range: Range](
    Copyable & Movable & Parsable
):
    """A parser implementation for `repeat`."""

    alias Output = CollecterType

    var _parser: ParserType

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        @parameter
        fn folder(
            var collecter: CollecterType,
            var element: ParserType.Output,
        ) -> CollecterType:
            collecter.append(rebind[CollecterType.Element](element^))
            return collecter^

        @parameter
        fn mapper(var collecter: CollecterType) -> CollecterType:
            return collecter^.finish()

        return map[mapper](
            fold[
                range=range,
                folder=folder,
                init = _initialize_collecter[CollecterType, range.min],
            ](self._parser)
        ).parse(input)


fn repeat[
    ParserType: Parsable, //,
    /,
    range: Range,
    CollecterType: Collectable = ListCollecter[ParserType.Output],
](parser: ParserType) -> Parser[Repeat[ParserType, CollecterType, range]]:
    """TODO."""

    return Parser(Repeat[_, CollecterType, range](parser))
