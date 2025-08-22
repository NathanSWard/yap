from yap.ascii import *
from yap.parser import *
from yap.combinator.choice import alt
from yap.combinator.sequence import *
from yap.combinator.multi import *
from yap.combinator.multi.separated import separated
from yap.token import *

# from emberjson import Null, Value, Object, Array

alias ws[P: Parsable, //, parser: P] = preceded(multispace0, parser)

alias null = tag("null").value(Null())

alias true = tag("true").value(True)
alias false = tag("false").value(False)
alias bool = alt(true, false)


fn try_map_number(var input: StringSlice[ImmutableAnyOrigin]) raises -> Float64:
    return Float64(input)


alias number = try_map[try_map_number](
    take_while[min=1](TokenSet(NumericTokens, Tokens["-", "."]))
)


fn to_string(slice: StringSlice[ImmutableAnyOrigin]) -> String:
    return String(slice)


alias string_contents = escaped[control="\\"](
    alphanumeric[min=1], one_of(Tokens['"', "\\", "n"])
)

alias string = map[to_string](
    delimited(char['"'], string_contents.cut(), char['"'].cut())
)

alias array = delimited(
    char["["],
    separated[Range(min=0)](value, ws[char[","]]).cut(),
    ws[char["]"]].cut(),
)


struct ObjectCollecter(Copyable & Movable & Collectable):
    alias Element = Tuple[String, Value]

    var object: Object

    fn __init__(out self):
        self.object = Object()

    fn __init__(out self, capacity: Int):
        self.object = Object()

    fn append(mut self, var element: Self.Element):
        var (key, value) = element^
        self.object[key^] = value^


alias key_value = separated_pair(ws[string], ws[char[":"]], value)
alias object = delimited(
    char["{"],
    separated[Range(min=0), ObjectCollecter](key_value, ws[char[","]]),
    ws[char["}"]].cut(),
)


fn from_null(null: Null) -> Value:
    return Value(None)


fn from_bool(bool: Bool) -> Value:
    return Value(bool)


fn from_number(float: Float64) -> Value:
    return Value(float)


fn from_string(var string: String) -> Value:
    return Value(string^)


fn from_array(var list: ListCollecter[Value]) -> Value:
    # todo: list.list^ fails to compile...
    return Value(Array(list.list))


fn from_object(var object: ObjectCollecter) -> Value:
    # todo: object.object^ fails to compile...
    return Value(object.object)


fn parse_value(input: ParserInput) -> ParseResult[Value]:
    alias parser = ws[
        alt(
            map[from_null](null),
            map[from_bool](bool),
            map[from_number](number),
            map[from_string](string),
            map[from_array](array),
            map[from_object](object),
        )
    ]
    return rebind[ParseResult[Value]](parser.parse(input))


alias value = parser_fn[parse_value]

alias root = delimited(
    multispace0,
    alt(
        map[from_object](object),
        map[from_array](array),
        map[from_null](null),
    ),
    multispace0,
)


def main():
    var result = root.parse(
        '{"null":null, "true": true, "false": false, "number":-3.14, "string":'
        ' "string", "array": [123, "hello", null], "object": {"nested": 890} }'
    )
    if result:
        var (output, _) = result.ok()
        print(output)
    else:
        print(result.err())
