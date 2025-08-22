from .parser import *
from .ascii import digit1
from .combinator import *
from .combinator.choice import alt
from .combinator.sequence import seq
from .token import *


# fn _recognize_float(
#     input: ParserInput,
# ) -> ParseResult[StringSlice[ImmutableAnyOrigin]]:
#     return recognize(
#         seq(
#             opt(alt(char["+"], char["-"])),
#             alt(
#                 discard(seq(digit1, opt(seq(char["."], opt(digit1))))),
#                 discard(seq(char["."], digit1)),
#             ),
#             opt(
#                 seq(
#                     alt(char["e"], char["E"]),
#                     opt(alt(char["+"], char["-"])),
#                     cut(digit1),
#                 )
#             ),
#         )
#     ).parse(input)


fn _recognize_float(
    input: ParserInput,
) -> ParseResult[StringSlice[ImmutableAnyOrigin]]:
    return recognize(
        opt(char["+"] | char["-"])
        >> (
            (digit1 >> opt(char["."] >> opt(digit1)) >> None)
            | (char["."] >> digit1 >> None)
        )
        >> opt(
            (char["e"] | char["E"])
            >> opt(char["+"] | char["-"])
            >> cut(digit1),
        )
    ).parse(input)


fn _recognize_float_or_exceptions(
    input: ParserInput,
) -> ParseResult[StringSlice[ImmutableAnyOrigin]]:
    return alt(
        parser_fn[_recognize_float],
        tag_no_case("nan"),
        tag_no_case("infinity"),
        tag_no_case("inf"),
    ).parse(input)


fn _string_to_float(input: StringSlice[ImmutableAnyOrigin]) raises -> Float64:
    return Float64(input)


fn _float(input: ParserInput) -> ParseResult[Float64]:
    return try_map[_string_to_float](
        parser_fn[_recognize_float_or_exceptions]
    ).parse(input)


alias float = parser_fn[_float]
