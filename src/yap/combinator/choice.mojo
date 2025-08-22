from yap.parser import *
from yap.tuple import _TraitTuple

# --- alt ---


@fieldwise_init
struct Alt[*parser_types: Parsable](Movable & Copyable & Parsable):
    alias Output = parser_types[0].Output
    alias _tuple = _TraitTuple[Parsable, *parser_types]

    var _parsers: Self._tuple

    fn parse(self, input: ParserInput) -> ParseResult[Self.Output]:
        @parameter
        for i in range(Self._tuple.__len__()):
            var result = self._parsers[i].parse(input)
            if result:
                var (output, input) = result.ok()
                return (rebind[Self.Output](output^), input)
            elif result is ErrKind.CUT:
                return Err(
                    kind=ErrKind.CUT,
                    input=input,
                )

        return Err(input=input)


fn alt[
    *parser_types: Parsable
](var *parsers: *parser_types) -> Parser[Alt[*parser_types]]:
    return Parser(Alt(_TraitTuple(storage=parsers^)))
