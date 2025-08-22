from .token import *
from .combinator import *
from .parser import *

alias AlphaLowerTokens = CodepointRange[start="a", end="z"]
alias AlphaUpperTokens = CodepointRange[start="A", end="Z"]
alias NumericTokens = CodepointRange[start="0", end="9"]

alias alpha_lower[*, min: UInt = 0] = take_while[min=min](AlphaLowerTokens)
"""Parser recognizing lowercase alpha codepoints `'a'..='z'`."""

alias alpha_upper[*, min: UInt = 0] = take_while[min=min](AlphaUpperTokens)
"""Parser recognizing uppercase alpha codepoints `'A'..='Z'`."""

alias alpha[*, min: UInt] = take_while[min=min](
    TokenSet(AlphaLowerTokens, AlphaUpperTokens)
)
"""Parser recognizing alpha codepoints `'a'..='z'` and `'A'..='Z'`."""

alias alpha0 = alpha[min=0]
alias alpha1 = alpha[min=1]

alias digit[*, min: UInt] = take_while[min=min](NumericTokens)
"""Parser recognizing numeric codepoints `'0'..='9'`."""

alias digit0 = digit[min=0]
alias digit1 = digit[min=1]

alias alphanumeric[*, min: UInt] = take_while[min=min](
    TokenSet(
        AlphaLowerTokens,
        AlphaUpperTokens,
        NumericTokens,
    )
)
"""Parser recognizing alphanumeric codepoints `'a'..='z'`, `'A'..='Z'`, and `'0'..='9'`."""

alias alphanumeric0 = alphanumeric[min=0]
alias alphanumeric1 = alphanumeric[min=1]

alias hex_digit[*, min: UInt = 0] = take_while[min=min](
    TokenSet(
        CodepointRange[start="a", end="f"],
        CodepointRange[start="A", end="F"],
        NumericTokens,
    )
)
"""Parser recognizing hex digits `'a'..='f'`, `'A'..='F'`, and `'0'..='9'`."""

alias oct_digit[*, min: UInt = 0] = take_while[min=min](
    CodepointRange[start="0", end="7"]
)
"""Parser recognizing octal digits `'0'..='7'`."""

alias bin_digit[*, min: UInt = 0] = take_while[min=min](
    CodepointRange[start="0", end="1"]
)
"""Parser recognizing binary digits `'0'` and `'1'`."""

alias multispace[*, min: UInt = 0] = take_while[min=min](
    Tokens[" ", "\t", "\r", "\n"]
)
"""Parser recognizing codepoints: `' '`, `'\\t'`, `'\\r'`, and `'\\n'`."""

alias multispace0 = multispace[min=0]
alias multispace1 = multispace[min=1]

alias space[*, min: UInt = 0] = take_while[min=min](Tokens[" ", "\t"])
"""Parser recognizing codepoints: `' '` and `'\\t'`"""

alias tab = tag("\t")
"""Parser recognizing the tab codepoint: `'\\t'`"""

alias newline = tag("\n")
"""Parser recognizing the newline codepoint: `'\\n'`"""

alias crlf = tag("\r\n")
"""Parser recognizing the string: `'\\r\\n'`"""

alias line_ending = alt(newline, crlf)
"""Parser recognizing a line ending string: `'\\n'` or `'\\r\\n'`"""


@fieldwise_init
struct Escaped[
    NormalParser: Parsable,
    EscapeParser: Parsable,
    *,
    control: StringSlice[mut=False],
](Copyable & Movable & Parsable):
    alias Output = StringSlice[ImmutableAnyOrigin]

    var _normal: NormalParser
    var _escape: EscapeParser

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        alias result_type = ParseResult[Self.Output]

        var input_to_parse = rebind[StringSlice[ImmutableAnyOrigin]](input)
        while len(input_to_parse) > 0:
            var normal_result = opt(self._normal).parse(input_to_parse)
            if not normal_result:
                return normal_result.err()

            var (normal_output, normal_next_input) = normal_result.ok()
            if normal_output:
                if len(input_to_parse) == len(normal_next_input):
                    # TODO: add context that we cannot have an infinite parser
                    print("oh no")
                    return Err(input=input)
                input_to_parse = normal_next_input
                continue

            var control_result = opt(tag(control)).parse(input_to_parse)
            if not control_result:
                return control_result.err()

            var (control_output, control_next_input) = control_result.ok()
            if not control_output:
                var diff = len(input) - len(input_to_parse)
                return (input[:diff], input_to_parse)

            var escape_result = self._escape.parse(control_next_input)
            if escape_result:
                input_to_parse = escape_result.ok()[1]
            else:
                return escape_result.err()

        return (input, input_to_parse)


fn escaped[
    NormalParser: Parsable,
    EscapeParser: Parsable, //,
    *,
    control: StringSlice[mut=False],
](normal: NormalParser, escape: EscapeParser) -> Parser[
    Escaped[NormalParser, EscapeParser, control=control]
]:
    return Parser(
        Escaped[NormalParser, EscapeParser, control=control](normal, escape)
    )
