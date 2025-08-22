from yap.parser import *
from yap.error import *
from yap.combinator.multi.fold import *


fn _add_one[T: AnyType](init: Int, var element: T) -> Int:
    return init + 1


alias RepeatCount[ParserType: Parsable] = Fold[
    FoldInitialValue[Int],
    Range(min=0),
    _add_one[ParserType.Output],
]


fn repeat_count[
    ParserType: Parsable, //
](parser: ParserType) -> Parser[RepeatCount[ParserType]]:
    return fold[range = Range(min=0), folder = _add_one[ParserType.Output]](
        parser, init=0
    )
